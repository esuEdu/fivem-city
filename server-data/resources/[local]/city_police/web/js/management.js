import { el, L, run, icon, heading, ago, empty, select, confirmButton, pill, toast } from './ui.js';
import { app, can, go } from './main.js';

function hours(minutes) {
    return `${Math.floor(minutes / 60)}h ${String(minutes % 60).padStart(2, '0')}m`;
}

let hiring = false;

function gradeName(level) {
    const grade = app.grades.find((entry) => entry.level === level);
    return grade ? grade.name : String(level);
}

// The chief types a server id; the player gets the offer on their screen and accepts or declines
function hirePanel() {
    const input = el('input', { class: 'field', type: 'number', min: '1', placeholder: L('ui_hire_placeholder'), 'aria-label': L('ui_hire_placeholder') });

    const send = async () => {
        const target = Number(input.value);
        if (!Number.isInteger(target) || target < 1) return;

        const response = await run('offer', { target });
        if (!response) return;

        toast(L('ui_offer_sent', response.data));
        hiring = false;
        go('management');
    };

    input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') send();
    });

    setTimeout(() => input.focus(), 0);

    return el('div', { class: 'card' },
        el('div', { class: 'card-head' }, icon('plus', 18), el('strong', { text: L('ui_hire') }), el('small', { class: 'muted', text: L('ui_offer_hint', gradeName(0)) })),
        el('div', { class: 'button-row' }, input,
            el('button', { class: 'kit-btn accent', onclick: send }, L('ui_send_offer')),
            el('button', { class: 'kit-btn', onclick: () => { hiring = false; go('management'); } }, L('ui_cancel'))),
    );
}

export async function renderManagement() {
    app.editing = false;

    const [membersResponse, noticesResponse] = await Promise.all([run('members'), run('notices')]);
    const members = membersResponse ? membersResponse.data : [];
    const notices = noticesResponse ? noticesResponse.data : [];

    const lowerGrades = app.grades.filter((grade) => grade.level < app.me.grade);

    const rows = members.map((member) => {
        const self = member.citizenid === app.me.citizenid;
        const editable = can('management') && !self && member.grade < app.me.grade;
        const grade = select(lowerGrades.map((entry) => [entry.level, entry.name]), member.grade);

        grade.disabled = !editable;
        grade.addEventListener('change', async () => {
            if (await run('setGrade', { citizenid: member.citizenid, grade: Number(grade.value) }, L('ui_saved'))) go('management');
        });

        return el('div', { class: 'table-row member-cols' },
            el('span', { class: 'person' },
                el('i', { class: `dot ${member.onDuty ? 'available' : member.online ? 'break' : 'offline'}` }),
                el('span', { class: 'who' }, el('strong', { text: member.name }), el('small', { text: member.callsign || member.citizenid }))),
            editable ? grade : el('span', { class: 'muted', text: gradeName(member.grade) }),
            el('span', { text: hours(member.weekMinutes) }),
            el('span', { class: 'muted', text: hours(member.minutes) }),
            member.onDuty ? pill(L('ui_on_duty_now'), 'green') : member.online ? pill(L('ui_online'), 'blue')
                : el('span', { class: 'muted', text: member.lastDuty ? L('ui_offline_since', ago(member.lastDuty)) : L('ui_not_online') }),
            editable ? confirmButton(L('ui_fire'), async () => { if (await run('fire', { citizenid: member.citizenid }, L('ui_done'))) go('management'); }, 'kit-btn') : el('span', {}),
        );
    });

    const hire = can('management') && hiring ? hirePanel() : null;

    const text = el('textarea', { class: 'field area', maxlength: 500, rows: 3, placeholder: L('ui_notice_placeholder') });
    const noticeCard = el('div', { class: 'card' },
        el('div', { class: 'card-head' }, icon('bell', 18), el('strong', { text: L('ui_notices') })),
        can('notices') ? el('div', { class: 'stack small' }, text, el('div', { class: 'button-row' }, el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', onclick: async () => { if (await run('addNotice', { text: text.value }, L('ui_posted'))) go('management'); } }, L('ui_post')))) : null,
        notices.length ? el('div', { class: 'notices' }, notices.map((notice) => el('div', { class: 'notice' },
            el('p', { text: notice.text }),
            el('div', { class: 'button-row' }, el('small', { class: 'grow', text: `${notice.author} · ${ago(notice.created)}` }),
                can('notices') ? el('button', { class: 'icon-btn', 'aria-label': L('ui_delete'), onclick: async () => { if (await run('deleteNotice', { id: notice.id })) go('management'); } }, icon('trash', 16)) : null)))) : null,
    );

    const onDuty = members.filter((member) => member.onDuty).length;
    const week = members.reduce((sum, member) => sum + member.weekMinutes, 0);

    return el('div', { class: 'stack' },
        heading(L('ui_tab_management'), pill(L('ui_members_count', members.length)), pill(L('ui_on_duty_count', onDuty), 'green'), pill(L('ui_week_hours', hours(week)), 'blue'),
            el('span', { class: 'spacer' }),
            can('management') && !hiring ? el('button', { class: 'kit-btn accent', onclick: () => { hiring = true; go('management'); } }, L('ui_hire')) : null),
        hire,
        el('div', { class: 'card flush table-scroll' },
            el('div', { class: 'table-head member-cols' },
                el('span', { text: L('ui_officer') }), el('span', { text: L('ui_rank') }), el('span', { text: L('ui_this_week') }),
                el('span', { text: L('ui_total') }), el('span', { text: L('ui_status') }), el('span', {})),
            rows.length ? rows : empty(L('ui_no_members')),
        ),
        noticeCard,
    );
}
