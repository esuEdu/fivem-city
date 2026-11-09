import { el, L, run, icon, pill, money, ago, empty, toast, confirmButton, segmented, searchField } from './ui.js';
import { app, go } from './main.js';
import { personPicker, personLabel, totals, chargeList } from './picker.js';
import { chargePicker, chargeRows, countsOf } from './penal.js';
import { loadDraft, saveDraft, clearDraft, leaveDraft } from './draft.js';

// The Prison tab: who is serving now, and booking an arrest (person, the case it comes from, charges, reason and a
// reduction). The server checks the suspect is close and restrained, works the sentence out again and sends them in.
export async function renderPrison(args) {
    const response = await run('inmates');
    const inmates = response ? response.data : [];

    const list = el('div', { class: 'list' }, inmates.length ? inmates.map((inmate) => el('button', { class: 'list-row', onclick: () => go('people', { citizenid: inmate.citizenid }) },
        el('span', { class: 'who' }, el('strong', { text: inmate.name }),
            el('small', { text: [inmate.officer, ago(inmate.since)].filter(Boolean).join(' · ') })),
        inmate.status === 'escaped' ? pill(L('ui_escaped'), 'bad') : pill(L('ui_months_left', inmate.months), 'gold'),
    )) : empty(L('ui_no_inmates')));

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_prison') }), el('span', { class: 'spacer' }), pill(String(inmates.filter((inmate) => inmate.status === 'serving').length), 'gold')),
            el('small', { class: 'muted', text: L('ui_inmates_now') }),
            list,
        ),
        el('div', { class: 'split-detail' }, await bookingForm(args)),
    );
}

function blankBooking() {
    return { person: null, caseId: null, caseTitle: '', counts: {}, reason: '', reduction: { kind: 'none', value: 0 } };
}

