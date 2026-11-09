import { el, L, run, icon, pill, searchField, formatTime, empty, money, confirmButton } from './ui.js';
import { app, can, go } from './main.js';
import { casePhoto } from './photos.js';
import { countsOf, chargeRows } from './penal.js';
import { totals, chargeList } from './picker.js';
import { caseEditor, newCase } from './case-editor.js';
import { loadDraft } from './draft.js';

let query = '';
let selected = null;

export function tagPill(id) {
    const tag = app.caseTags.find((entry) => entry.id === id);
    return tag ? pill(tag.label, tag.color) : null;
}

// A case already being written gets the person as a criminal instead of being thrown away for a new one
function withPerson(draft, person) {
    if (!draft || !person) return null;

    if (!draft.people.some((entry) => entry.citizenid === person.citizenid)) {
        draft.people.push({ citizenid: person.citizenid, name: person.name, role: 'criminal', charges: [] });
    }

    return draft;
}

export async function renderCases(args) {
    app.editing = false;
    if (args && args.id) selected = args.id;

    let detail;
    if (args && (args.new || args.edit || args.draft)) {
        detail = caseEditor((args.draft && loadDraft('case')) || args.edit || withPerson(loadDraft('case'), args.person) || newCase(args.person));
    } else if (selected) {
        detail = await caseView(selected);
    } else {
        detail = el('div', { class: 'empty' }, icon('cases', 40), el('p', { text: L('ui_pick_case') }));
    }

    const response = await run('reports', { q: query });
    const cases = response ? response.data : [];
    const draft = loadDraft('case');

    const list = el('div', { class: 'list' },
        draft ? el('button', { class: 'list-row draft', onclick: () => go('reports', { draft: true }) },
            el('span', { class: 'id', text: L('ui_draft') }),
            el('span', { class: 'who' }, el('strong', { text: draft.title || L('ui_untitled') }), el('small', { text: L('ui_continue_draft') }))) : null,
        cases.length ? cases.map((entry) => el('button', { class: `list-row${entry.id === selected ? ' on' : ''}`, onclick: () => go('reports', { id: entry.id }) },
            el('span', { class: 'id', text: `#${entry.id}` }),
            el('span', { class: 'who' }, el('strong', { text: entry.title }), el('small', { text: `${entry.author} · ${formatTime(entry.created)}` })),
        )) : empty(L('ui_no_cases')),
    );

    let timer = null;
    const search = searchField(L('ui_search_cases'), (value) => {
        clearTimeout(timer);
        timer = setTimeout(() => {
            query = value;
            go('reports');
        }, 400);
    });
    search.querySelector('input').value = query;

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_reports') }), el('span', { class: 'spacer' }),
                el('button', { class: 'kit-btn accent', onclick: () => go('reports', draft ? { draft: true } : { new: true }) }, icon('plus', 16), ' ', L('ui_new'))),
            search,
            list,
        ),
        el('div', { class: 'split-detail' }, detail),
    );
}

function box(title, ...children) {
    return el('div', { class: 'card case-box' }, el('div', { class: 'card-head' }, el('strong', { text: title })), ...children);
}

function nameChips(people, role, kind) {
    const list = people.filter((person) => person.role === role);
    if (!list.length) return el('p', { class: 'muted', text: L('ui_none') });

    return el('div', { class: 'chips' }, list.map((person) => el('button', { class: `tag-chip ${kind}`, onclick: () => go('people', { citizenid: person.citizenid }), text: person.name })));
}

// One criminal of the case: their charges, totals, and the fine / jail buttons
function criminalCard(entry, person) {
    const counts = countsOf(person.charges);
    const sum = totals(app.penal, counts, app.maxMonths, app.maxFine);
    const hasCharges = Object.keys(counts).length > 0;

    const fine = async () => {
        await run('charge', { citizenid: person.citizenid, target: person.id, kind: 'fine', charges: chargeList(counts), caseId: entry.id, notes: entry.title }, L('ui_fined_done'));
    };

    return el('div', { class: 'card case-box' },
        el('div', { class: 'card-head' },
            el('strong', { text: person.name }), el('span', { class: 'spacer' }),
            can('charge') && hasCharges && person.id ? confirmButton(el('span', {}, L('ui_fine_button', money(sum.fine))), fine, 'accent') : null,
            can('charge') ? el('button', { class: 'kit-btn danger', onclick: () => go('prison', { person: { citizenid: person.citizenid, name: person.name, id: person.id }, caseId: entry.id }) }, L('ui_jail')) : null),
        ...chargeRows(counts, null),
        hasCharges ? el('small', { class: 'muted', text: L('ui_case_totals', sum.months, money(sum.fine)) }) : null,
    );
}

async function caseView(id) {
    const response = await run('report', { id });
    if (!response) return empty(L('error_not_found'));

    const entry = response.data;
    const criminals = entry.people.filter((person) => person.role === 'criminal');

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('span', { class: 'id big', text: `#${entry.id}` }), el('h2', { text: entry.title }), el('span', { class: 'spacer' }),
            entry.canEdit ? el('button', { class: 'kit-btn', onclick: () => go('reports', { edit: entry }) }, icon('edit', 16), ' ', L('ui_edit')) : null),
        el('small', { class: 'muted', text: [entry.place, `${entry.author} · ${formatTime(entry.created)}`, entry.updated !== entry.created ? L('ui_edited', formatTime(entry.updated)) : null].filter(Boolean).join(' · ') }),
        el('div', { class: 'case-grid' },
            el('div', { class: 'stack small' },
                box(L('ui_evidence'), entry.photos.length ? el('div', { class: 'thumbs' }, entry.photos.map((photoId, index) => casePhoto(photoId, index + 1))) : el('p', { class: 'muted', text: L('ui_none') }),
                    ...(entry.evidenceItems || []).map((item) => el('button', { class: 'info-row link-row', onclick: () => go('evidence', { id: item.id }) },
                        icon('evidence', 18), el('strong', { text: `#${item.id} ${L(`evidence_kind_${item.kind}`)}` })))),
                box(L('ui_tags'), entry.tags.length ? el('div', { class: 'chips' }, entry.tags.map(tagPill)) : el('p', { class: 'muted', text: L('ui_none') })),
                box(L('ui_description'), el('p', { class: 'report-body', text: entry.body })),
            ),
            el('div', { class: 'stack small' },
                box(L('ui_vehicles_involved'), entry.plates.length ? el('div', { class: 'chips' }, entry.plates.map((plate) => el('button', { class: 'tag-chip blue', onclick: () => go('vehicles', { plate }), text: plate }))) : el('p', { class: 'muted', text: L('ui_none') })),
                box(L('ui_officers_involved'), nameChips(entry.people, 'officer', 'blue')),
                box(L('ui_civilians_involved'), nameChips(entry.people, 'civilian', 'green')),
                box(L('ui_criminals_involved'), nameChips(entry.people, 'criminal', 'red')),
            ),
        ),
        ...criminals.map((person) => criminalCard(entry, person)),
    );
}
