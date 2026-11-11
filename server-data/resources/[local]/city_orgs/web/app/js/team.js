// Management: every member (online or not) with their week's farm net, for the whole faction. The leader sends
// invites by server id (the player accepts on screen), changes grades below their own and removes members; the
// server checks it all again.
import { app, state } from './main.js';

const { el, L, run, icon, heading, pill, avatar, confirmButton, segmented, toast } = window.WorkApp;

let filter = 'all';
let hiring = false;

function status(member) {
    if (member.online) return pill(L('ui_online'), 'green');
    return pill(L('ui_offline'));
}

function gradeName(level) {
    const grade = state.grades.find((entry) => entry.level === level);
    return grade ? grade.name : String(level);
}

// The leader may change members below their own grade, to any grade below their own
function canManage(member) {
    return state.boss && !member.me && member.grade < state.gradeLevel;
}

function gradeCell(member) {
    const name = el('span', { class: 'grade' }, member.boss ? icon('star', 14, 2) : null, member.gradeName);
    if (!canManage(member)) return name;

    const select = el('select', { class: 'field grade-select', 'aria-label': L('ui_grade') },
        state.grades.filter((grade) => grade.level < state.gradeLevel).map((grade) =>
            el('option', { value: String(grade.level), text: grade.name, selected: grade.level === member.grade })));

    select.addEventListener('change', async () => {
        const grade = Number(select.value);
        if (await run('setGrade', { citizenid: member.citizenid, grade }, L('ui_grade_set', member.name, gradeName(grade)))) app.go('team');
        else select.value = String(member.grade);
    });

    return select;
}

function fireButton(member) {
    if (!canManage(member)) return el('span');

    return el('div', { class: 'row-actions' }, confirmButton([icon('kick', 16, 2), L('ui_fire')], async () => {
        if (await run('fire', { citizenid: member.citizenid }, L('ui_fired', member.name))) app.go('team');
    }, 'kit-btn soft-danger small'));
}

function hirePanel() {
    const input = el('input', { class: 'field', type: 'number', min: '1', placeholder: L('ui_hire_placeholder'), 'aria-label': L('ui_hire_placeholder') });

    const send = async () => {
        const target = Number(input.value);
        if (!Number.isInteger(target) || target < 1) return;

        const response = await run('offer', { target });
        if (!response) return;

        toast(L('ui_offer_sent', response.data));
        hiring = false;
        app.go('team');
    };

    input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') send();
    });

    setTimeout(() => input.focus(), 0);

    return el('div', { class: 'card hire' },
        el('div', { class: 'card-head' }, el('span', { class: 'tile-icon tint' }, icon('plus', 18, 2)),
            el('div', { class: 'who' }, el('strong', { text: L('ui_hire') }), el('small', { text: L('ui_offer_hint', gradeName(0)) }))),
        el('div', { class: 'form-row' }, input,
            el('button', { class: 'kit-btn tint', onclick: send }, L('ui_send_offer')),
            el('button', { class: 'kit-btn', onclick: () => { hiring = false; app.go('team'); } }, L('ui_cancel'))),
    );
}

export async function renderTeam() {
    const response = await run('team');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const members = response.data;
    const online = members.filter((member) => member.online).length;
    const shown = filter === 'online' ? members.filter((member) => member.online) : members;

    return el('div', { class: 'stack' },
        heading(L('ui_tab_management'), pill(L('ui_members', members.length)), pill(L('ui_online_count', online), 'green'),
            el('span', { class: 'spacer' }),
            segmented([['all', L('ui_all')], ['online', L('ui_online')]], filter, (value) => {
                filter = value;
                app.go('team');
            }),
            state.boss && !hiring ? el('button', { class: 'kit-btn tint', onclick: () => { hiring = true; app.go('team'); } }, icon('plus', 16, 2), L('ui_hire')) : null),
        state.boss && hiring ? hirePanel() : null,
        el('div', { class: 'card flush' },
            el('div', { class: 'table-head team-cols' }, ['ui_member', 'ui_grade', 'ui_status', 'ui_week_farm', ''].map((key) => el('span', { text: key ? L(key) : '' }))),
            shown.length ? shown.map((member) => el('div', { class: `table-row team-cols${member.me ? ' me' : ''}` },
                el('div', { class: 'person' },
                    avatar(member.name, member.online ? 'on' : ''),
                    el('div', { class: 'who' }, el('strong', { text: member.name }), member.me ? el('small', { text: L('ui_you') }) : null)),
                gradeCell(member),
                status(member),
                el('strong', { text: String(member.week) }),
                fireButton(member),
            )) : el('div', { class: 'table-row muted', text: L('ui_nobody') })),
    );
}
