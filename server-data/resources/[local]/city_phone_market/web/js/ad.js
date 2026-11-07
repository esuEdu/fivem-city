// One ad's page (photo, price, text, contact, favorite; edit/renew/delete for the owner; remove for staff), the
// form to publish or edit an ad, and the picker for one of your photos
import {
    state, call, t, h, button, icon, input, toast, openSheet, closeSheet, navBar, backButton, formatNumber,
    CATEGORIES, money, ago, daysLeft, photo, forgetPhoto, lazyImage,
} from './lib.js';

let refresh = async () => {};

export function setRefresh(fn) {
    refresh = fn;
}

const REASONS = { limit: 'error.limit', no_money: 'error.noMoney', invalid: 'error.invalid' };

function reasonText(reason) {
    return t(REASONS[reason] || 'error.invalid');
}

function row(label, value) {
    return h('div', 'k-row', null, h('span', '', label), h('span', 'k-row__value', value));
}

function action(iconName, label, onClick) {
    return button('action', null, onClick, icon(iconName), h('span', '', label));
}

export function openAd(ad, back = t('tabs.browse')) {
    const actions = ad.mine ? [] : [
        action('message', t('ad.contact'), async () => {
            if (!(await call('contact', { id: ad.id })).ok) toast(t('error.contact'));
        }),
        action(ad.favorite ? 'heartFilled' : 'heart', t('ad.favorite'), async () => {
            if (!(await call('favorite', { id: ad.id, favorite: !ad.favorite })).ok) return;
            ad.favorite = !ad.favorite;
            await refresh();
            openAd(ad, back);
        }),
    ];

    const owner = ad.mine ? h('div', 'k-group', null,
        button('k-row k-row--accent', t('ad.edit'), () => openForm(ad)),
        button('k-row k-row--accent', t('ad.renew', state.days, money(state.fee)), async () => {
            const result = await call('renew', { id: ad.id });
            if (!result.ok) return toast(reasonText(result.reason));
            toast(t('ad.renewed'));
            closeSheet();
            await refresh();
        }),
        button('k-row k-row--danger', t('ad.delete'), async () => {
            if (!(await call('delete', { id: ad.id })).ok) return toast(t('error.invalid'));
            closeSheet();
            await refresh();
        }),
    ) : null;

    const staff = state.staff && !ad.mine ? h('div', 'k-group', null,
        button('k-row k-row--danger', t('ad.staffRemove'), async () => {
            if (!(await call('staffRemove', { id: ad.id })).ok) return toast(t('error.invalid'));
            toast(t('ad.removed'));
            closeSheet();
            await refresh();
        }),
    ) : null;

    openSheet(
        navBar(backButton(back, closeSheet), null, null),
        ad.hasPhoto ? lazyImage('ad__photo', () => photo(ad.id)) : null,
        h('div', 'ad__head', null,
            h('div', 'ad__price', money(ad.price)),
            h('div', 'ad__title', ad.title),
            h('div', 'ad__meta', `${t(`category.${ad.category}`)} · ${ago(ad.createdAt)}`),
        ),
        actions.length ? h('div', 'actions', null, actions) : null,
        ad.description ? h('p', 'ad__description', ad.description) : null,
        h('div', 'k-group', null,
            ad.number ? row(t('ad.number'), formatNumber(ad.number)) : null,
            ad.mine ? row(t('ad.status'), daysLeft(ad.expiresAt)) : null,
        ),
        owner,
        staff,
    );
}

// Your photos (newest first), each image loaded as it is shown; picks one id
function pickPhoto(onPick, reopen) {
    openSheet(
        navBar(backButton(t('form.back'), reopen), t('form.pickPhoto'), null),
        h('div', 'picker', null, h('div', 'k-empty', null, icon('photo'), h('span', '', t('form.loading')))),
    );

    call('myPhotos').then((result) => {
        const ids = result.ok && Array.isArray(result.result) ? result.result : [];
        const grid = document.querySelector('.picker');
        if (!grid) return;

        if (ids.length === 0) {
            grid.replaceChildren(h('div', 'k-empty', null, icon('photo'), h('span', '', t('form.noPhotos'))));
            return;
        }

        grid.replaceChildren(h('div', 'picker__grid', null, ids.map((id) => button('picker__tile', null, () => onPick(id),
            lazyImage('picker__image', () => call('myPhoto', { id }).then((r) => (r.ok ? r.result : null))),
        ))));
    });
}

