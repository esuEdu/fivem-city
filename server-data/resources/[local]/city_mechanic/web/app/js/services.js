// Services: the tuning bay's history (searchable by plate or mechanic) and the reference price list to charge customers.
import { app, state } from './main.js';
import { partChips } from './dashboard.js';

const { el, L, run, heading, segmented, searchField, money, formatTime, icon } = window.WorkApp;

let view = 'history';
let query = '';

const FLAT_ICONS = { part: 'wrench', paint: 'tag', wheels: 'tyre', tyres: 'tyre', lights: 'star', tint: 'shield', plate: 'tag', horn: 'bell', turbo: 'engine' };

function history(list) {
    const rows = el('div');

    const draw = () => {
        const shown = query
            ? list.filter((service) => service.plate.toLowerCase().includes(query) || service.name.toLowerCase().includes(query))
            : list;

        rows.replaceChildren(...(shown.length ? shown.map((service) => el('div', { class: 'table-row history-cols' },
            el('span', { class: 'plate', text: service.plate }),
            el('div', { class: 'who' }, el('strong', { text: service.name }), el('small', { text: formatTime(service.created) })),
            el('div', { class: 'chips' }, partChips(service, 5)),
            el('strong', { class: 'value', text: money(service.total) }),
        )) : [el('div', { class: 'list-empty', text: query ? L('ui_no_match') : L('ui_no_services') })]));
    };

    draw();

    return el('div', { class: 'stack small' },
        searchField(L('ui_search_services'), (value) => {
            query = value;
            draw();
        }, query),
        el('div', { class: 'card flush' },
            el('div', { class: 'table-head history-cols' }, ['ui_plate', 'ui_mechanic', 'ui_work', 'ui_value'].map((key) => el('span', { text: L(key) }))),
            rows),
    );
}

function prices() {
    const list = state.prices;

    return el('div', { class: 'stack small' },
        el('div', { class: 'banner' }, icon('money', 18, 2), el('span', { text: L('ui_prices_hint') })),
        el('div', { class: 'price-grid' }, list.flat.map((entry) => el('div', { class: 'card price' },
            el('span', { class: 'tile-icon tint' }, icon(FLAT_ICONS[entry.key] || 'wrench', 18, 2)),
            el('div', { class: 'who' }, el('strong', { text: L(`price_${entry.key}`) }), el('small', { text: L(`price_${entry.key}_sub`) })),
            el('strong', { class: 'value', text: money(entry.price) })))),
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_performance') }), el('span', { class: 'spacer' }), el('small', { class: 'muted', text: L('ui_per_level') })),
            list.performance.map((entry) => el('div', { class: 'table-row perf-row' },
                el('strong', { text: entry.label }),
                el('div', { class: 'levels' }, entry.levels.map((price, index) => el('span', { class: 'level' },
                    el('small', { text: L('ui_level', index + 1) }), el('strong', { text: money(price) }))))))),
        el('div', { class: 'card price' },
            el('span', { class: 'tile-icon green' }, icon('check', 18, 2)),
            el('div', { class: 'who' }, el('strong', { text: L('price_repair') }), el('small', { text: L('price_repair_sub') })),
            el('strong', { class: 'value', text: L('ui_per_point', money(list.repairPerPoint)) })),
    );
}

export async function renderServices() {
    let body;

    if (view === 'history') {
        const response = await run('services');
        if (!response) return el('div', { class: 'empty', text: L('error_failed') });
        body = history(response.data);
    } else {
        body = prices();
    }

    return el('div', { class: 'stack' },
        heading(L('ui_tab_services'), el('span', { class: 'spacer' }),
            segmented([['history', L('ui_history')], ['prices', L('ui_prices')]], view, (value) => {
                view = value;
                app.go('services');
            })),
        body,
    );
}
