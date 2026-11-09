// The 555 calls: city_dispatch's open calls for mechanics on duty. Respond sets the GPS; whoever responds can close it.
import { app, setCalls, setDuty } from './main.js';

const { el, L, run, icon, heading, pill, ago, confirmButton } = window.WorkApp;

const KIND_ICONS = { Breakdown: 'engine', 'Flat tyre': 'tyre', Tow: 'tow' };

let calls = [];
let selected = null;

// Off duty, city_dispatch answers "no": the list is then empty and the tab says why
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

function kindIcon(call) {
    return KIND_ICONS[call.kind] || 'wrench';
}

function callCard(call) {
    return el('button', { class: `call-card${selected === call.id ? ' on' : ''}`, onclick: () => app.go('calls', { id: call.id }) },
        el('div', { class: 'call-top' },
            el('span', { class: 'call-icon' }, icon(kindIcon(call), 18, 2)),
            el('strong', { text: call.kind }),
            el('span', { class: 'spacer' }),
            el('small', { text: ago(call.ago) })),
        el('small', { class: 'call-place', text: call.place }),
        el('div', { class: 'pills' },
            call.responding ? pill(L('ui_you_respond'), 'tint') : null,
            call.responders > 0 && !call.responding ? pill(L('ui_responders', call.responders), 'blue') : null,
            call.responders === 0 ? pill(L('ui_no_responders')) : null),
    );
}

function detail(call) {
    if (!call) return el('div', { class: 'empty', text: calls.length ? L('ui_pick_call') : '' });

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('span', { class: 'big-icon' }, icon(kindIcon(call), 28, 2)),
            el('div', { class: 'who grow' },
                el('h2', { text: call.kind }),
                el('small', { text: L('ui_call_number', call.id, ago(call.ago)) })),
            call.responding ? pill(L('ui_you_respond'), 'tint') : null),
        el('div', { class: 'card flush' },
            el('div', { class: 'info-row' }, icon('user', 18), el('span', { text: L('ui_caller') }), el('span', { class: 'value', text: call.caller })),
            el('div', { class: 'info-row' }, icon('place', 18), el('span', { text: L('ui_location') }), el('span', { class: 'value', text: call.place })),
            el('div', { class: 'info-row' }, icon('players', 18), el('span', { text: L('ui_responding') }), el('span', { class: 'value', text: String(call.responders) }))),
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
            }, icon('route', 18, 2), call.responding ? L('ui_gps_again') : L('ui_respond')),
            call.responding ? confirmButton([icon('check', 18, 2), L('ui_close_call')], async () => {
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

