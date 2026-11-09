import { el, L, run, icon, pill, searchField, formatTime, dateOnly, money, empty, photo } from './ui.js';
import { can, go } from './main.js';

let query = '';
let results = [];
let selected = null;

// A search box that asks the server after a short pause
export function serverSearch(placeholder, action, onResults, initial = '') {
    let timer = null;
    const field = searchField(placeholder, (value) => {
        clearTimeout(timer);
        timer = setTimeout(async () => {
            const response = await run(action, { q: value });
            onResults(value, response ? response.data : []);
        }, 350);
    });
    field.querySelector('input').value = initial;
    return field;
}

function personRow(person) {
    return el('button', { class: `list-row${person.citizenid === selected ? ' on' : ''}`, onclick: () => go('people', { citizenid: person.citizenid }) },
        photo(null, person.name, 'small'),
        el('span', { class: 'who' }, el('strong', { text: person.name }), el('small', { text: [person.citizenid, person.phone].filter(Boolean).join(' · ') })),
        person.online ? el('i', { class: 'dot available' }) : null,
    );
}

export async function renderPeople(args) {
    if (args && args.citizenid) selected = args.citizenid;

    const list = el('div', { class: 'list' });
    const draw = () => list.replaceChildren(...(results.length ? results.map(personRow) : [empty(L(query ? 'ui_no_results' : 'ui_search_hint'))]));
    draw();

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_people') })),
            serverSearch(L('ui_search_people'), 'searchPeople', (value, data) => {
                query = value;
                results = data;
                draw();
            }, query),
            list,
        ),
        el('div', { class: 'split-detail' }, selected ? await personFile(selected) : el('div', { class: 'empty' }, icon('people', 40), el('p', { text: L('ui_pick_person') }))),
    );
}

function section(title, rows, emptyText) {
    return el('div', { class: 'card flush' },
        el('div', { class: 'card-head padded' }, el('strong', { text: title }), el('span', { class: 'pill', text: String(rows.length) })),
        rows.length ? rows : el('p', { class: 'muted padded', text: emptyText }),
    );
}

function chargesText(charges) {
    return charges.map((charge) => (charge.count > 1 ? `${charge.title} x${charge.count}` : charge.title)).join(', ');
}

async function personFile(citizenid) {
    const response = await run('person', { citizenid });
    if (!response) return empty(L('error_not_found'));

    const person = response.data;
    const licences = person.licences || {};

    const pills = [
        person.online ? pill(L('ui_online_now'), 'green') : pill(L('ui_offline')),
        person.warrants.length ? pill(L('ui_wanted'), 'bad') : null,
        person.anklet ? pill(L('ui_anklet'), 'gold') : null,
        licences.driver ? pill(L('licence_driver'), 'blue') : pill(L('ui_no_driver'), 'muted-pill'),
        licences.weapon ? pill(L('licence_weapon'), 'blue') : null,
        licences.explosives ? pill(L('licence_explosives'), 'blue') : null,
    ];

    const actions = el('div', { class: 'button-row' },
        can('charge') && person.online ? el('button', { class: 'kit-btn accent', onclick: () => go('charges', { citizenid: person.citizenid, name: person.name }) }, L('ui_charge')) : null,
        can('reports') ? el('button', { class: 'kit-btn', onclick: () => go('reports', { new: true, person: { citizenid: person.citizenid, name: person.name } }) }, L('ui_new_report')) : null,
        can('issueWarrant') ? el('button', { class: 'kit-btn', onclick: () => go('warrants', { issue: { citizenid: person.citizenid, name: person.name } }) }, L('ui_issue_warrant')) : null,
        can('licences') ? el('button', { class: 'kit-btn', onclick: () => go('licences', { citizenid: person.citizenid }) }, L('ui_tab_licences')) : null,
    );

    const info = (label, value) => el('div', { class: 'info-row' }, el('span', { text: label }), el('span', { class: 'value', text: value || '—' }));

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            photo(person.photo, person.name),
            el('div', { class: 'who grow' },
                el('h2', { text: person.name }),
                el('small', { text: `${person.citizenid}${person.job ? ` · ${person.job}` : ''}` }),
                el('div', { class: 'pills' }, pills),
            ),
        ),
        actions,
        el('div', { class: 'two-cols even' },
            el('div', { class: 'card flush' },
                info(L('ui_birthdate'), person.birthdate),
                info(L('ui_phone'), person.phone),
                info(L('ui_nationality'), person.nationality),
                info(L('ui_fingerprint'), person.fingerprint),
                info(L('ui_bloodtype'), person.bloodtype),
                info(L('ui_points'), L('ui_points_of', person.points)),
            ),
            section(L('ui_active_warrants'), person.warrants.map((warrant) => el('div', { class: 'info-row tall' },
                icon('warrants', 18),
                el('span', { class: 'grow' }, el('strong', { text: warrant.reason }), el('small', { class: 'block muted', text: chargesText(warrant.charges) })),
                el('span', { class: 'value', text: L('ui_until', dateOnly(warrant.expires)) }))), L('ui_no_warrants')),
        ),
        section(L('ui_record'), person.records.map((record) => el('div', { class: 'info-row tall' },
            pill(L(`record_${record.kind}`), record.kind === 'arrest' ? 'bad' : 'gold'),
            el('span', { class: 'grow' }, el('strong', { text: chargesText(record.charges) }),
                el('small', { class: 'block muted', text: [record.months ? L('ui_months', record.months) : null, record.fine ? money(record.fine) : null, record.points ? L('ui_points_short', record.points) : null, record.officer].filter(Boolean).join(' · ') })),
            el('span', { class: 'value', text: formatTime(record.created) }))), L('ui_clean_record')),
        el('div', { class: 'two-cols even' },
            section(L('ui_tab_vehicles'), person.vehicles.map((vehicle) => el('button', { class: 'info-row link-row', onclick: () => go('vehicles', { plate: vehicle.plate }) },
                icon('vehicles', 18), el('strong', { text: vehicle.plate }), el('span', { class: 'value', text: vehicle.vehicle }))), L('ui_none')),
            section(L('ui_tab_weapons'), person.weapons.map((weapon) => el('button', { class: 'info-row link-row', onclick: () => go('weapons', { serial: weapon.serial }) },
                icon('weapons', 18), el('strong', { text: weapon.label }), el('span', { class: 'value', text: `${weapon.serial} · ${L(`weapon_${weapon.status}`)}` }))), L('ui_none')),
        ),
        section(L('ui_tab_reports'), person.reports.map((report) => el('button', { class: 'info-row link-row', onclick: () => go('reports', { id: report.id }) },
            icon('reports', 18), el('strong', { text: `#${report.id} ${report.title}` }), el('span', { class: 'value', text: formatTime(report.created) }))), L('ui_none')),
    );
}
