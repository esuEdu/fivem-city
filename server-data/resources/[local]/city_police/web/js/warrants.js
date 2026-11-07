import { el, L, run, icon, segmented, formatTime, dateOnly, empty, labeled, confirmButton } from './ui.js';
import { app, can, go } from './main.js';
import { personPicker, crimeList, chargeList } from './picker.js';

let status = 'active';

function chargesText(charges) {
    return charges.map((charge) => (charge.count > 1 ? `${charge.title} x${charge.count}` : charge.title)).join(', ');
}

export async function renderWarrants(args) {
    app.editing = false;
    if (args && args.issue) return issueForm(args.issue);

    const response = await run('warrants', { status });
    const warrants = response ? response.data : [];

    const rows = warrants.map((warrant) => el('div', { class: 'card warrant' },
        el('div', { class: 'card-head' },
            icon('warrants', 20),
            el('button', { class: 'link big', text: warrant.name, onclick: () => go('people', { citizenid: warrant.citizenid }) }),
            el('span', { class: 'spacer' }),
            status === 'active' ? el('span', { class: 'pill gold', text: L('ui_until', dateOnly(warrant.expires)) }) : el('span', { class: 'pill', text: warrant.closed_by || '' }),
        ),
        el('p', { text: warrant.reason }),
        el('small', { class: 'muted', text: chargesText(warrant.charges) }),
        el('div', { class: 'button-row' },
            el('small', { class: 'muted grow', text: `${warrant.issued_by} · ${formatTime(warrant.created)}` }),
            status === 'active' ? el('button', { class: 'kit-btn', onclick: async () => { if (await run('closeWarrant', { id: warrant.id, status: 'served' }, L('ui_done'))) go('warrants'); } }, L('ui_mark_served')) : null,
            status === 'active' && can('issueWarrant') ? confirmButton(L('ui_cancel_warrant'), async () => { if (await run('closeWarrant', { id: warrant.id, status: 'cancelled' }, L('ui_done'))) go('warrants'); }) : null,
        ),
    ));

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_warrants') }),
            segmented([['active', L('warrant_active')], ['served', L('warrant_served')], ['cancelled', L('warrant_cancelled')]], status, (value) => {
                status = value;
                go('warrants');
            }),
            el('span', { class: 'spacer' }),
            can('issueWarrant') ? el('button', { class: 'kit-btn accent', onclick: () => go('warrants', { issue: {} }) }, icon('plus', 16), ' ', L('ui_issue_warrant')) : null),
        rows.length ? el('div', { class: 'stack small' }, rows) : el('div', { class: 'empty' }, icon('warrants', 40), el('p', { text: L('ui_no_warrants') })),
    );
}

function issueForm(person) {
    app.editing = true;

    let target = person && person.citizenid ? person : null;
    const counts = {};
    const who = el('div', { class: 'form-row' });
    const reason = el('input', { class: 'field', type: 'text', maxlength: 160 });
    const days = el('input', { class: 'field', type: 'number', min: 1, max: 30, value: app.warrantDays });

    const drawWho = () => who.replaceChildren(target
        ? el('span', { class: 'chip big' }, target.name, el('button', { class: 'chip-x', type: 'button', onclick: () => { target = null; drawWho(); } }, '×'))
        : personPicker((picked) => { target = picked; drawWho(); }));
    drawWho();

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_issue_warrant') })),
        el('div', { class: 'card form' },
            labeled(L('ui_person'), who),
            el('div', { class: 'form-grid' }, labeled(L('ui_reason'), reason), labeled(L('ui_days_valid'), days)),
        ),
        el('div', { class: 'card' }, el('strong', { text: L('ui_charges') }), crimeList(app.penal, counts, () => {})),
        el('div', { class: 'button-row' },
            el('button', { class: 'kit-btn', onclick: () => go('warrants') }, L('ui_cancel')),
            el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', onclick: async () => {
                if (!target) return;
                const result = await run('issueWarrant', { citizenid: target.citizenid, reason: reason.value, days: Number(days.value), charges: chargeList(counts) }, L('ui_warrant_issued'));
                if (result) go('warrants');
            } }, L('ui_issue_warrant'))),
    );
}
