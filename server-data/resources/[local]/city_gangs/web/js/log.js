// The Log tab: who joined, was promoted, demoted or kicked out, and what members made and sold.

import { el, L, run, icon, money, ago, heading, drugLabel } from './ui.js';

export const LOOK = {
    hire: ['recruit', 'green'],
    promote: ['up', 'blue'],
    demote: ['down', 'grey'],
    fire: ['kick', 'red'],
    leave: ['kick', 'grey'],
    sale: ['money', 'green'],
    made: ['flask', 'purple'],
};

export function line(entry) {
    if (entry.action === 'sale') return [el('strong', { text: entry.actor }), ` ${L('action_sale', drugLabel(entry.details))} `, el('strong', { class: 'good', text: money(entry.amount) })];
    if (entry.action === 'made') return [el('strong', { text: entry.actor }), ` ${L('action_made', drugLabel(entry.details))} ${entry.amount}`];

    return [
        el('strong', { text: entry.actor }), ` ${L(`action_${entry.action}`)} `,
        entry.target ? el('strong', { text: entry.target }) : null,
        entry.details ? el('span', { class: 'muted', text: ` · ${entry.details}` }) : null,
    ];
}

export async function renderLog() {
    const response = await run('log');
    const entries = response ? response.data : [];

    return el('div', { class: 'stack' },
        heading(L('ui_tab_log')),
        el('div', { class: 'card flush' }, entries.length ? entries.map((entry) => {
            const [iconName, kind] = LOOK[entry.action] || ['log', 'grey'];
            return el('div', { class: 'info-row' },
                el('span', { class: `tile-icon small ${kind}` }, icon(iconName, 14, 2)),
                el('span', { class: 'grow' }, ...line(entry)),
                el('small', { class: 'muted', text: ago(entry.time) }));
        }) : el('div', { class: 'list-empty', text: L('ui_log_empty') })),
    );
}
