import { el, L, run, icon, segmented, formatTime, dateOnly, labeled, confirmButton } from './ui.js';
import { app, go } from './main.js';

let status = 'active';

export async function renderBolos(args) {
    app.editing = false;
    if (args && args.create) return createForm();

    const response = await run('bolos', { status });
    const bolos = response ? response.data : [];

    const rows = bolos.map((bolo) => el('div', { class: 'card warrant' },
        el('div', { class: 'card-head' },
            icon(bolo.kind === 'vehicle' ? 'vehicles' : 'people', 20),
            el('strong', { class: 'big', text: bolo.title }),
            bolo.plate ? el('span', { class: 'pill', text: bolo.plate }) : null,
            el('span', { class: 'spacer' }),
            status === 'active' ? el('span', { class: 'pill gold', text: L('ui_until', dateOnly(bolo.expires)) }) : el('span', { class: 'pill', text: bolo.closed_by || '' }),
        ),
        el('p', { class: 'pre', text: bolo.description }),
        el('div', { class: 'button-row' },
            el('small', { class: 'muted grow', text: `${bolo.created_by} · ${formatTime(bolo.created)}` }),
            status === 'active' ? confirmButton(L('ui_close_bolo'), async () => { if (await run('closeBolo', { id: bolo.id }, L('ui_done'))) go('bolos'); }) : null,
        ),
    ));

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_bolos') }),
            segmented([['active', L('bolo_active')], ['closed', L('bolo_closed')]], status, (value) => {
                status = value;
                go('bolos');
            }),
            el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', onclick: () => go('bolos', { create: true }) }, icon('plus', 16), ' ', L('ui_new_bolo'))),
        el('p', { class: 'muted', text: L('ui_bolo_hint') }),
        rows.length ? el('div', { class: 'stack small' }, rows) : el('div', { class: 'empty' }, icon('bolos', 40), el('p', { text: L('ui_no_bolos') })),
    );
}

function createForm() {
    app.editing = true;

    let kind = 'person';
    const title = el('input', { class: 'field', type: 'text', maxlength: 60, placeholder: L('ui_bolo_title_hint') });
    const plate = el('input', { class: 'field', type: 'text', maxlength: 8, placeholder: 'ABC 123' });
    const plateRow = labeled(L('ui_plate'), plate);
    const description = el('textarea', { class: 'field', rows: 6, maxlength: 4000, placeholder: L('ui_bolo_description_hint') });
    const hours = el('input', { class: 'field', type: 'number', min: 1, max: 168, value: app.boloHours || 48 });

    plateRow.classList.add('hidden');

    const options = [['person', L('bolo_person')], ['vehicle', L('bolo_vehicle')]];
    const kinds = segmented(options, kind, (value) => {
        kind = value;
        plateRow.classList.toggle('hidden', kind !== 'vehicle');
        [...kinds.children].forEach((button, index) => button.classList.toggle('on', options[index][0] === kind));
    });

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_new_bolo') })),
        el('div', { class: 'card form' },
            labeled(L('ui_kind'), kinds),
            el('div', { class: 'form-grid' }, labeled(L('ui_bolo_title'), title), labeled(L('ui_hours_valid'), hours)),
            plateRow,
            labeled(L('ui_description'), description),
        ),
        el('div', { class: 'button-row' },
            el('button', { class: 'kit-btn', onclick: () => go('bolos') }, L('ui_cancel')),
            el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', onclick: async () => {
                const result = await run('saveBolo', { kind, title: title.value, plate: plate.value, description: description.value, hours: Number(hours.value) }, L('ui_bolo_created'));
                if (result) go('bolos');
            } }, L('ui_new_bolo'))),
    );
}
