import { el, L, run, icon, pill, formatTime, money, empty, select, confirmButton } from './ui.js';
import { can, go } from './main.js';
import { serverSearch } from './people.js';

let query = '';
let results = null;
let selected = null;

function vehicleRow(vehicle) {
    return el('button', { class: `list-row${vehicle.plate === selected ? ' on' : ''}`, onclick: () => go('vehicles', { plate: vehicle.plate }) },
        el('span', { class: 'plate', text: vehicle.plate }),
        el('span', { class: 'who' }, el('strong', { text: vehicle.model || L('ui_unknown_model') }), el('small', { text: vehicle.owner || vehicle.reason || '' })),
        vehicle.flag ? pill(L(`plate_${vehicle.flag}`), 'bad') : null,
    );
}

export async function renderVehicles(args) {
    if (args && args.plate) selected = args.plate;

    if (results === null) {
        const response = await run('searchVehicles', { q: '' });
        results = response ? response.data : [];
    }

    const list = el('div', { class: 'list' });
    const draw = () => list.replaceChildren(...(results.length ? results.map(vehicleRow) : [empty(L(query ? 'ui_no_results' : 'ui_no_flagged'))]));
    draw();

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_vehicles') })),
            serverSearch(L('ui_search_vehicles'), 'searchVehicles', (value, data) => {
                query = value;
                results = data;
                draw();
            }, query),
            list,
        ),
        el('div', { class: 'split-detail' }, selected ? await vehiclePage(selected) : el('div', { class: 'empty' }, icon('vehicles', 40), el('p', { text: L('ui_pick_vehicle') }))),
    );
}

async function vehiclePage(plate) {
    const response = await run('vehicle', { plate });
    if (!response) return empty(L('error_not_found'));

    const vehicle = response.data;
    const reload = () => {
        results = null;
        go('vehicles', { plate });
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
    );
}
