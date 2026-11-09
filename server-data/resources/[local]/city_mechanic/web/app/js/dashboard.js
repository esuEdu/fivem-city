import { app, state, setCalls, setDuty } from './main.js';

const { el, L, run, icon, heading, pill, tile, bars, avatar, money, since } = window.WorkApp;

export function serviceRow(service) {
    return el('div', { class: 'table-row service-cols' },
        el('span', { class: 'plate', text: service.plate }),
        el('div', { class: 'who' }, el('strong', { text: service.name }), el('small', { text: since(service.created) })),
        el('div', { class: 'chips' }, partChips(service)),
        el('strong', { class: 'value', text: money(service.total) }),
    );
}

export function partChips(service, max = 3) {
    const chips = service.parts.slice(0, max).map((part) => el('span', { class: 'chip', text: part }));
    if (service.parts.length > max) chips.push(el('span', { class: 'chip muted', text: `+${service.parts.length - max}` }));
    if (service.repaired) chips.unshift(el('span', { class: 'chip tint-chip', text: L('ui_repaired') }));
    if (service.staff) chips.unshift(el('span', { class: 'chip blue-chip', text: L('ui_staff') }));
    return chips;
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
            tile('wrench', 'blue', L('ui_tile_today'), String(data.today), L('ui_tile_today_sub', money(data.todayValue))),
            tile('star', 'gold', L('ui_tile_mine'), String(data.mine), L('ui_tile_mine_sub', data.week)),
        ),
        el('div', { class: 'two-cols' },
            el('div', { class: 'card' },
                el('div', { class: 'card-head' }, el('strong', { text: L('ui_chart_title') }), el('span', { class: 'spacer' }), el('small', { class: 'muted', text: L('ui_last_7_days') })),
                bars(data.days.map((day) => ({ label: day.label, value: day.value, title: L('ui_chart_n', day.value) })))),
            onDutyCard(data.onDuty)),
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_latest_services') }), el('span', { class: 'spacer' }),
                el('button', { class: 'link', text: L('ui_see_all'), onclick: () => app.go('services') })),
            data.latest.length ? data.latest.map(serviceRow) : el('div', { class: 'table-row muted', text: L('ui_no_services') })),
    );
}
