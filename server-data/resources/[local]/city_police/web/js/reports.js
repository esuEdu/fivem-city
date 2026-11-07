import { el, L, run, icon, pill, searchField, formatTime, empty, select, labeled, toast } from './ui.js';
import { app, go } from './main.js';
import { personPicker } from './picker.js';

const KINDS = ['incident', 'arrest', 'traffic', 'investigation', 'other'];
const ROLES = ['suspect', 'victim', 'witness', 'officer'];

let query = '';
let selected = null;

export async function renderReports(args) {
    app.editing = false;
    if (args && args.id) selected = args.id;

    const response = await run('reports', { q: query });
    const reports = response ? response.data : [];

    const list = el('div', { class: 'list' }, reports.length ? reports.map((report) => el('button', { class: `list-row${report.id === selected ? ' on' : ''}`, onclick: () => go('reports', { id: report.id }) },
        el('span', { class: 'id', text: `#${report.id}` }),
        el('span', { class: 'who' }, el('strong', { text: report.title }), el('small', { text: `${L(`report_${report.kind}`)} · ${report.author} · ${formatTime(report.created)}` })),
    )) : empty(L('ui_no_reports')));

    let detail;
    if (args && args.new) detail = editor({ kind: 'incident', title: '', place: '', body: '', people: args.person ? [{ ...args.person, role: 'suspect' }] : [], plates: [], evidence: [] });
    else if (args && args.edit) detail = editor(args.edit);
    else if (selected) detail = await reportView(selected);
    else detail = el('div', { class: 'empty' }, icon('reports', 40), el('p', { text: L('ui_pick_report') }));

    let timer = null;
    const search = searchField(L('ui_search_reports'), (value) => {
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
                el('button', { class: 'kit-btn accent', onclick: () => go('reports', { new: true }) }, icon('plus', 16), ' ', L('ui_new'))),
            search,
            list,
        ),
        el('div', { class: 'split-detail' }, detail),
    );
}

async function reportView(id) {
    const response = await run('report', { id });
    if (!response) return empty(L('error_not_found'));

    const report = response.data;

    return el('div', { class: 'stack' },
        el('div', { class: 'card' },
            el('div', { class: 'heading' }, el('span', { class: 'id big', text: `#${report.id}` }), el('h2', { text: report.title }), el('span', { class: 'spacer' }),
                pill(L(`report_${report.kind}`), 'blue'),
                report.canEdit ? el('button', { class: 'kit-btn', onclick: () => go('reports', { edit: report }) }, icon('edit', 16), ' ', L('ui_edit')) : null),
            el('small', { class: 'muted', text: [report.place, `${report.author} · ${formatTime(report.created)}`, report.updated !== report.created ? L('ui_edited', formatTime(report.updated)) : null].filter(Boolean).join(' · ') }),
            el('p', { class: 'report-body', text: report.body }),
        ),
        el('div', { class: 'two-cols even' },
            el('div', { class: 'card flush' },
                el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_people_involved') })),
                report.people.length ? report.people.map((person) => el('button', { class: 'info-row link-row', onclick: () => go('people', { citizenid: person.citizenid }) },
                    icon('user', 18), el('strong', { text: person.name }), el('span', { class: 'value', text: L(`role_${person.role}`) }))) : el('p', { class: 'muted padded', text: L('ui_none') }),
            ),
            el('div', { class: 'card flush' },
                el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_vehicles_evidence') })),
                ...report.plates.map((plate) => el('button', { class: 'info-row link-row', onclick: () => go('vehicles', { plate }) }, icon('vehicles', 18), el('strong', { text: plate }))),
                ...(report.evidenceItems || []).map((item) => el('button', { class: 'info-row link-row', onclick: () => go('evidence', { id: item.id }) },
                    icon('evidence', 18), el('strong', { text: `#${item.id} ${L(`evidence_kind_${item.kind}`)}` }), el('span', { class: 'value', text: item.analyzed_at ? L('ui_analyzed') : L('ui_not_analyzed') }))),
                !report.plates.length && !(report.evidenceItems || []).length ? el('p', { class: 'muted padded', text: L('ui_none') }) : null,
            ),
        ),
    );
}

