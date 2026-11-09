// Hire (boss only): online players who don't work here yet, hired with one click, or by server id. The server checks
// the boss grade and the player again.
import { app, state } from './main.js';

const { el, L, run, icon, heading, pill, avatar, searchField, confirmButton, toast } = window.WorkApp;

let query = '';

function gradeName(level) {
    const grade = state.grades.find((entry) => entry.level === level);
    return grade ? grade.name : String(level);
}

async function hire(target) {
    const response = await run('hire', { target });
    if (!response) return;

    toast(L('ui_hired', response.data));
    app.go('team');
}

function byId() {
    const input = el('input', { class: 'field', type: 'number', min: '1', placeholder: L('ui_hire_placeholder'), 'aria-label': L('ui_hire_placeholder') });

    const submit = () => {
        const target = Number(input.value);
        if (Number.isInteger(target) && target > 0) hire(target);
    };

    input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') submit();
    });

    return el('div', { class: 'card hire' },
        el('div', { class: 'card-head' }, el('span', { class: 'tile-icon tint' }, icon('plus', 18, 2)),
            el('div', { class: 'who' }, el('strong', { text: L('ui_hire_by_id') }), el('small', { text: L('ui_hire_sub', gradeName(0)) }))),
        el('div', { class: 'form-row' }, input, el('button', { class: 'kit-btn tint', onclick: submit }, L('ui_hire'))),
    );
}

function candidates(list) {
    const rows = el('div');

    const draw = () => {
        const shown = query
            ? list.filter((player) => player.name.toLowerCase().includes(query) || String(player.id) === query)
            : list;

        rows.replaceChildren(...(shown.length ? shown.map((player) => el('div', { class: 'table-row hire-cols' },
            el('span', { class: 'server-id', text: String(player.id) }),
            el('div', { class: 'person' }, avatar(player.name, 'on'), el('div', { class: 'who' }, el('strong', { text: player.name }))),
            player.job ? pill(player.job, 'blue') : pill(L('ui_unemployed')),
            confirmButton([icon('plus', 16, 2), L('ui_hire')], () => hire(player.id), 'kit-btn tint'),
        )) : [el('div', { class: 'list-empty', text: query ? L('ui_no_match') : L('ui_nobody_to_hire') })]));
    };

    draw();

    return el('div', { class: 'stack small' },
        searchField(L('ui_search_players'), (value) => {
            query = value;
            draw();
        }, query),
        el('div', { class: 'card flush' },
            el('div', { class: 'table-head hire-cols' }, ['ui_id', 'ui_player', 'ui_current_job', ''].map((key) => el('span', { text: key ? L(key) : '' }))),
            rows),
    );
}

export async function renderHire() {
    const response = await run('candidates');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    return el('div', { class: 'stack' },
        heading(L('ui_tab_hire'), pill(L('ui_online_count', response.data.length), 'blue')),
        el('div', { class: 'banner' }, icon('players', 18, 2), el('span', { text: L('ui_hire_hint', gradeName(0)) })),
        byId(),
        candidates(response.data),
    );
}
