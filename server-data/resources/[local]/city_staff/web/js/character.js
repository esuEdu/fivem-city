// The "Character" card on a player's page: each value shown as it is now, Edit opens a small editor for that one row,
// and nothing changes until the staff member confirms the "old → new" summary.

import { el, L, icon, stepper } from './ui.js';
import { app, can } from './main.js';

const NO_GROUP = { job: 'unemployed', gang: 'none' };

function groupLabel(kind, name, level) {
    const groups = (kind === 'job' ? app.jobs : app.gangs) || [];
    const group = groups.find((entry) => entry.name === name);
    const grade = group && group.grades.find((entry) => entry.level === level);

    return group ? `${group.label}${grade ? ` · ${grade.name}` : ''}` : name;
}

export function characterCard(player, act) {
    const fields = [];

    if (can('setJob') && app.jobs) fields.push({ id: 'job', icon: 'job', label: L('ui_job'), current: { name: player.jobName, level: player.jobLevel } });
    if (can('setGang') && app.gangs) fields.push({ id: 'gang', icon: 'gang', label: L('ui_gang'), current: { name: player.gangName, level: player.gangLevel } });
    if (can('setStats')) {
        fields.push({ id: 'armor', icon: 'armor', label: L('ui_armor'), current: player.armor });
        fields.push({ id: 'hunger', icon: 'hunger', label: L('ui_hunger'), current: player.hunger });
        fields.push({ id: 'thirst', icon: 'thirst', label: L('ui_thirst'), current: player.thirst });
    }
    if (can('bucket')) fields.push({ id: 'bucket', icon: 'bucket', label: L('ui_bucket'), current: player.bucket });

    if (!fields.length) return null;

    const card = el('div', { class: 'card flush character' });
    // editing: { field, draft, review } — one row at a time
    let editing = null;

    const show = (field, value) => {
        if (field.id === 'job' || field.id === 'gang') return groupLabel(field.id, value.name, value.level);
        if (field.id === 'bucket') return String(value);
        return `${value}%`;
    };

    const apply = (field, draft) => {
        if (field.id === 'job' || field.id === 'gang') {
            const action = field.id === 'job' ? 'setJob' : 'setGang';
            return act(action, draft.name === NO_GROUP[field.id] ? { fire: true } : { name: draft.name, grade: draft.level }, L('ui_saved'))();
        }
        if (field.id === 'bucket') return act('bucket', { bucket: draft }, L('ui_saved'))();
        return act('setStat', { stat: field.id, value: draft }, L('ui_saved'))();
    };

    const draw = () => {
        card.replaceChildren(
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_character') })),
            ...fields.map((field) => {
                const open = editing && editing.field === field;

                return el('div', { class: `char-row${open ? ' open' : ''}` },
                    el('div', { class: 'char-line' },
                        el('span', { class: 'char-icon' }, icon(field.icon, 18, 1.9)),
                        el('span', { class: 'char-label', text: field.label }),
                        el('span', { class: 'char-value', text: show(field, field.current) }),
                        open ? null : el('button', { class: 'char-edit', 'aria-label': L('ui_edit_x', field.label), onclick: () => {
                            editing = { field, draft: typeof field.current === 'object' ? { ...field.current } : field.current, review: false };
                            draw();
                        } }, icon('edit', 16, 2), L('ui_edit')),
                    ),
                    open ? (editing.review ? review(field) : editor(field)) : null,
                );
            }),
        );
    };

    const cancel = () => {
        editing = null;
        draw();
    };

    const review = (field) => el('div', { class: 'char-editor' },
        el('div', { class: 'change-summary' },
            el('span', { class: 'from', text: show(field, field.current) }),
            el('span', { class: 'arrow', text: '→' }),
            el('strong', { class: 'to', text: show(field, editing.draft) })),
        el('div', { class: 'editor-buttons' },
            el('button', { class: 'kit-btn', text: L('ui_back'), onclick: () => {
                editing.review = false;
                draw();
            } }),
            el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', text: L('ui_confirm'), onclick: () => apply(field, editing.draft) })),
    );

    const footer = (field, changed) => el('div', { class: 'editor-buttons' },
        el('button', { class: 'kit-btn', text: L('ui_cancel'), onclick: cancel }),
        el('span', { class: 'spacer' }),
        el('button', { class: 'kit-btn accent', text: L('ui_review'), disabled: !changed, onclick: () => {
            editing.review = true;
            draw();
        } }));

    const editor = (field) => {
        if (field.id === 'job' || field.id === 'gang') return groupEditor(field);
        if (field.id === 'bucket') return bucketEditor(field);
        return statEditor(field);
    };

    const groupEditor = (field) => {
        const groups = (field.id === 'job' ? app.jobs : app.gangs) || [];
        const draft = editing.draft;
        const list = el('div', { class: 'picker-list' });
        const search = el('input', { class: 'field', type: 'text', value: editing.search || '', placeholder: L(`ui_search_${field.id}s`), 'aria-label': L(`ui_search_${field.id}s`) });

        const drawList = () => {
            const filter = search.value.trim().toLowerCase();
            const shown = groups.filter((group) => !filter || group.label.toLowerCase().includes(filter) || group.name.includes(filter));

            list.replaceChildren(...(shown.length ? shown.map((group) => el('button', { class: `picker-item${group.name === draft.name ? ' on' : ''}`, onclick: () => {
                editing.draft = { name: group.name, level: group.grades.length ? group.grades[0].level : 0 };
                draw();
            } }, el('span', { text: group.label }), group.name === field.current.name ? el('small', { text: L('ui_current') }) : null))
                : [el('div', { class: 'list-empty', text: L('ui_nothing_found') })]));
        };

        search.addEventListener('input', () => {
            editing.search = search.value;
            drawList();
        });
        drawList();

        const selected = groups.find((group) => group.name === draft.name);
        const changed = draft.name !== field.current.name || draft.level !== field.current.level;
        const isNone = field.current.name === NO_GROUP[field.id];

        return el('div', { class: 'char-editor' },
            el('div', { class: 'picker' }, search, list),
            selected && selected.grades.length > 1 ? el('div', { class: 'grades' },
                el('small', { class: 'muted', text: L('ui_grade') }),
                el('div', { class: 'chips' }, selected.grades.map((grade) => el('button', { class: `grade${grade.level === draft.level ? ' on' : ''}`, onclick: () => {
                    editing.draft = { name: draft.name, level: grade.level };
                    draw();
                } }, `${grade.level} · ${grade.name}`)))) : null,
            isNone ? null : el('button', { class: 'fire', onclick: () => {
                editing.draft = { name: NO_GROUP[field.id], level: 0 };
                editing.review = true;
                draw();
            } }, icon('fire', 16, 2), L(`ui_fire_${field.id}`)),
            footer(field, changed),
        );
    };

    const statEditor = (field) => {
        const value = el('strong', { class: 'stat-number', text: `${editing.draft}%` });
        const range = el('input', { type: 'range', min: '0', max: '100', step: '1', value: String(editing.draft), 'aria-label': field.label });
        const save = footer(field, editing.draft !== field.current);

        const set = (n) => {
            editing.draft = n;
            value.textContent = `${n}%`;
            range.value = String(n);
            save.querySelector('.accent').disabled = n === field.current;
        };
        range.addEventListener('input', () => set(Number(range.value)));

        return el('div', { class: 'char-editor' },
            el('div', { class: 'stat-edit' }, range, value),
            el('div', { class: 'chips' }, [0, 25, 50, 75, 100].map((n) => el('button', { class: 'grade', onclick: () => set(n) }, `${n}%`))),
            save,
        );
    };

    const bucketEditor = (field) => {
        const input = el('input', { class: 'field', type: 'number', min: '0', max: String(app.maxBucket), value: String(editing.draft), 'aria-label': field.label });
        const save = footer(field, false);

        input.addEventListener('input', () => {
            const n = Number(input.value);
            const valid = Number.isInteger(n) && n >= 0 && n <= app.maxBucket;
            if (valid) editing.draft = n;
            save.querySelector('.accent').disabled = !valid || n === field.current;
        });

        return el('div', { class: 'char-editor' },
            el('div', { class: 'stat-edit' }, stepper(input), el('small', { class: 'muted', text: L('ui_bucket_help') })),
            save,
        );
    };

    draw();

    return card;
}
