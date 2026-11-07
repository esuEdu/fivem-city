import { el, L, run, icon, pill, formatTime, empty, select } from './ui.js';
import { go } from './main.js';
import { serverSearch } from './people.js';

let query = '';
let results = null;
let selected = null;

const STATUS_KIND = { registered: 'blue', seized: 'gold', stolen: 'bad' };

function weaponRow(weapon) {
    return el('button', { class: `list-row${weapon.serial === selected ? ' on' : ''}`, onclick: () => go('weapons', { serial: weapon.serial }) },
        icon('weapons', 18),
        el('span', { class: 'who' }, el('strong', { text: weapon.label }), el('small', { text: `${weapon.serial} · ${weapon.owner || '—'}` })),
        pill(L(`weapon_${weapon.status}`), STATUS_KIND[weapon.status]),
    );
}

export async function renderWeapons(args) {
    if (args && args.serial) selected = args.serial;

    if (results === null) {
        const response = await run('searchWeapons', { q: '' });
        results = response ? response.data : [];
    }

    const list = el('div', { class: 'list' });
    const draw = () => list.replaceChildren(...(results.length ? results.map(weaponRow) : [empty(L(query ? 'ui_no_results' : 'ui_search_serial'))]));
    draw();

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_weapons') })),
            serverSearch(L('ui_search_weapons'), 'searchWeapons', (value, data) => {
                query = value;
                results = data;
                draw();
            }, query),
            list,
        ),
        el('div', { class: 'split-detail' }, selected ? await weaponPage(selected) : el('div', { class: 'empty' }, icon('weapons', 40), el('p', { text: L('ui_pick_weapon') }))),
    );
}

async function weaponPage(serial) {
    const response = await run('weapon', { serial });
    if (!response) return empty(L('error_not_found'));

    const weapon = response.data;
    const status = select(['registered', 'seized', 'stolen'].map((value) => [value, L(`weapon_${value}`)]), weapon.status);
    const notes = el('input', { class: 'field', type: 'text', maxlength: 160, placeholder: L('ui_notes') });
    const info = (label, value) => el('div', { class: 'info-row' }, el('span', { text: label }), el('span', { class: 'value', text: value || '—' }));

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('span', { class: 'big-icon' }, icon('weapons', 30)),
            el('div', { class: 'who grow' }, el('h2', { text: weapon.label }), el('small', { text: weapon.serial }),
                el('div', { class: 'pills' }, pill(L(`weapon_${weapon.status}`), STATUS_KIND[weapon.status]))),
        ),
        el('div', { class: 'card flush' },
            el('div', { class: 'info-row' }, el('span', { text: L('ui_owner') }),
                weapon.owner_cid ? el('button', { class: 'link value', text: weapon.owner, onclick: () => go('people', { citizenid: weapon.owner_cid }) }) : el('span', { class: 'value', text: '—' })),
            info(L('ui_bought_at'), weapon.shop),
            info(L('ui_registered_on'), formatTime(weapon.created)),
            info(L('ui_notes'), weapon.notes),
        ),
        el('div', { class: 'card' },
            el('div', { class: 'card-head' }, el('strong', { text: L('ui_change_status') })),
            el('div', { class: 'form-row' }, status, notes,
                el('button', { class: 'kit-btn accent', onclick: async () => {
                    if (await run('setWeaponStatus', { serial, status: status.value, notes: notes.value }, L('ui_saved'))) go('weapons', { serial });
                } }, L('ui_save'))),
        ),
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_casings_matched') }), el('span', { class: 'pill', text: String(weapon.casings.length) })),
            weapon.casings.length ? weapon.casings.map((casing) => el('button', { class: 'info-row link-row', onclick: () => go('evidence', { id: casing.id }) },
                icon('evidence', 18), el('strong', { text: `#${casing.id} ${casing.place || ''}` }),
                el('span', { class: 'value', text: `${casing.collected_by} · ${formatTime(casing.collected_at)}` }))) : el('p', { class: 'muted padded', text: L('ui_none') }),
        ),
    );
}
