// The Drugs tab: for each of city_drugs' drugs, the chain from raw material to sale (where, what turns into what, what
// it pays) and how much it draws the police. Places can be set as the map waypoint.

import { el, L, icon, pill, money, heading } from './ui.js';
import { app } from './main.js';

const RISK_KIND = { low: 'good-pill', medium: 'warn-pill', high: 'bad' };

function gps(coords, label) {
    return el('button', { class: 'kit-btn small', onclick: () => window.CityOS.send('gps', { x: coords.x, y: coords.y }) }, icon('place', 14, 2), ` ${label || L('ui_gps')}`);
}

function items(list) {
    return list.map((item) => `${item.count}× ${item.label}`).join(', ');
}

function step(title, iconName, ...rows) {
    return el('div', { class: 'step' },
        el('div', { class: 'step-head' }, el('span', { class: 'tile-icon small grey' }, icon(iconName, 14, 2)), el('strong', { text: title })),
        ...rows);
}

function drugCard(drug) {
    const risk = drug.risk;

    return el('div', { class: 'card drug' },
        el('div', { class: 'card-head' },
            el('h2', { text: drug.label }),
            pill(L(`ui_risk_${drug.level}`), RISK_KIND[drug.level] || ''),
            el('span', { class: 'spacer' }),
            drug.gangOnly ? pill(L('ui_gang_only'), 'blue') : null),
        el('div', { class: 'steps' },
            step(L('ui_step_gather'), 'leaf', ...drug.gather.map((spot) => el('div', { class: 'step-row' },
                el('span', { class: 'grow' }, el('strong', { text: spot.item }), el('small', { class: 'muted', text: spot.inside ? ` · ${L('ui_inside', spot.inside)}` : ` · ${spot.label}` })),
                gps(spot.coords)))),
            drug.lab ? step(L('ui_step_process'), 'flask',
                el('div', { class: 'step-row' }, el('strong', { class: 'grow', text: drug.lab.label }), gps(drug.lab.coords)),
                ...drug.lab.recipes.map((recipe) => el('div', { class: 'recipe' },
                    el('small', { class: 'muted', text: `${recipe.label} · ${L('ui_seconds', recipe.seconds)}` }),
                    el('span', { text: `${items(recipe.inputs)}  →  ${items(recipe.outputs)}` })))) : null,
            step(L('ui_step_sell'), 'money',
                ...drug.corner.map((offer) => el('div', { class: 'recipe' }, el('span', { text: L('ui_corner', offer.item, offer.min, offer.max, offer.maxUnits) }))),
                ...drug.deals.map((deal) => el('div', { class: 'recipe' }, el('span', { text: L('ui_deal', `${deal.min}–${deal.max}`, deal.item, money(deal.price).slice(1)) })))),
        ),
        el('div', { class: 'risk' }, icon('warn', 16, 2),
            el('small', { text: L('ui_police_chance', risk.pick, risk.lab, risk.sale, risk.perPoint, risk.max) })),
    );
}

export async function renderDrugs() {
    const guide = app.guide;
    if (!guide) return el('div', { class: 'empty', text: L('error_unavailable') });

    return el('div', { class: 'stack' },
        heading(L('ui_tab_drugs')),
        el('small', { class: 'muted', text: L('ui_drugs_help') }),
        el('div', { class: 'card dealer' },
            el('span', { class: 'tile-icon gold' }, icon('cart', 18, 2)),
            el('small', { class: 'grow', text: L('ui_dealer', guide.dealMinutes) }),
            guide.dealsGangOnly ? pill(L('ui_gang_only'), 'blue') : null,
            gps(guide.dealer, L('ui_dealer_gps'))),
        ...guide.drugs.map(drugCard),
    );
}
