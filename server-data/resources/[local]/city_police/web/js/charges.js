import { el, L, run, icon, money, labeled, confirmButton, toast } from './ui.js';
import { app, go } from './main.js';
import { personPicker, crimeList, totals, chargeList } from './picker.js';

// The penal code, and charging a person with a fine or an arrest. The server works the totals out again.
export async function renderCharges(args) {
    app.editing = true;

    const nearbyResponse = await run('nearby');
    const nearby = nearbyResponse ? nearbyResponse.data : [];

    let target = null;
    if (args && args.citizenid) {
        const close = nearby.find((entry) => entry.citizenid === args.citizenid);
        target = { citizenid: args.citizenid, name: args.name, id: close ? close.id : null };
    }

    const counts = {};
    const notes = el('input', { class: 'field', type: 'text', maxlength: 160, placeholder: L('ui_notes_optional') });
    const who = el('div', { class: 'stack small' });
    const summary = el('div', { class: 'summary' });
    const buttons = el('div', { class: 'button-row' });

    const drawSummary = () => {
        const sum = totals(app.penal, counts, app.maxMonths, app.maxFine);
        const picked = Object.keys(counts).length > 0;

        summary.replaceChildren(
            el('div', { class: 'mini' }, el('strong', { text: L('ui_months', sum.months) }), el('small', { text: L('ui_jail_time') })),
            el('div', { class: 'mini' }, el('strong', { text: money(sum.fine) }), el('small', { text: L('ui_fine') })),
            el('div', { class: 'mini' }, el('strong', { text: String(sum.points) }), el('small', { text: L('ui_points') })),
        );

        const charge = (kind) => async () => {
            if (!target) return toast(L('ui_pick_person_first'), 'bad');
            const result = await run('charge', { citizenid: target.citizenid, target: target.id, kind, charges: chargeList(counts), notes: notes.value },
                kind === 'arrest' ? L('ui_arrested_done') : L('ui_fined_done'));
            if (result) {
                app.editing = false;
                go('people', { citizenid: target.citizenid });
            }
        };

        buttons.replaceChildren(...[
            el('span', { class: 'spacer' }),
            picked && target ? confirmButton(el('span', {}, L('ui_fine_button', money(sum.fine))), charge('fine'), 'accent') : null,
            picked && target && target.id ? confirmButton(el('span', {}, L('ui_arrest_button', sum.months)), charge('arrest'), 'danger') : null,
        ].filter(Boolean));
    };

    const drawWho = () => {
        who.replaceChildren(
            target
                ? el('div', { class: 'form-row' }, el('span', { class: 'chip big' }, target.name, el('button', { class: 'chip-x', type: 'button', onclick: () => { target = null; drawWho(); drawSummary(); } }, '×')),
                    el('small', { class: 'muted', text: target.id ? L('ui_suspect_here') : L('ui_suspect_away') }))
                : el('div', { class: 'stack small' },
                    nearby.length ? el('div', { class: 'chips' }, nearby.map((person) => el('button', { class: 'chip big pick', type: 'button', onclick: () => { target = person; drawWho(); drawSummary(); } }, icon('user', 14), ' ', person.name))) : el('small', { class: 'muted', text: L('ui_nobody_near') }),
                    personPicker((person) => {
                        if (!person.online) return toast(L('error_offline'), 'bad');
                        const close = nearby.find((entry) => entry.citizenid === person.citizenid);
                        target = { ...person, id: close ? close.id : null };
                        drawWho();
                        drawSummary();
                    }),
                ),
        );
    };

    drawWho();
    drawSummary();

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_charges') })),
        el('div', { class: 'two-cols reverse charges-layout' },
            el('div', { class: 'stack small sticky' },
                el('div', { class: 'card form' }, labeled(L('ui_suspect'), who), labeled(L('ui_notes'), notes)),
                el('div', { class: 'card' }, el('strong', { text: L('ui_total') }), summary, buttons),
                el('p', { class: 'muted small', text: L('ui_charge_hint') }),
            ),
            el('div', { class: 'card' }, crimeList(app.penal, counts, drawSummary)),
        ),
    );
}
