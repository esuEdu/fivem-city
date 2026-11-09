import { el, L, run, icon, toast } from './ui.js';

// Case photos by id, loaded once while the MDT is open
const cache = new Map();

async function imageOf(action, id) {
    const key = `${action}:${id}`;
    if (!cache.has(key)) cache.set(key, run(action, { id }).then((response) => (response ? response.data : null)));
    return cache.get(key);
}

// Only images the phone made (data URLs) are drawn
function safe(src) {
    return typeof src === 'string' && /^data:image\/(png|jpe?g|webp);base64,/.test(src) ? src : null;
}

function showBig(src) {
    const overlay = el('div', { class: 'overlay', onclick: () => overlay.remove() }, el('img', { class: 'photo-big', src, alt: '' }));
    document.body.append(overlay);
}

// A thumbnail of a case photo; onRemove adds the × in the corner
export function casePhoto(id, number, onRemove) {
    const box = el('div', { class: 'thumb' }, el('span', { class: 'thumb-loading' }, icon('image', 22)));

    imageOf('casePhoto', id).then((data) => {
        const src = safe(data);
        box.replaceChildren(
            src ? el('img', { src, alt: '', onclick: () => showBig(src) }) : el('span', { class: 'thumb-loading' }, icon('image', 22)),
            el('span', { class: 'thumb-number', text: String(number) }),
            onRemove ? el('button', { class: 'thumb-x', type: 'button', title: L('ui_remove'), onclick: onRemove }, icon('close', 14)) : null,
        );
    });

    return box;
}

// A window with the officer's newest phone photos; picking one copies it into the police files and calls onPick(id)
export async function pickPhonePhoto(onPick) {
    const response = await run('phonePhotos');
    if (!response) return;

    const close = () => overlay.remove();
    const grid = el('div', { class: 'photo-grid' });
    const overlay = el('div', { class: 'overlay', onclick: (event) => { if (event.target === overlay) close(); } },
        el('div', { class: 'modal' },
            el('div', { class: 'heading' }, el('h2', { text: L('ui_add_evidence') }), el('span', { class: 'spacer' }),
                el('button', { class: 'kit-btn', type: 'button', onclick: close }, L('ui_cancel'))),
            el('p', { class: 'muted', text: L('ui_phone_photos_hint') }),
            grid,
        ));

    if (!response.data.length) grid.replaceChildren(el('div', { class: 'list-empty', text: L('ui_no_phone_photos') }));

    for (const id of response.data) {
        const tile = el('button', { class: 'thumb pick', type: 'button' }, el('span', { class: 'thumb-loading' }, icon('image', 22)));
        grid.append(tile);

        imageOf('phonePhoto', id).then((data) => {
            const src = safe(data);
            if (src) tile.replaceChildren(el('img', { src, alt: '' }));
        });

        tile.addEventListener('click', async () => {
            const result = await run('attachPhoto', { id });
            if (!result) return;

            close();
            toast(L('ui_photo_added'));
            onPick(result.data);
        });
    }

    document.body.append(overlay);
}
