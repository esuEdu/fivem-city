import { el, L, icon, searchField, money } from './ui.js';
import { app } from './main.js';

// Card color per penal code category
const COLORS = { traffic: 'green', misdemeanor: 'gold', felony: 'red' };

function crimeText(crime) {
    return [L('ui_months', crime.months), money(crime.fine), crime.points ? L('ui_points_short', crime.points) : null].filter(Boolean).join(' · ');
}

// The penal code as colored cards, grouped by category. With onPick, a card adds that crime (counts shows how many).
function penalGrid(filter, onPick, counts) {
    const text = filter.toLowerCase();
    const groups = [];

    for (const category of app.penal.categories) {
        const crimes = app.penal.crimes.filter((crime) => crime.category === category && (!text || crime.title.toLowerCase().includes(text)));
        if (!crimes.length) continue;

        groups.push(el('div', { class: 'penal-group' },
            el('div', { class: 'kit-head', text: L(`penal_${category}`) }),
            el('div', { class: 'penal-grid' }, crimes.map((crime) => {
                const count = counts ? counts[crime.id] || 0 : 0;

                return el(onPick ? 'button' : 'div', { class: `penal-card ${COLORS[category]}${onPick ? ' pick' : ''}`, type: onPick ? 'button' : null, onclick: onPick ? () => onPick(crime) : null },
                    el('span', { class: 'penal-top' }, el('strong', { text: crime.title }), el('small', { text: L(`penal_one_${category}`) })),
                    el('span', { class: 'penal-bottom' }, el('small', { text: crimeText(crime) }), count ? el('span', { class: 'penal-count', text: `×${count}` }) : null),
                );
            })),
        ));
    }

    return groups.length ? groups : [el('div', { class: 'list-empty', text: L('ui_no_results') })];
}

// The Penal Code tab: look only
export async function renderPenal() {
    app.editing = false;

    const grid = el('div', { class: 'stack' }, penalGrid('', null));
    const search = searchField(L('ui_search_crimes'), (value) => grid.replaceChildren(...penalGrid(value, null)));

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_penal') })),
        search,
        grid,
    );
}

// A window over the page that lists the penal code; each tap adds one count of that crime (up to 5) and calls
// onChange(counts). counts is { crimeId: n }, changed in place.
export function chargePicker(counts, onChange) {
    let filter = '';
    const grid = el('div', { class: 'stack' });
    const draw = () => grid.replaceChildren(...penalGrid(filter, (crime) => {
        counts[crime.id] = Math.min(5, (counts[crime.id] || 0) + 1);
        draw();
        onChange(counts);
    }, counts));

    const close = () => overlay.remove();
    const overlay = el('div', { class: 'overlay', onclick: (event) => { if (event.target === overlay) close(); } },
        el('div', { class: 'modal' },
            el('div', { class: 'heading' }, el('h2', { text: L('ui_add_charges') }), el('span', { class: 'spacer' }),
                el('button', { class: 'kit-btn accent', type: 'button', onclick: close }, L('ui_done'))),
            searchField(L('ui_search_crimes'), (value) => { filter = value; draw(); }),
            grid,
        ));

    draw();
    document.body.append(overlay);
    overlay.querySelector('input').focus();
}

// The picked charges as rows with × (and the count when more than one)
export function chargeRows(counts, onChange) {
    const rows = Object.entries(counts).map(([id, count]) => {
        const crime = app.penal.crimes.find((entry) => entry.id === id);
        if (!crime) return null;

        return el('div', { class: `charge-row ${COLORS[crime.category]}` },
            el('span', { class: 'grow' }, el('strong', { text: count > 1 ? `${crime.title} ×${count}` : crime.title }),
                el('small', { class: 'block muted', text: crimeText(crime) })),
            onChange ? el('button', { class: 'icon-btn', type: 'button', title: L('ui_remove'), onclick: () => {
                if (counts[id] > 1) counts[id] -= 1; else delete counts[id];
                onChange(counts);
            } }, icon('close', 16)) : null,
        );
    }).filter(Boolean);

    return rows.length ? rows : [el('p', { class: 'muted', text: L('ui_no_charges') })];
}

// { crimeId: n } from a saved charge list [{ id, count }]
export function countsOf(list) {
    const counts = {};
    for (const charge of list || []) counts[charge.id] = charge.count;
    return counts;
}
