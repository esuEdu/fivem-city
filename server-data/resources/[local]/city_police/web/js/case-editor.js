import { el, L, run, icon, toast, money, confirmButton } from './ui.js';
import { app, go } from './main.js';
import { personPicker, totals } from './picker.js';
import { casePhoto, pickPhonePhoto } from './photos.js';
import { chargePicker, chargeRows, countsOf } from './penal.js';
import { saveDraft, clearDraft, leaveDraft } from './draft.js';

const MAX_PHOTOS = 6;
const MAX_TAGS = 8;

// A new case: this officer is on it, the description starts from the template (date and who filed it)
export function newCase(person) {
    const me = app.me;
    const people = [{ citizenid: me.citizenid, name: me.name, role: 'officer' }];
    if (person && person.citizenid !== me.citizenid) people.push({ citizenid: person.citizenid, name: person.name, role: 'criminal', charges: [] });

    const filedBy = me.callsign ? `${me.name} ${me.callsign}` : me.name;
    const date = new Date().toLocaleDateString('en-US', { day: 'numeric', month: 'long', year: 'numeric' });

    return { title: '', place: '', body: L('ui_case_template', date, filedBy), tags: [], people, plates: [], photos: [], evidence: [] };
}

// The form of a case being written or edited; every change is kept as a draft until it is saved or cancelled
export function caseEditor(start) {
    app.editing = true;

    const draft = {
        id: start.id, title: start.title || '', place: start.place || '', body: start.body || '',
        tags: [...(start.tags || [])], plates: [...(start.plates || [])], photos: [...(start.photos || [])], evidence: [...(start.evidence || [])],
        people: (start.people || []).map((person) => ({ citizenid: person.citizenid, name: person.name, role: person.role, charges: person.role === 'criminal' ? [...(person.charges || [])] : undefined })),
    };

    const keep = () => saveDraft('case', { ...draft, open: true });
    app.onLeave = () => leaveDraft('case');
    keep();

    const title = el('input', { class: 'field', type: 'text', maxlength: 100, placeholder: L('ui_case_title'), value: draft.title, oninput: () => { draft.title = title.value; keep(); } });
    const place = el('input', { class: 'field', type: 'text', maxlength: 100, placeholder: L('ui_location'), value: draft.place, oninput: () => { draft.place = place.value; keep(); } });
    const body = el('textarea', { class: 'field area', maxlength: 4000, rows: 12, oninput: () => { draft.body = body.value; keep(); } });
    body.value = draft.body;

    // Evidence: photos from the officer's phone
    const photos = el('div', { class: 'thumbs' });
    const drawPhotos = () => photos.replaceChildren(...(draft.photos.length
        ? draft.photos.map((id, index) => casePhoto(id, index + 1, () => { draft.photos.splice(index, 1); keep(); drawPhotos(); }))
        : [el('p', { class: 'muted', text: L('ui_no_photos') })]));
    drawPhotos();

    const addPhoto = () => {
        if (draft.photos.length >= MAX_PHOTOS) return toast(L('ui_max_photos', MAX_PHOTOS), 'bad');
        pickPhonePhoto((id) => { draft.photos.push(id); keep(); drawPhotos(); });
    };

    // Tags: adding one puts its template at the end of the description
    const tags = el('div', { class: 'chips' });
    const tagMenu = el('div', { class: 'chips hidden' });
    const drawTags = () => {
        tags.replaceChildren(...(draft.tags.length ? draft.tags.map((id, index) => {
            const tag = app.caseTags.find((entry) => entry.id === id);
            return tag ? el('span', { class: `tag-chip ${tag.color}` }, tag.label,
                el('button', { class: 'chip-x', type: 'button', onclick: () => { draft.tags.splice(index, 1); keep(); drawTags(); } }, '×')) : null;
        }) : [el('p', { class: 'muted', text: L('ui_none') })]));

        tagMenu.replaceChildren(...app.caseTags.filter((tag) => !draft.tags.includes(tag.id)).map((tag) => el('button', {
            class: `tag-chip pick ${tag.color}`, type: 'button', text: tag.label,
            onclick: () => {
                if (draft.tags.length >= MAX_TAGS) return;
                draft.tags.push(tag.id);
                if (tag.template && !draft.body.includes(tag.template.split('\n')[0])) {
                    draft.body = `${draft.body.replace(/\s+$/, '')}\n\n${tag.template}`;
                    body.value = draft.body;
                }
                tagMenu.classList.add('hidden');
                keep();
                drawTags();
            },
        })));
    };
    drawTags();

    // Vehicles by plate
    const plates = el('div', { class: 'chips' });
    const plateInput = el('input', { class: 'field', type: 'text', maxlength: 8, placeholder: L('ui_plate') });
    const plateRow = el('div', { class: 'form-row hidden' }, plateInput, el('button', { class: 'kit-btn', type: 'button', onclick: () => addPlate() }, L('ui_add')));
    const drawPlates = () => plates.replaceChildren(...(draft.plates.length ? draft.plates.map((plate, index) => el('span', { class: 'tag-chip blue' }, plate,
        el('button', { class: 'chip-x', type: 'button', onclick: () => { draft.plates.splice(index, 1); keep(); drawPlates(); } }, '×'))) : [el('p', { class: 'muted', text: L('ui_none') })]));
    const addPlate = () => {
        const value = plateInput.value.trim().toUpperCase();
        if (!/^[A-Z0-9 ]{1,8}$/.test(value)) return toast(L('error_invalid'), 'bad');
        if (!draft.plates.includes(value)) draft.plates.push(value);
        plateInput.value = '';
        keep();
        drawPlates();
    };
    plateInput.addEventListener('keydown', (event) => { if (event.key === 'Enter') addPlate(); });
    drawPlates();

    // People: officers, civilians and criminals, each a box with its own picker
    const criminals = el('div', { class: 'stack small' });
    const peopleBoxes = {};

    const drawPeople = (role) => {
        const target = peopleBoxes[role];
        const list = draft.people.filter((person) => person.role === role);
        const kind = { officer: 'blue', civilian: 'green', criminal: 'red' }[role];

        target.replaceChildren(...(list.length ? list.map((person) => el('span', { class: `tag-chip ${kind}` }, person.name,
            el('button', { class: 'chip-x', type: 'button', onclick: () => {
                draft.people.splice(draft.people.indexOf(person), 1);
                keep();
                drawPeople(role);
                if (role === 'criminal') drawCriminals();
            } }, '×'))) : [el('p', { class: 'muted', text: L('ui_none') })]));
    };

    const drawCriminals = () => criminals.replaceChildren(...draft.people.filter((person) => person.role === 'criminal').map((person) => {
        const counts = countsOf(person.charges);
        const sum = totals(app.penal, counts, app.maxMonths, app.maxFine);
        const changed = (next) => {
            person.charges = Object.entries(next).map(([id, count]) => ({ id, count }));
            keep();
            drawCriminals();
        };

        return el('div', { class: 'card case-box' },
            el('div', { class: 'card-head' }, el('strong', { text: person.name }), el('span', { class: 'spacer' }),
                el('button', { class: 'kit-btn accent small', type: 'button', onclick: () => chargePicker(counts, changed) }, icon('plus', 14), ' ', L('ui_add_charge'))),
            ...chargeRows(counts, changed),
            Object.keys(counts).length ? el('small', { class: 'muted', text: L('ui_case_totals', sum.months, money(sum.fine)) }) : null,
        );
    }));

    const peopleBox = (role, titleKey) => {
        peopleBoxes[role] = el('div', { class: 'chips' });
        drawPeople(role);

        const picker = personPicker((person) => {
            if (draft.people.some((entry) => entry.citizenid === person.citizenid)) return toast(L('ui_already_on_case'), 'bad');
            draft.people.push({ citizenid: person.citizenid, name: person.name, role, charges: role === 'criminal' ? [] : undefined });
            picker.classList.add('hidden');
            keep();
            drawPeople(role);
            if (role === 'criminal') drawCriminals();
        });
        picker.classList.add('hidden');

        return section(L(titleKey), () => picker.classList.toggle('hidden'), peopleBoxes[role], picker);
    };

    drawCriminals();

    const save = async () => {
        if (!draft.title.trim()) return toast(L('ui_case_needs_title'), 'bad');

        const result = await run('saveReport', {
            id: draft.id, title: draft.title, place: draft.place, body: draft.body, tags: draft.tags, plates: draft.plates,
            photos: draft.photos, evidence: draft.evidence,
            people: draft.people.map((person) => ({ citizenid: person.citizenid, role: person.role, charges: person.charges })),
        }, L('ui_saved'));

        if (result) {
            clearDraft('case');
            app.onLeave = null;
            app.editing = false;
            go('reports', { id: result.data });
        }
    };

    const cancel = () => {
        clearDraft('case');
        app.onLeave = null;
        app.editing = false;
        go('reports', draft.id ? { id: draft.id } : undefined);
    };

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' },
            el('h2', { text: draft.id ? L('ui_edit_case', draft.id) : L('ui_new_case') }), el('span', { class: 'spacer' }),
            confirmButton(el('span', {}, L('ui_cancel')), cancel, 'danger'),
            el('button', { class: 'kit-btn accent', onclick: save }, L('ui_save'))),
        el('div', { class: 'form-grid two' }, title, place),
        el('div', { class: 'case-grid' },
            el('div', { class: 'stack small' },
                section(L('ui_evidence'), addPhoto, photos),
                section(L('ui_tags'), () => tagMenu.classList.toggle('hidden'), tags, tagMenu),
                section(L('ui_description'), null, body),
            ),
            el('div', { class: 'stack small' },
                section(L('ui_vehicles_involved'), () => { plateRow.classList.toggle('hidden'); plateInput.focus(); }, plates, plateRow),
                peopleBox('officer', 'ui_officers_involved'),
                peopleBox('civilian', 'ui_civilians_involved'),
                peopleBox('criminal', 'ui_criminals_involved'),
            ),
        ),
        criminals,
    );
}

// A box with a title and a blue "+ Add" on the right
function section(title, onAdd, ...children) {
    return el('div', { class: 'card case-box' },
        el('div', { class: 'card-head' }, el('strong', { text: title }), el('span', { class: 'spacer' }),
            onAdd ? el('button', { class: 'add-btn', type: 'button', onclick: onAdd }, icon('plus', 14), ' ', L('ui_add')) : null),
        ...children);
}
