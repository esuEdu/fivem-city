// Dashboard: members online, the organization's money, the week's deliveries (faction and own), a 7-day chart and
// the latest activity.
import { app, state } from './main.js';
import { logRow, logHead } from './activity.js';

const { el, L, run, heading, pill, tile, bars, avatar, money } = window.WorkApp;

function onlineCard(list) {
    return el('div', { class: 'card' },
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_online_now') }), el('span', { class: 'spacer' }), pill(String(list.length), 'green')),
        list.length
            ? el('div', { class: 'duty-list' }, list.map((member) => el('div', { class: 'person' },
                avatar(member.name, 'on'),
                el('div', { class: 'who' }, el('strong', { text: member.name }), el('small', { text: member.grade })))))
            : el('small', { class: 'muted', text: L('ui_nobody_online') }),
    );
}

export async function renderDashboard() {
    const response = await run('dashboard');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;

    return el('div', { class: 'stack' },
        heading(L('ui_tab_dashboard'), el('span', { class: 'spacer' }), pill(state.grade, 'blue')),
        el('div', { class: 'tiles' },
            tile('players', 'green', L('ui_tile_members'), String(data.members), L('ui_tile_members_sub', data.online.length)),
            tile('money', 'gold', L('ui_tile_balance'), money(data.balance), L('ui_tile_balance_sub')),
            tile('vault', 'tint', L('ui_tile_week'), String(data.weekNet), L('ui_tile_week_sub')),
            tile('star', 'blue', L('ui_tile_mine'), String(data.mine.net), L('ui_tile_mine_sub', data.mine.deposited, data.mine.withdrawn)),
        ),
        el('div', { class: 'two-cols' },
            el('div', { class: 'card' },
                el('div', { class: 'card-head' }, el('strong', { text: L('ui_chart_title') }), el('span', { class: 'spacer' }), el('small', { class: 'muted', text: L('ui_last_7_days') })),
                bars(data.days.map((day) => ({ label: day.label, value: day.value, title: L('ui_chart_n', day.value) })))),
            onlineCard(data.online)),
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_latest_activity') }), el('span', { class: 'spacer' }),
                el('button', { class: 'link', text: L('ui_see_all'), onclick: () => app.go('activity') })),
            logHead(),
            data.latest.length ? data.latest.map(logRow) : el('div', { class: 'table-row muted', text: L('ui_no_activity') })),
    );
}
