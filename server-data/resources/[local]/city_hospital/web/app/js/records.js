// Records: every revive and bill an EMS gave (searchable by patient or EMS) and the reference prices to bill patients.
import { app, state } from './main.js';
import { kindPill } from './dashboard.js';

const { el, L, run, heading, segmented, searchField, money, formatTime, icon } = window.WorkApp;

let view = 'history';
let query = '';

const PRICE_ICONS = { revive: 'heart', treatment: 'plus', transport: 'vehicle', checkup: 'check' };

function history(list) {
    const rows = el('div');

    const draw = () => {
        const shown = query
            ? list.filter((record) => record.patient.toLowerCase().includes(query) || record.name.toLowerCase().includes(query))
            : list;

        rows.replaceChildren(...(shown.length ? shown.map((record) => el('div', { class: 'table-row record-cols' },
            el('span', { class: 'kind' }, kindPill(record)),
            el('div', { class: 'who' }, el('strong', { text: record.patient }), el('small', { text: formatTime(record.created) })),
            el('span', { text: record.name }),
            el('span', { class: 'record-note', text: record.note || '' }),
            el('strong', { class: 'value', text: record.kind === 'bill' ? money(record.amount) : '—' }),
        )) : [el('div', { class: 'list-empty', text: query ? L('ui_no_match') : L('ui_no_records') })]));
    };

    draw();

    return el('div', { class: 'stack small' },
        searchField(L('ui_search_records'), (value) => {
            query = value;
            draw();
        }, query),
        el('div', { class: 'card flush' },
            el('div', { class: 'table-head record-cols' }, ['ui_kind', 'ui_patient', 'ui_ems', 'ui_note', 'ui_value'].map((key) => el('span', { text: L(key) }))),
            rows),
    );
}

function prices() {
    const list = state.prices;

    return el('div', { class: 'stack small' },
        el('div', { class: 'banner' }, icon('money', 18, 2), el('span', { text: L('ui_prices_hint', money(list.maxBill)) })),
        el('div', { class: 'price-grid' }, list.billing.map((entry) => el('div', { class: 'card price' },
            el('span', { class: 'tile-icon tint' }, icon(PRICE_ICONS[entry.key] || 'plus', 18, 2)),
            el('div', { class: 'who' }, el('strong', { text: L(`price_${entry.key}`) }), el('small', { text: L(`price_${entry.key}_sub`) })),
            el('strong', { class: 'value', text: money(entry.price) })))),
    );
}

export async function renderRecords() {
    let body;

    if (view === 'history') {
        const response = await run('records');
        if (!response) return el('div', { class: 'empty', text: L('error_failed') });
        body = history(response.data);
    } else {
        body = prices();
    }

    return el('div', { class: 'stack' },
        heading(L('ui_tab_records'), el('span', { class: 'spacer' }),
            segmented([['history', L('ui_history')], ['prices', L('ui_prices')]], view, (value) => {
                view = value;
                app.go('records');
            })),
        body,
    );
}
