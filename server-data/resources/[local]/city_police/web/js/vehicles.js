import { el, L, run, icon, pill, formatTime, money, empty, select, confirmButton, photo } from './ui.js';
import { can, go } from './main.js';
import { serverSearch } from './people.js';

let query = '';
let results = null; // { people, vehicles } from the search box
let owner = null; // citizenid whose small profile and cars are on the left, instead of the results
let selected = null;

function vehicleRow(vehicle, sub) {
    return el('button', { class: `list-row${vehicle.plate === selected ? ' on' : ''}`, onclick: () => go('vehicles', { plate: vehicle.plate }) },
        el('span', { class: 'plate', text: vehicle.plate }),
        el('span', { class: 'who' }, el('strong', { text: vehicle.model || L('ui_unknown_model') }), el('small', { text: sub || vehicle.owner || vehicle.reason || '' })),
        vehicle.flag ? pill(L(`plate_${vehicle.flag}`), 'bad') : null,
    );
}

function personRow(person) {
    return el('button', { class: `list-row${person.citizenid === owner ? ' on' : ''}`, onclick: () => go('vehicles', { owner: person.citizenid }) },
        photo(null, person.name, 'small'),
        el('span', { class: 'who' }, el('strong', { text: person.name }), el('small', { text: `${person.citizenid} · ${(person.cars === 1 ? L('ui_vehicle_count_one') : L('ui_vehicle_count', person.cars))}` })),
        person.online ? el('i', { class: 'dot available' }) : null,
    );
}

function resultsList() {
    const people = results.people || [];
    const vehicles = results.vehicles || [];
    const rows = [];

    if (people.length) rows.push(el('div', { class: 'list-label', text: L('ui_tab_people') }), ...people.map(personRow));
    if (people.length && vehicles.length) rows.push(el('div', { class: 'list-label', text: L('ui_tab_vehicles') }));
    rows.push(...vehicles.map((vehicle) => vehicleRow(vehicle)));

    return el('div', { class: 'list' }, rows.length ? rows : empty(L(query ? 'ui_no_results' : 'ui_no_flagged')));
}

// The owner picked from the search, or of the car shown: a small profile, then every car they own
function ownerPanel(person) {
    return el('div', { class: 'stack small grow-list' },
        el('div', { class: 'card owner-card' },
            photo(person.photo, person.name, 'mid'),
            el('div', { class: 'who grow' },
                el('strong', { text: person.name }),
                el('small', { text: person.citizenid }),
                el('div', { class: 'pills' },
                    person.online ? pill(L('ui_online_now'), 'green') : pill(L('ui_offline')),
                    can('people') ? el('button', { class: 'link small', text: L('ui_open_file'), onclick: () => go('people', { citizenid: person.citizenid }) }) : null),
            ),
            el('button', { class: 'icon-btn', title: L('ui_close'), onclick: () => { owner = null; go('vehicles', {}); } }, icon('close', 16, 2)),
        ),
        el('div', { class: 'list' },
            el('div', { class: 'list-label', text: L('ui_owner_vehicles', person.vehicles.length) }),
            person.vehicles.length
                ? person.vehicles.map((vehicle) => vehicleRow(vehicle, L(`vehicle_state_${vehicle.state}`)))
                : empty(L('ui_none'))),
    );
}

export async function renderVehicles(args) {
    if (args && args.owner !== undefined) owner = args.owner;
    if (args && args.plate) selected = args.plate;
    // Picking a person shows their first car; opening a plate shows its owner
    if (args && args.owner && !args.plate) selected = null;

    if (results === null) {
        const response = await run('searchVehicles', { q: query });
        results = response ? response.data : { people: [], vehicles: [] };
    }

    let vehicle = selected ? await loadVehicle(selected) : null;
    if (args && args.plate && args.owner === undefined) owner = vehicle && vehicle.citizenid ? vehicle.citizenid : null;

    let person = null;
    if (owner) {
        const response = await run('vehicleOwner', { citizenid: owner });
        person = response ? response.data : null;
        if (!person) owner = null;
    }

    if (person && !selected && person.vehicles.length) {
        selected = person.vehicles[0].plate;
        vehicle = await loadVehicle(selected);
    }

    const left = el('div', { class: 'split-body' }, person ? ownerPanel(person) : resultsList());

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_vehicles') })),
            serverSearch(L('ui_search_vehicles'), 'searchVehicles', (value, data) => {
                query = value;
                results = data || { people: [], vehicles: [] };
                owner = null;
                left.replaceChildren(resultsList());
            }, query),
            left,
        ),
        el('div', { class: 'split-detail' }, selected ? vehiclePage(vehicle) : el('div', { class: 'empty' }, icon('vehicles', 40), el('p', { text: L(person ? 'ui_owner_no_vehicles' : 'ui_pick_vehicle') }))),
    );
}

