import { el, L, run, icon, heading, duration, money, ago, empty } from './ui.js';
import { app, can, go, setCallCount, setMyStatus } from './main.js';

function tile(iconName, color, label, value, sub, tab) {
    return el('button', { class: 'card tile', onclick: tab ? () => go(tab) : null },
        el('div', { class: 'tile-head' }, el('span', { class: `tile-icon ${color}` }, icon(iconName, 18)), el('span', { text: label })),
        el('div', { class: 'tile-value', text: String(value) }),
        sub ? el('div', { class: 'tile-sub', text: sub }) : null,
    );
}

export function callRow(call, onclick) {
    return el('button', { class: `call-row${call.priority === 2 ? ' urgent' : ''}`, onclick },
        el('span', { class: `code${call.priority === 2 ? ' urgent' : ''}`, text: call.code }),
        el('span', { class: 'who' },
            el('strong', { text: call.title }),
            el('small', { text: [call.place, ago(call.at)].filter(Boolean).join(' · ') }),
        ),
        el('span', { class: 'pill', title: L('ui_units_count', call.units.length) }, icon('units', 14), ` ${call.units.length}`),
    );
}

export async function renderDashboard() {
    const response = await run('dashboard');
    if (!response) return empty(L('error_failed'));

    const data = response.data;
    setCallCount(data.openCalls);
    setMyStatus(data.me.status);

    const calls = el('div', { class: 'card flush' },
        el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_open_calls') }), el('span', { class: 'spacer' }),
            can('dispatch') ? el('button', { class: 'link', text: L('ui_see_all'), onclick: () => go('dispatch') }) : null),
        data.calls.length ? data.calls.map((call) => callRow(call, () => go('dispatch', { id: call.id }))) : empty(L('ui_no_calls')),
    );

    const notices = el('div', { class: 'card' },
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_notices') })),
        data.notices.length
            ? el('div', { class: 'notices' }, data.notices.map((notice) => el('div', { class: 'notice' },
                el('p', { text: notice.text }),
                el('small', { text: `${notice.author} · ${ago(notice.created)}` }))))
            : empty(L('ui_no_notices')),
    );

    const me = data.me;
    const shift = el('div', { class: 'card shift' },
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_my_shift') })),
        el('div', { class: 'mini-grid' },
            el('div', { class: 'mini' }, el('strong', { text: duration(data.shiftSeconds) }), el('small', { text: L('ui_on_duty_for') })),
            el('div', { class: 'mini' }, el('strong', { text: me.callsign || '—' }), el('small', { text: L('ui_callsign') })),
            el('div', { class: 'mini' }, el('strong', { text: L(`status_${me.status || 'available'}`) }), el('small', { text: L('ui_status') })),
            el('div', { class: 'mini' }, el('strong', { text: String(me.certs.length) }), el('small', { text: L('ui_certifications') })),
        ),
    );

    return el('div', { class: 'stack' },
        heading(L('ui_good_shift', (app.me.name || '').split(' ')[0])),
        el('div', { class: 'tiles' },
            tile('dispatch', 'red', L('ui_open_calls'), data.openCalls, null, can('dispatch') ? 'dispatch' : null),
            tile('units', 'blue', L('ui_units_on_duty'), data.units, null, 'units'),
            tile('warrants', 'gold', L('ui_active_warrants'), data.warrants, null, can('warrants') ? 'warrants' : null),
            can('bolos') ? tile('bolos', 'blue', L('ui_active_bolos'), data.bolos, null, 'bolos') : null,
            tile('charges', 'green', L('ui_today'), L('ui_arrests_fines', data.arrests, data.fines), money(data.fined)),
            tile('impounds', 'grey', L('ui_impounded'), data.impounds, null, can('impound') ? 'impounds' : null),
        ),
        el('div', { class: 'two-cols' }, calls, el('div', { class: 'stack small' }, shift, notices)),
    );
}
