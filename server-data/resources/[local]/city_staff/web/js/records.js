import { el, L, run, icon, heading, pill, confirmButton, searchField, formatTime, shortName } from './ui.js';
import { can, go } from './main.js';

// The icon and color each staff log action gets
export const ACTION_LOOK = {
    ban: ['ban', 'red'], kick: ['kick', 'red'], kill: ['kill', 'red'], unban: ['check', 'green'],
    warn: ['warn', 'gold'], closeReport: ['check', 'green'], claimReport: ['reports', 'blue'], replyReport: ['reports', 'blue'],
    goto: ['goto', 'blue'], bring: ['bring', 'blue'], spectate: ['spectate', 'blue'],
    heal: ['heal', 'red'], revive: ['revive', 'red'], freeze: ['freeze', 'blue'], unfreeze: ['freeze', 'blue'],
    inventory: ['inventory', 'grey'], cuff: ['cuff', 'grey'], clothing: ['clothing', 'grey'], bucket: ['bucket', 'grey'],
    setJob: ['job', 'grey'], setGang: ['gang', 'grey'],
    spawnVehicle: ['vehicle', 'grey'],
};

export async function renderBans() {
    const response = await run('bans');
    const bans = response ? response.data : [];

    return el('div', { class: 'stack' },
        heading(L('ui_tab_bans'), pill(L('ui_active_bans', bans.length))),
        el('div', { class: 'card flush' }, bans.length ? bans.map((ban) => el('div', { class: 'info-row tall' },
            el('span', { class: 'tile-icon red' }, icon('ban', 18, 2)),
            el('div', { class: 'who grow' }, el('strong', { text: ban.name || ban.license || '?' }), el('small', { text: ban.reason })),
            el('small', { class: 'muted', text: `${ban.permanent ? L('permanent') : L('ui_until', formatTime(ban.expire))} · ${shortName(ban.bannedby)}` }),
            can('unban') ? confirmButton(L('ui_unban'), async () => (await run('unban', { id: ban.id }, L('ui_unbanned'))) && go('bans'), '') : null,
        )) : el('div', { class: 'list-empty', text: L('ui_no_bans') })),
        el('small', { class: 'muted', text: L('ui_bans_foot') }),
    );
}

export async function renderLog() {
    const response = await run('log');
    const entries = response ? response.data : [];
    let filter = '';

    const list = el('div', { class: 'card flush' });
    const draw = () => {
        const shown = entries.filter((entry) => !filter || [entry.staff_name, entry.action, L(`action_${entry.action}`), entry.target_name, entry.details]
            .some((value) => value && value.toLowerCase().includes(filter)));

        list.replaceChildren(...(shown.length ? shown.map((entry) => {
            const [iconName, kind] = ACTION_LOOK[entry.action] || ['tools', 'grey'];

            return el('div', { class: 'info-row tall' },
                el('small', { class: 'time', text: formatTime(entry.time) }),
                el('span', { class: `tile-icon ${kind}` }, icon(iconName, 16, 2)),
                el('span', { class: 'grow' }, el('strong', { text: shortName(entry.staff_name) }), ` ${L(`action_${entry.action}`)} `, entry.target_name ? el('strong', { text: shortName(entry.target_name) }) : null),
                el('small', { class: 'muted', text: entry.details || '' }),
            );
        }) : [el('div', { class: 'list-empty', text: L('ui_no_log') })]));
    };

    draw();

    return el('div', { class: 'stack' },
        heading(L('ui_tab_log')),
        searchField(L('ui_search_log'), (value) => {
            filter = value;
            draw();
        }),
        list,
    );
}
