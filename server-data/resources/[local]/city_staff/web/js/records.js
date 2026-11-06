import { el, L, run, section, confirmButton, searchField, formatTime } from './ui.js';
import { can, go } from './main.js';

export async function renderBans() {
    const response = await run('bans');
    const bans = response ? response.data : [];

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { class: 'kit-heading', text: L('ui_tab_bans') }), el('span', { class: 'kit-pill', text: L('ui_active_bans', bans.length) })),
        section(null, bans.length ? bans.map((ban) => el('div', { class: 'kit-row entry' },
            el('span', { class: 'who' }, el('strong', { text: ban.name || ban.license || '?' }), el('small', { text: ban.reason })),
            el('small', { class: 'kit-value', text: `${ban.permanent ? L('permanent') : L('ui_until', formatTime(ban.expire))} · ${ban.bannedby}` }),
            can('unban') ? confirmButton(L('ui_unban'), async () => (await run('unban', { id: ban.id }, L('ui_unbanned'))) && go('bans'), '') : null,
        )) : [el('div', { class: 'kit-row muted', text: L('ui_no_bans') })], L('ui_bans_foot')),
    );
}

export async function renderLog() {
    const response = await run('log');
    const entries = response ? response.data : [];
    let filter = '';

    const list = el('div', { class: 'kit-group' });
    const draw = () => {
        const shown = entries.filter((entry) => !filter || [entry.staff_name, entry.action, entry.target_name, entry.details]
            .some((value) => value && value.toLowerCase().includes(filter)));

        list.replaceChildren(...(shown.length ? shown.map((entry) => el('div', { class: 'kit-row entry log' },
            el('small', { class: 'time', text: formatTime(entry.time) }),
            el('span', { class: 'who' },
                el('strong', { text: `${entry.staff_name} · ${L(`action_${entry.action}`)}` }),
                el('small', { text: [entry.target_name, entry.details].filter(Boolean).join(' · ') }),
            ),
        )) : [el('div', { class: 'kit-row muted', text: L('ui_no_log') })]));
    };

    draw();

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { class: 'kit-heading', text: L('ui_tab_log') })),
        searchField(L('ui_search_log'), (value) => {
            filter = value;
            draw();
        }),
        list,
    );
}