async function loadVehicle(plate) {
    const response = await run('vehicle', { plate });
    return response ? response.data : null;
}

// The model's catalogue picture; addon cars have none, so the card goes away when it fails to load
function vehiclePhoto(src, model) {
    const card = el('div', { class: 'card vehicle-photo hidden' });
    const img = el('img', { alt: model || '' });

    img.onload = () => card.classList.remove('hidden');
    img.onerror = () => card.remove();
    img.src = src;
    card.append(img);

    return card;
}

function vehiclePage(vehicle) {
    if (!vehicle) return empty(L('error_not_found'));

    const plate = vehicle.plate;
    const reload = () => {
        results = null;
        go('vehicles', { plate, owner });
    };

    let flagCard = null;
    if (vehicle.flag) {
        flagCard = el('div', { class: 'card alert' },
            el('div', { class: 'card-head' }, icon('flag', 18), el('strong', { text: L(`plate_${vehicle.flag.status}`) }), el('span', { class: 'spacer' }),
                can('flagPlate') ? confirmButton(L('ui_clear_flag'), async () => { if (await run('clearPlate', { plate }, L('ui_done'))) reload(); }, 'kit-btn') : null),
            el('p', { text: vehicle.flag.reason }),
            el('small', { class: 'muted', text: `${vehicle.flag.by} · ${formatTime(vehicle.flag.at)}` }),
        );
    } else if (can('flagPlate')) {
        const status = select([['stolen', L('plate_stolen')], ['wanted', L('plate_wanted')]], 'stolen');
        const reason = el('input', { class: 'field', type: 'text', maxlength: 160, placeholder: L('ui_reason') });

        flagCard = el('div', { class: 'card' },
            el('div', { class: 'card-head' }, el('strong', { text: L('ui_flag_plate') })),
            el('div', { class: 'form-row' }, status, reason,
                el('button', { class: 'kit-btn accent', onclick: async () => {
                    if (await run('flagPlate', { plate, status: status.value, reason: reason.value }, L('ui_done'))) reload();
                } }, L('ui_flag'))),
        );
    }

    const info = (label, value) => el('div', { class: 'info-row' }, el('span', { text: label }), el('span', { class: 'value', text: value || '—' }));

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('span', { class: 'plate big', text: vehicle.plate }),
            el('div', { class: 'who grow' },
                el('h2', { text: vehicle.model || L('ui_unknown_model') }),
                el('small', { text: vehicle.registered ? L('ui_registered') : L('ui_not_registered') })),
        ),
        el('div', { class: 'card flush' },
            el('div', { class: 'info-row' }, el('span', { text: L('ui_owner') }),
                vehicle.citizenid ? el('button', { class: 'link value', text: vehicle.owner || vehicle.citizenid, onclick: () => go('people', { citizenid: vehicle.citizenid }) }) : el('span', { class: 'value', text: '—' })),
            info(L('ui_garage'), vehicle.garage),
            info(L('ui_state'), vehicle.state !== undefined && vehicle.state !== null ? L(`vehicle_state_${vehicle.state}`) : null),
        ),
        flagCard,
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_impounds') })),
            vehicle.impounds.length ? vehicle.impounds.map((row) => el('div', { class: 'info-row tall' },
                icon('impounds', 18),
                el('span', { class: 'grow' }, el('strong', { text: row.reason }), el('small', { class: 'block muted', text: `${row.officer} · ${money(row.fee)}` })),
                el('span', { class: 'value', text: row.released_at ? L('ui_released') : L('ui_held') }))) : el('p', { class: 'muted padded', text: L('ui_none') }),
        ),
        vehicle.image ? vehiclePhoto(vehicle.image, vehicle.model) : null,
    );
}
