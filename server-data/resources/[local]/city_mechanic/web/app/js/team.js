// Team: everyone with the job. The boss hires by server id, moves grades up and down and fires (the server checks it all).
import { app, state } from './main.js';

const { el, L, run, icon, heading, pill, avatar, confirmButton } = window.WorkApp;

let filter = 'all';

function status(member) {
    if (member.onDuty) return pill(L('ui_on_duty'), 'green');
    if (member.online) return pill(L('ui_online'), 'blue');
    return pill(L('ui_offline'));
}

function gradeName(level) {
    const grade = state.grades.find((entry) => entry.level === level);
    return grade ? grade.name : String(level);
}

// The boss may change members below their own grade, to any grade below their own
function canManage(member) {
    return state.boss && !member.me && member.grade < state.gradeLevel;
}

function memberActions(member) {
    if (!canManage(member)) return el('span');

    const setGrade = async (grade) => {
        if (await run('setGrade', { citizenid: member.citizenid, grade }, L('ui_grade_set', member.name, gradeName(grade)))) app.go('team');
    };

    const up = member.grade + 1 < state.gradeLevel;
    const down = member.grade > 0;

    return el('div', { class: 'row-actions' },
        el('button', { class: 'icon-btn', title: L('ui_promote'), disabled: !up, onclick: () => setGrade(member.grade + 1) }, icon('up', 16, 2)),
        el('button', { class: 'icon-btn', title: L('ui_demote'), disabled: !down, onclick: () => setGrade(member.grade - 1) }, icon('down', 16, 2)),
        confirmButton(icon('kick', 16, 2), async () => {
            if (await run('fire', { citizenid: member.citizenid }, L('ui_fired', member.name))) app.go('team');
        }, 'icon-btn danger'),
    );
}

function hireCard() {
    const input = el('input', { class: 'field', type: 'number', min: '1', placeholder: L('ui_hire_placeholder'), 'aria-label': L('ui_hire_placeholder') });

    const hire = async () => {
        const target = Number(input.value);
        if (!Number.isInteger(target) || target < 1) return;

        const response = await run('hire', { target });
        if (response) {
            window.WorkApp.toast(L('ui_hired', response.data));
            app.go('team');
        }
    };

    input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') hire();
    });

    return el('div', { class: 'card hire' },
        el('div', { class: 'card-head' }, el('span', { class: 'tile-icon tint' }, icon('plus', 18, 2)),
            el('div', { class: 'who' }, el('strong', { text: L('ui_hire_title') }), el('small', { text: L('ui_hire_sub', gradeName(0)) }))),
        el('div', { class: 'form-row' }, input, el('button', { class: 'kit-btn tint', onclick: hire }, L('ui_hire'))),
    );
}

export async function renderTeam() {
    const response = await run('team');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const members = response.data;
    const onDuty = members.filter((member) => member.onDuty).length;
    const shown = filter === 'duty' ? members.filter((member) => member.onDuty) : members;

    return el('div', { class: 'stack' },
        heading(L('ui_tab_team'), pill(L('ui_members', members.length)), pill(L('ui_on_duty_count', onDuty), 'green'), el('span', { class: 'spacer' }),
            window.WorkApp.segmented([['all', L('ui_all')], ['duty', L('ui_on_duty')]], filter, (value) => {
                filter = value;
                app.go('team');
            })),
        state.boss ? hireCard() : null,
        el('div', { class: 'card flush' },
            el('div', { class: 'table-head team-cols' }, ['ui_member', 'ui_grade', 'ui_status', 'ui_week_services', ''].map((key) => el('span', { text: key ? L(key) : '' }))),
            shown.length ? shown.map((member) => el('div', { class: `table-row team-cols${member.me ? ' me' : ''}` },
                el('div', { class: 'person' },
                    avatar(member.name, member.onDuty ? 'on' : member.online ? 'away' : ''),
                    el('div', { class: 'who' }, el('strong', { text: member.name }), member.me ? el('small', { text: L('ui_you') }) : null)),
                el('span', { class: 'grade' }, member.boss ? icon('star', 14, 2) : null, member.gradeName),
                status(member),
                el('strong', { text: String(member.week) }),
                memberActions(member),
            )) : el('div', { class: 'table-row muted', text: L('ui_nobody_on_duty') })),
    );
}