async function bookingForm(args) {
    app.editing = true;

    let draft = loadDraft('prison') || blankBooking();
    if (args && args.person) {
        draft = { ...blankBooking(), person: args.person, caseId: args.caseId || null };
    }

    // Only a started booking is kept (an empty form isn't worth coming back to)
    const keep = () => {
        if (!draft.person && !Object.keys(draft.counts).length && !draft.reason) return clearDraft('prison');
        saveDraft('prison', { ...draft, open: true });
    };
    app.onLeave = () => leaveDraft('prison');

    const who = el('div', { class: 'stack small' });
    const cases = el('div', { class: 'stack small' });
    const charges = el('div', { class: 'stack small' });
    const summary = el('div', { class: 'summary' });
    const buttons = el('div', { class: 'button-row' });
    const reductionBox = el('div', { class: 'stack small' });

    const reason = el('input', { class: 'field', type: 'text', maxlength: 160, placeholder: L('ui_arrest_reason'), value: draft.reason,
        oninput: () => { draft.reason = reason.value; keep(); } });

    const finalMonths = (months) => {
        const { kind, value } = draft.reduction;
        if (kind === 'percent') return Math.floor(months * (100 - value) / 100);
        if (kind === 'months') return value;
        return months;
    };

    const drawSummary = () => {
        const sum = totals(app.penal, draft.counts, app.maxMonths, app.maxFine);
        const months = finalMonths(sum.months);
        const ready = draft.person && Object.keys(draft.counts).length > 0;

        summary.replaceChildren(
            el('div', { class: 'mini' }, el('strong', { text: L('ui_months', sum.months) }), el('small', { text: L('ui_penal_code_time') })),
            el('div', { class: 'mini' }, el('strong', { class: months < sum.months ? 'good' : '', text: L('ui_months', months) }), el('small', { text: L('ui_final_time') })),
            el('div', { class: 'mini' }, el('strong', { text: money(sum.fine) }), el('small', { text: L('ui_fine') })),
        );

        const jail = async () => {
            if (!draft.reason.trim()) return toast(L('ui_reason_needed'), 'bad');
            if (!draft.person.id) return toast(L('error_offline'), 'bad');

            const reduction = draft.reduction.kind === 'none' ? undefined : { kind: draft.reduction.kind, value: draft.reduction.value };
            const result = await run('charge', {
                citizenid: draft.person.citizenid, target: draft.person.id, kind: 'arrest', charges: chargeList(draft.counts),
                caseId: draft.caseId || undefined, notes: draft.reason, reduction,
            }, L('ui_arrested_done'));

            if (result) {
                clearDraft('prison');
                app.onLeave = null;
                app.editing = false;
                go('prison', { done: true });
            }
        };

        buttons.replaceChildren(
            confirmButton(el('span', {}, L('ui_clear')), () => { clearDraft('prison'); app.onLeave = null; go('prison', { done: true }); }, '', 'kit-btn'),
            el('span', { class: 'spacer' }),
            ready ? confirmButton(el('span', {}, L('ui_arrest_button', months)), jail, 'danger') : null,
        );
    };

    const drawCharges = () => {
        const changed = (next) => { draft.counts = next; keep(); drawCharges(); };

        charges.replaceChildren(
            el('div', { class: 'card-head' }, el('strong', { text: L('ui_charges') }), el('span', { class: 'spacer' }),
                el('button', { class: 'add-btn', type: 'button', onclick: () => chargePicker(draft.counts, changed) }, icon('plus', 14), ' ', L('ui_add'))),
            ...chargeRows(draft.counts, changed),
        );
        drawSummary();
    };

    const drawReduction = () => {
        const kind = draft.reduction.kind;
        const input = el('input', { class: 'field', type: 'number', min: 0, max: kind === 'percent' ? 100 : app.maxMonths, value: String(draft.reduction.value),
            oninput: () => {
                const max = kind === 'percent' ? 100 : app.maxMonths;
                draft.reduction.value = Math.max(0, Math.min(max, Math.floor(Number(input.value) || 0)));
                keep();
                drawSummary();
            } });

        reductionBox.replaceChildren(
            el('strong', { text: L('ui_reduction') }),
            segmented([['none', L('ui_reduction_none')], ['percent', L('ui_reduction_percent')], ['months', L('ui_reduction_months')]], kind, (value) => {
                draft.reduction = { kind: value, value: 0 };
                keep();
                drawReduction();
                drawSummary();
            }),
            kind === 'none' ? el('small', { class: 'muted', text: L('ui_reduction_hint') })
                : el('div', { class: 'form-row' }, input, el('span', { class: 'muted', text: kind === 'percent' ? '%' : L('ui_months_unit') })),
        );
    };

    // Cases where the person is a criminal; picking one fills the charges from it (they can still be changed)
    const drawCases = async (filter = '') => {
        if (!draft.person) return cases.replaceChildren();

        const response = await run('personCases', { citizenid: draft.person.citizenid, q: filter });
        const list = response ? response.data : [];

        cases.replaceChildren(
            el('strong', { text: L('ui_attach_case') }),
            searchField(L('ui_search_cases'), (value) => drawCases(value)),
            list.length ? el('div', { class: 'list compact' }, list.map((entry) => el('button', {
                class: `list-row${draft.caseId === entry.id ? ' on' : ''}`,
                onclick: () => {
                    if (draft.caseId === entry.id) {
                        draft.caseId = null;
                        draft.caseTitle = '';
                    } else {
                        draft.caseId = entry.id;
                        draft.caseTitle = entry.title;
                        draft.counts = countsOf(entry.charges);
                        if (!draft.reason) {
                            draft.reason = entry.title;
                            reason.value = entry.title;
                        }
                    }
                    keep();
                    drawCases(filter);
                    drawCharges();
                },
            }, el('span', { class: 'id', text: `#${entry.id}` }), el('span', { class: 'who' }, el('strong', { text: entry.title }), el('small', { text: ago(entry.created) })),
                draft.caseId === entry.id ? icon('check', 18) : null))) : el('small', { class: 'muted', text: L('ui_no_person_cases') }),
        );
    };

    const drawWho = () => {
        who.replaceChildren(draft.person
            ? el('div', { class: 'form-row' },
                el('span', { class: 'chip big' }, personLabel(draft.person), el('button', { class: 'chip-x', type: 'button', onclick: () => {
                    draft = blankBooking();
                    reason.value = '';
                    keep();
                    drawWho();
                    drawCases();
                    drawCharges();
                } }, '×')),
                draft.person.id ? null : el('small', { class: 'bad', text: L('error_offline') }))
            : personPicker((person) => {
                if (!person.online) return toast(L('error_offline'), 'bad');
                draft.person = person;
                keep();
                drawWho();
                drawCases();
                drawSummary();
            }));
    };

    keep();
    drawWho();
    drawCharges();
    drawReduction();
    drawCases();

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h2', { text: L('ui_book_arrest') })),
        el('div', { class: 'card form' }, el('strong', { text: L('ui_suspect') }), who, cases),
        el('div', { class: 'card form' }, charges),
        el('div', { class: 'card form' }, el('strong', { text: L('ui_arrest_reason') }), reason, reductionBox),
        el('div', { class: 'card' }, summary, buttons),
        el('small', { class: 'muted', text: L('ui_arrest_rules') }),
    );
}
