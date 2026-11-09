import { app, state, setCalls, setDuty } from './main.js';

const { el, L, run, icon, heading, pill, tile, bars, avatar, money, since } = window.WorkApp;

export function kindPill(record) {
    return record.kind === 'revive' ? pill(L('ui_kind_revive'), 'tint') : pill(L('ui_kind_bill'), 'green');
}

export function recordRow(record) {
    return el('div', { class: 'table-row record-cols' },
        el('span', { class: 'kind' }, kindPill(record)),
        el('div', { class: 'who' }, el('strong', { text: record.patient }), el('small', { text: since(record.created) })),
        el('div', { class: 'who' }, el('span', { text: record.name }), record.note ? el('small', { class: 'record-note', text: record.note }) : null),
        el('span'),
        el('strong', { class: 'value', text: record.kind === 'bill' ? money(record.amount) : '—' }),
    );
}

function onDutyCard(list) {
    return el('div', { class: 'card' },
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_on_duty_now') }), el('span', { class: 'spacer' }), pill(String(list.length), 'green')),
        list.length
            ? el('div', { class: 'duty-list' }, list.map((member) => el('div', { class: 'person' },
                avatar(member.name, 'on'),
                el('div', { class: 'who' }, el('strong', { text: member.name }), el('small', { text: member.grade })))))
            : el('small', { class: 'muted', text: L('ui_nobody_on_duty') }),
    );
}

export async function renderDashboard() {
    const response = await run('dashboard');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;
    setCalls(data.calls);
    setDuty(data.myDuty);

    return el('div', { class: 'stack' },
        heading(L('ui_tab_dashboard'), el('span', { class: 'spacer' }),
            pill(state.onDuty ? L('ui_on_duty') : L('ui_off_duty'), state.onDuty ? 'green' : '')),
        state.onDuty ? null : el('div', { class: 'banner' }, icon('clock', 18, 2), el('span', { text: L('ui_clock_in_hint') })),
        el('div', { class: 'tiles' },
            tile('players', 'green', L('ui_tile_on_duty'), String(data.onDuty.length), L('ui_tile_on_duty_sub')),
            tile('bell', 'tint', L('ui_tile_calls'), String(data.calls), data.calls > 0 ? L('ui_tile_calls_waiting') : L('ui_tile_calls_none'), data.calls > 0 ? 'warn' : ''),
            tile('heart', 'red', L('ui_tile_revives'), String(data.revives), L('ui_tile_billed', money(data.billed))),
            tile('star', 'gold', L('ui_tile_mine'), String(data.mine), L('ui_tile_mine_sub', data.week)),
        ),
        el('div', { class: 'two-cols' },
            el('div', { class: 'card' },
                el('div', { class: 'card-head' }, el('strong', { text: L('ui_chart_title') }), el('span', { class: 'spacer' }), el('small', { class: 'muted', text: L('ui_last_7_days') })),
                bars(data.days.map((day) => ({ label: day.label, value: day.value, title: L('ui_chart_n', day.value) })))),
            onDutyCard(data.onDuty)),
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_latest_records') }), el('span', { class: 'spacer' }),
                el('button', { class: 'link', text: L('ui_see_all'), onclick: () => app.go('records') })),
            data.latest.length ? data.latest.map(recordRow) : el('div', { class: 'table-row muted', text: L('ui_no_records') })),
    );
}
