// Activity: who moved what in and out of the vault, money, recruits and goal changes, newest first.
const { el, L, run, heading, pill, since } = window.WorkApp;

export function logHead() {
    return el('div', { class: 'table-head log-cols' }, ['ui_when', 'ui_member', 'ui_action', 'ui_details'].map((key) => el('span', { text: L(key) })));
}

export function logRow(entry) {
    const out = entry.action === 'vault_out' || entry.action === 'money_out' || entry.action === 'fire';

    return el('div', { class: 'table-row log-cols' },
        el('small', { class: 'muted', text: since(entry.created) }),
        el('strong', { text: entry.name }),
        el('span', { class: out ? 'loss' : '', text: L(`action_${entry.action}`) }),
        el('span', { class: 'muted', text: entry.details || '' }),
    );
}

export async function renderActivity() {
    const response = await run('activity');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const rows = response.data;

    return el('div', { class: 'stack' },
        heading(L('ui_tab_activity'), pill(String(rows.length))),
        el('div', { class: 'card flush' },
            logHead(),
            rows.length ? rows.map(logRow) : el('div', { class: 'table-row muted', text: L('ui_no_activity') })),
    );
}
