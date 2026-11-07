import { el, L, run, icon, ago, formatTime, empty, confirmButton } from './ui.js';
import { app, can, go, refresh, setCallCount } from './main.js';
import { callRow } from './dashboard.js';

let selected = null;

export async function renderDispatch(args) {
    if (args && args.id) selected = args.id;

    const response = await run('calls');
    const calls = response ? response.data : [];
    setCallCount(calls.length);

    if (!calls.some((call) => call.id === selected)) selected = calls.length ? calls[0].id : null;
    const call = calls.find((entry) => entry.id === selected);

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_dispatch') }), el('span', { class: 'pill', text: String(calls.length) })),
            el('div', { class: 'list' }, calls.length
                ? calls.map((entry) => {
                    const row = callRow(entry, () => go('dispatch', { id: entry.id }));
                    if (entry.id === selected) row.classList.add('on');
                    return row;
                })
                : empty(L('ui_no_calls'))),
        ),
        el('div', { class: 'split-detail' }, call ? callDetail(call) : el('div', { class: 'empty' }, icon('dispatch', 40), el('p', { text: L('ui_no_calls') }))),
    );
}

function callDetail(call) {
    const act = (action, done) => async () => {
        const result = await run(action, { id: call.id }, done);
        if (result) refresh();
    };

    const note = el('input', { class: 'field', type: 'text', maxlength: 160, placeholder: L('ui_add_note'),
        onfocus: () => { app.editing = true; },
        onblur: () => { app.editing = false; },
    });

    const sendNote = async () => {
        if (!note.value.trim()) return;
        const result = await run('callNote', { id: call.id, text: note.value });
        if (result) {
            app.editing = false;
            refresh();
        }
    };
    note.addEventListener('keydown', (event) => { if (event.key === 'Enter') sendNote(); });

    const canClose = call.attached || can('issueWarrant');

    return el('div', { class: 'stack' },
        el('div', { class: 'card call-head' },
            el('div', { class: 'heading' },
                el('span', { class: `code big${call.priority === 2 ? ' urgent' : ''}`, text: call.code }),
                el('h2', { text: call.title }),
                el('span', { class: 'spacer' }),
                el('span', { class: 'pill', text: L(`call_kind_${call.kind}`) }),
            ),
            call.text ? el('p', { class: 'call-text', text: call.text }) : null,
            el('div', { class: 'info-list' },
                el('div', { class: 'info-row' }, icon('place', 18), el('span', { text: L('ui_location') }), el('span', { class: 'value', text: call.place || '—' })),
                el('div', { class: 'info-row' }, icon('clock', 18), el('span', { text: L('ui_received') }), el('span', { class: 'value', text: `${formatTime(call.at)} (${ago(call.at)})` })),
                call.caller ? el('div', { class: 'info-row' }, icon('phone', 18), el('span', { text: L('ui_caller') }), el('span', { class: 'value', text: call.caller })) : null,
            ),
            el('div', { class: 'button-row' },
                call.attached
                    ? el('button', { class: 'kit-btn', onclick: act('callDetach', L('ui_detached')) }, L('ui_detach'))
                    : el('button', { class: 'kit-btn accent', onclick: act('callAttach', L('ui_attached')) }, L('ui_attach')),
                el('button', { class: 'kit-btn', onclick: act('callGps', L('ui_gps_set')) }, L('ui_gps')),
                el('span', { class: 'spacer' }),
                canClose ? confirmButton(L('ui_close_call'), act('callClose', L('ui_call_closed'))) : null,
            ),
        ),
        el('div', { class: 'card' },
            el('div', { class: 'card-head' }, el('strong', { text: L('ui_units_on_call') })),
            call.units.length
                ? el('div', { class: 'chips' }, call.units.map((unit) => el('span', { class: 'chip big', text: unit.callsign ? `${unit.callsign} · ${unit.name}` : unit.name })))
                : el('p', { class: 'muted', text: L('ui_no_units_on_call') }),
        ),
        el('div', { class: 'card' },
            el('div', { class: 'card-head' }, el('strong', { text: L('ui_notes') })),
            call.notes.length
                ? el('div', { class: 'notes' }, call.notes.map((entry) => el('div', { class: 'note' },
                    el('p', { text: entry.text }), el('small', { text: `${entry.name} · ${ago(entry.at)}` }))))
                : null,
            el('div', { class: 'form-row' }, note, el('button', { class: 'kit-btn', onclick: sendNote }, L('ui_send'))),
        ),
    );
}