function editor(report) {
    app.editing = true;

    const draft = { ...report, people: [...(report.people || [])], plates: [...(report.plates || [])], evidence: [...(report.evidence || [])] };
    const kind = select(KINDS.map((value) => [value, L(`report_${value}`)]), draft.kind);
    const title = el('input', { class: 'field', type: 'text', maxlength: 100, value: draft.title });
    const place = el('input', { class: 'field', type: 'text', maxlength: 100, value: draft.place || '' });
    const body = el('textarea', { class: 'field area', maxlength: 4000, rows: 10 });
    body.value = draft.body || '';

    const peopleList = el('div', { class: 'stack small' });
    const drawPeople = () => peopleList.replaceChildren(...draft.people.map((person, index) => el('div', { class: 'form-row' },
        el('strong', { class: 'grow', text: person.name }),
        (() => {
            const role = select(ROLES.map((value) => [value, L(`role_${value}`)]), person.role);
            role.addEventListener('change', () => { person.role = role.value; });
            return role;
        })(),
        el('button', { class: 'icon-btn', type: 'button', onclick: () => { draft.people.splice(index, 1); drawPeople(); } }, icon('close', 16)),
    )));
    drawPeople();

    const chips = (list, prefix) => {
        const box = el('div', { class: 'chips' });
        const draw = () => box.replaceChildren(...list.map((value, index) => el('span', { class: 'chip big' }, `${prefix}${value}`,
            el('button', { class: 'chip-x', type: 'button', onclick: () => { list.splice(index, 1); draw(); } }, '×'))));
        draw();
        return { box, draw };
    };

    const plates = chips(draft.plates, '');
    const plateInput = el('input', { class: 'field', type: 'text', maxlength: 8, placeholder: L('ui_plate') });
    const evidence = chips(draft.evidence, '#');
    const evidenceInput = el('input', { class: 'field', type: 'number', min: 1, placeholder: L('ui_evidence_id') });

    const save = async () => {
        const result = await run('saveReport', {
            id: draft.id, kind: kind.value, title: title.value, place: place.value, body: body.value,
            people: draft.people.map((person) => ({ citizenid: person.citizenid, role: person.role })),
            plates: draft.plates, evidence: draft.evidence.map(Number),
        }, L('ui_saved'));

        if (result) {
            app.editing = false;
            selected = result.data;
            go('reports', { id: result.data });
        }
    };

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h2', { text: draft.id ? L('ui_edit_report', draft.id) : L('ui_new_report') })),
        el('div', { class: 'card form' },
            el('div', { class: 'form-grid' }, labeled(L('ui_type'), kind), labeled(L('ui_title_field'), title), labeled(L('ui_location'), place)),
            labeled(L('ui_report_text'), body),
        ),
        el('div', { class: 'card form' },
            el('strong', { text: L('ui_people_involved') }),
            peopleList,
            personPicker((person) => {
                if (draft.people.some((entry) => entry.citizenid === person.citizenid)) return;
                draft.people.push({ ...person, role: 'suspect' });
                drawPeople();
            }),
        ),
        el('div', { class: 'two-cols even' },
            el('div', { class: 'card form' }, el('strong', { text: L('ui_tab_vehicles') }), plates.box,
                el('div', { class: 'form-row' }, plateInput, el('button', { class: 'kit-btn', type: 'button', onclick: () => {
                    const value = plateInput.value.trim().toUpperCase();
                    if (!value || draft.plates.includes(value)) return;
                    draft.plates.push(value);
                    plateInput.value = '';
                    plates.draw();
                } }, L('ui_add')))),
            el('div', { class: 'card form' }, el('strong', { text: L('ui_tab_evidence') }), evidence.box,
                el('div', { class: 'form-row' }, evidenceInput, el('button', { class: 'kit-btn', type: 'button', onclick: () => {
                    const value = Number(evidenceInput.value);
                    if (!Number.isInteger(value) || value < 1 || draft.evidence.includes(value)) return toast(L('error_invalid'), 'bad');
                    draft.evidence.push(value);
                    evidenceInput.value = '';
                    evidence.draw();
                } }, L('ui_add')))),
        ),
        el('div', { class: 'button-row' },
            el('button', { class: 'kit-btn', onclick: () => { app.editing = false; go('reports', draft.id ? { id: draft.id } : undefined); } }, L('ui_cancel')),
            el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', onclick: save }, L('ui_save_report'))),
    );
}