// Publishing (ad without id) or editing; the photo is one of yours, copied into the ad
export function openForm(ad = {}) {
    const editing = ad.id !== undefined;
    const form = {
        title: ad.title || '',
        description: ad.description || '',
        price: ad.price !== undefined ? String(ad.price) : '',
        category: ad.category || null,
        showNumber: ad.showNumber !== false,
        // undefined: keep (editing) or none; a number: a new photo; false: remove it
        photo: undefined,
        hasPhoto: ad.hasPhoto === true,
    };

    const draw = () => {
        const title = input('k-field', t('form.title'), 50);
        title.value = form.title;
        title.addEventListener('input', () => { form.title = title.value; });

        const price = input('k-field', t('form.price'), 9);
        price.inputMode = 'numeric';
        price.value = form.price;
        price.addEventListener('input', () => {
            price.value = price.value.replace(/\D/g, '');
            form.price = price.value;
        });

        const description = document.createElement('textarea');
        description.className = 'k-field form__text';
        description.maxLength = 500;
        description.placeholder = t('form.description');
        description.value = form.description;
        description.addEventListener('input', () => { form.description = description.value; });

        const categories = CATEGORIES.map((category) => button(`chip${form.category === category ? ' chip--on' : ''}`, t(`category.${category}`), () => {
            form.category = category;
            draw();
        }));

        let photoPreview = null;
        if (typeof form.photo === 'number') {
            photoPreview = lazyImage('form__photo', () => call('myPhoto', { id: form.photo }).then((r) => (r.ok ? r.result : null)));
        } else if (form.photo === undefined && form.hasPhoto && editing) {
            photoPreview = lazyImage('form__photo', () => photo(ad.id));
        }

        const photoRows = [
            button('k-row k-row--accent', t(photoPreview ? 'form.changePhoto' : 'form.addPhoto'), () => pickPhoto((id) => {
                form.photo = id;
                draw();
            }, draw)),
            photoPreview ? button('k-row k-row--danger', t('form.removePhoto'), () => {
                form.photo = false;
                form.hasPhoto = false;
                draw();
            }) : null,
        ];

        const numberMark = h('span', `k-check${form.showNumber ? ' k-check--on' : ''}`, null, icon('check'));

        const save = button('k-link', editing ? t('form.save') : t('form.publish'), async () => {
            const data = {
                title: form.title,
                description: form.description,
                price: Number(form.price || 0),
                category: form.category,
                showNumber: form.showNumber,
            };

            if (!data.title.trim()) return toast(t('form.needTitle'));
            if (!data.category) return toast(t('form.needCategory'));

            const result = editing
                ? await call('edit', { id: ad.id, ad: data, photo: form.photo })
                : await call('publish', { ad: data, photo: typeof form.photo === 'number' ? form.photo : undefined });

            if (!result.ok) return toast(reasonText(result.reason));

            if (editing) forgetPhoto(ad.id);
            toast(t(editing ? 'form.saved' : 'form.published'));
            closeSheet();
            await refresh();
        });

        openSheet(
            navBar(button('k-link', t('form.cancel'), closeSheet), editing ? t('form.editTitle') : t('form.newTitle'), save),
            photoPreview,
            h('div', 'k-group', null, photoRows),
            h('div', 'k-group', null, title, price),
            h('p', 'k-group__label', t('form.category')),
            h('div', 'chips chips--wrap', null, categories),
            h('div', 'k-group', null, description),
            h('div', 'k-group', null, button('k-row', null, () => {
                form.showNumber = !form.showNumber;
                draw();
            }, h('span', '', t('form.showNumber')), numberMark)),
            h('p', 'form__hint', editing ? t('form.hintEdit') : t('form.hintFee', money(state.fee), state.days)),
        );
    };

    draw();
}
