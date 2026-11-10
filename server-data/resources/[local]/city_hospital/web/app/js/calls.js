// EMS calls: a downed player's SOS, 192 phone calls, the emergency button and officer down (server/sos.lua). Accept
// sets the GPS and tells the patient; whoever accepted can close the call.
import { app, setCalls, setDuty } from './main.js';

const { el, L, run, icon, heading, pill, ago, confirmButton } = window.WorkApp;

const KIND_ICONS = { sos: 'sos', phone: 'phone', emergency: 'bell', officer: 'officer' };

let calls = [];
let selected = null;

// Off duty there are no calls: the list is then empty and the tab says why
export async function loadCalls() {
    const response = await window.CityOS.send('run', { action: 'calls', args: {} });

    if (!response || !response.ok) {
        calls = [];
        setDuty(false);
        setCalls(0);
        return false;
    }

    calls = response.data;
    setDuty(true);
    setCalls(calls.length);
    return true;
}

function kindLabel(call) {
    return L(`call_kind_${call.kind}`);
}

function taken(call) {
    if (call.mine) return pill(L('ui_you_respond'), 'tint');
    if (call.acceptedBy) return pill(L('ui_taken_by', call.acceptedBy), 'blue');
    return pill(L('ui_no_responders'));
}

function callCard(call) {
    return el('button', { class: `call-card${selected === call.id ? ' on' : ''}`, onclick: () => app.go('calls', { id: call.id }) },
        el('div', { class: 'call-top' },
            el('span', { class: 'call-icon' }, icon(KIND_ICONS[call.kind] || 'bell', 18, 2)),
            el('strong', { text: kindLabel(call) }),
            el('span', { class: 'spacer' }),
            el('small', { text: ago(call.ago) })),
        el('small', { class: 'call-place', text: call.place }),
        el('div', { class: 'pills' }, taken(call)),
    );
}

function detail(call) {
    if (!call) return el('div', { class: 'empty', text: calls.length ? L('ui_pick_call') : '' });

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('span', { class: 'big-icon' }, icon(KIND_ICONS[call.kind] || 'bell', 28, 2)),
            el('div', { class: 'who grow' },
                el('h2', { text: kindLabel(call) }),
                el('small', { text: L('ui_call_number', call.id, ago(call.ago)) })),
            taken(call)),
        el('div', { class: 'card flush' },
            el('div', { class: 'info-row' }, icon('place', 18), el('span', { text: L('ui_location') }), el('span', { class: 'value', text: call.place })),
            el('div', { class: 'info-row' }, icon('user', 18), el('span', { text: L('ui_accepted_by') }), el('span', { class: 'value', text: call.acceptedBy || '—' }))),
        call.text ? el('div', { class: 'card' }, el('strong', { class: 'card-title', text: L('ui_message') }), el('div', { class: 'note', text: call.text })) : null,
        el('div', { class: 'form-row' },
            el('button', {
                class: 'kit-btn tint big',
                onclick: async () => {
                    if (await run('respond', { id: call.id }, L('ui_gps_set'))) {
                        await loadCalls();
                        app.go('calls', { id: call.id });
                    }
                },
            }, icon('route', 18, 2), call.mine ? L('ui_gps_again') : L('ui_respond')),
            call.mine ? confirmButton([icon('check', 18, 2), L('ui_close_call')], async () => {
                if (await run('close', { id: call.id }, L('ui_call_closed'))) {
                    selected = null;
                    await loadCalls();
                    app.go('calls');
                }
            }, 'kit-btn success big') : null),
    );
}

export async function renderCalls(args) {
    const onDuty = await loadCalls();

    if (!onDuty) {
        return el('div', { class: 'stack' },
            heading(L('ui_tab_calls')),
            el('div', { class: 'card empty-card' }, el('span', { class: 'big-icon' }, icon('clock', 28, 2)),
                el('strong', { text: L('ui_off_duty') }), el('small', { class: 'muted', text: L('ui_calls_off_duty') })));
    }

    if (args && args.id) selected = args.id;
    if (!calls.some((call) => call.id === selected)) selected = calls.length ? calls[0].id : null;

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            heading(L('ui_tab_calls'), el('span', { class: 'spacer' }), pill(String(calls.length), calls.length ? 'tint' : '')),
            calls.length
                ? el('div', { class: 'call-list' }, calls.map(callCard))
                : el('div', { class: 'card empty-card' }, el('span', { class: 'big-icon' }, icon('check', 28, 2)),
                    el('strong', { text: L('ui_no_calls') }), el('small', { class: 'muted', text: L('ui_no_calls_sub') }))),
        el('div', { class: 'split-detail' }, detail(calls.find((call) => call.id === selected))),
    );
}
