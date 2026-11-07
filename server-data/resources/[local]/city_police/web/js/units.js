import { el, L, run, heading, duration, empty, pill } from './ui.js';
import { app, go, refresh, setMyStatus } from './main.js';

function gradeName(level) {
    const grade = (app.grades || []).find((entry) => entry.level === level);
    return grade ? grade.name : String(level);
}

// The status card in the sidebar opens the Units tab, where the officer's own controls are
export function pickStatus() {
    go('units');
}

function myControls() {
    const callsign = el('input', { class: 'field', type: 'text', maxlength: 6, value: app.me.callsign || '', placeholder: 'A-12' });

    const statuses = el('div', { class: 'status-picker' }, app.statuses.map((status) => el('button', {
        class: `status-btn ${status}${app.me.status === status ? ' on' : ''}`,
        onclick: async () => {
            const result = await run('setStatus', { status });
            if (!result) return;
            setMyStatus(status);
            refresh();
        },
    }, el('i', { class: `dot ${status}` }), L(`status_${status}`))));

    return el('div', { class: 'card' },
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_my_unit') })),
        statuses,
        el('div', { class: 'form-row' },
            el('span', { class: 'label', text: L('ui_callsign') }), callsign,
            el('button', { class: 'kit-btn', onclick: async () => {
                const result = await run('setCallsign', { callsign: callsign.value }, L('ui_saved'));
                if (result) app.me.callsign = callsign.value.toUpperCase();
            } }, L('ui_save')),
        ),
    );
}

export async function renderUnits() {
    const response = await run('units');
    const units = response ? response.data : [];
    const now = Date.now() / 1000;

    const table = el('div', { class: 'card flush' },
        el('div', { class: 'table-head unit-cols' },
            el('span', { text: L('ui_unit') }), el('span', { text: L('ui_rank') }), el('span', { text: L('ui_status') }),
            el('span', { text: L('ui_call') }), el('span', { text: L('ui_vehicle') }), el('span', { text: L('ui_on_duty_for') })),
        units.length ? units.map((unit) => el('div', { class: 'table-row unit-cols' },
            el('span', { class: 'person' }, el('span', { class: 'callsign', text: unit.callsign || '—' }), el('strong', { text: unit.name })),
            el('span', { class: 'muted', text: gradeName(unit.grade) }),
            el('span', {}, pill(L(`status_${unit.status}`), `status ${unit.status}`)),
            el('span', {}, unit.call ? el('button', { class: 'link', text: `#${unit.call}`, onclick: () => go('dispatch', { id: unit.call }) }) : '—'),
            el('span', { class: 'muted', text: unit.vehicle || '—' }),
            el('span', { class: 'muted', text: duration(now - unit.since) }),
        )) : empty(L('ui_no_units')),
    );

    return el('div', { class: 'stack' },
        heading(L('ui_tab_units'), el('span', { class: 'pill', text: L('ui_units_count', units.length) })),
        myControls(),
        table,
    );
}
