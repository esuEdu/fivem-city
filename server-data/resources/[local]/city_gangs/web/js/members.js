// The Members tab: everyone in the gang with what they brought in over the period. A member's page shows their
// performance (money, sales, production, where they stand in the gang, day by day, per drug, their latest activity) and,
// for members above them, promote / demote / kick out. Everyone can leave from their own page.

import { el, L, run, icon, pill, initials, money, ago, confirmButton, heading, list, chart, drugLabel, tile, periodPicker } from './ui.js';
import { app, can, go, closed, setOnline } from './main.js';
import { line, LOOK } from './log.js';

let selected = null;

export async function renderMembers(args) {
    if (args && args.citizenid) selected = args.citizenid;

    const response = await run('members', { days: app.period });
    const members = response ? list(response.data.members) : [];
    if (!members.some((member) => member.citizenid === selected)) selected = members.length ? members[0].citizenid : null;

    setOnline(members.filter((member) => member.online).length, members.length);

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            heading(L('ui_tab_members'), pill(L('ui_member_count', members.length))),
            periodPicker(app.periods, app.period, (days) => {
                app.period = days;
                go('members');
            }),
            el('div', { class: 'list' }, members.length ? members.map((entry) => el('button', { class: `list-row${entry.citizenid === selected ? ' on' : ''}`, onclick: () => go('members', { citizenid: entry.citizenid }) },
                el('span', { class: 'avatar' }, initials(entry.name), el('i', { class: `presence${entry.online ? ' on' : ''}` })),
                el('span', { class: 'who grow' }, el('strong', { text: entry.isMe ? `${entry.name} (${L('ui_you')})` : entry.name }), el('small', { text: entry.gradeName })),
                el('span', { class: 'row-nums' }, el('strong', { class: entry.earned ? 'good' : 'muted', text: money(entry.earned) }), el('small', { text: L('ui_sales_n', entry.sales) })),
            )) : el('div', { class: 'list-empty', text: L('ui_no_members') })),
        ),
        el('div', { class: 'split-detail' }, selected ? await memberPage(selected) : el('div', { class: 'empty', text: L('ui_no_members') })),
    );
}

function controls(member) {
    const grades = app.grades;
    const index = grades.findIndex((grade) => grade.level === member.grade);
    const up = grades[index + 1];
    const down = grades[index - 1];
    // only to ranks below your own (checked again on the server)
    const canUp = can('setGrade') && member.canManage && up && up.level < app.grade;
    const canDown = can('setGrade') && member.canManage && down;
    const canFire = can('fire') && member.canManage;

    const setGrade = async (grade) => {
        if (await run('setGrade', { citizenid: member.citizenid, grade: grade.level }, L('ui_saved'))) go('members', { citizenid: member.citizenid });
    };

    const fire = async () => {
        if (await run('fire', { citizenid: member.citizenid }, L('ui_fired'))) go('members');
    };

    const leave = async () => {
        if (await run('leave', {}, L('ui_left'))) closed(L('ui_left'));
    };

    return [
        canUp || canDown || canFire ? el('div', { class: 'card' },
            el('strong', { class: 'card-title', text: L('ui_control') }),
            el('div', { class: 'rank-row' },
                canDown ? el('button', { class: 'kit-btn', onclick: () => setGrade(down) }, icon('down', 16, 2), ` ${L('ui_demote')} · ${down.name}`) : null,
                canUp ? el('button', { class: 'kit-btn accent', onclick: () => setGrade(up) }, icon('up', 16, 2), ` ${L('ui_promote')} · ${up.name}`) : null,
                el('span', { class: 'spacer' }),
                canFire ? confirmButton([icon('kick', 16, 2), ` ${L('ui_fire')}`], fire) : null),
        ) : null,
        member.isMe ? el('div', { class: 'card' },
            el('strong', { class: 'card-title', text: L('ui_leave') }),
            el('small', { class: 'muted', text: L('ui_leave_help') }),
            el('div', { class: 'rank-row' }, confirmButton([icon('kick', 16, 2), ` ${L('ui_leave')}`], leave))) : null,
    ];
}

async function memberPage(citizenid) {
    const response = await run('member', { citizenid, days: app.period });
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;
    const member = data.member;
    const drugs = list(data.drugs);
    const recent = list(data.recent);
    const mostEarned = Math.max(1, ...drugs.map((drug) => drug.earned));
    const period = data.days === 1 ? L('ui_24h') : L('ui_days_n', data.days);

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('span', { class: 'avatar big' }, initials(member.name), el('i', { class: `presence${member.online ? ' on' : ''}` })),
            el('div', { class: 'who grow' },
                el('h2', { text: member.name }),
                el('small', { text: member.online ? L('ui_online_now') : member.seen ? L('ui_last_seen', ago(member.seen)) : '' }),
                el('div', { class: 'pills' }, pill(member.gradeName, member.isboss ? 'accent' : ''), member.isMe ? pill(L('ui_you'), 'blue') : null)),
            el('div', { class: 'standing' },
                el('strong', { text: data.place ? `#${data.place}` : '—' }),
                el('small', { text: L('ui_of_members', data.size) })),
        ),
        el('div', { class: 'tiles' },
            tile('money', 'green', L('ui_earned'), money(data.earned), `${period} · ${L('ui_share', data.share)}`),
            tile('cart', 'gold', L('ui_sales'), String(data.sales), L('ui_average_sale', money(data.average))),
            tile('flask', 'purple', L('ui_made'), String(data.made), L('ui_units')),
        ),
        chart(L('ui_last_days', list(data.chart.days).length), data.chart),
        el('div', { class: 'two-cols' },
            el('div', { class: 'card' },
                el('strong', { class: 'card-title', text: L('ui_by_drug') }),
                drugs.length ? drugs.map((drug) => el('div', { class: 'spread' },
                    el('span', { class: 'spread-label', text: drugLabel(drug.drug) }),
                    el('span', { class: 'meter' }, el('span', { class: 'fill', style: `width: ${Math.round((drug.earned / mostEarned) * 100)}%` })),
                    el('span', { class: 'muted count', text: money(drug.earned) }),
                    el('span', { class: 'muted count small', text: `${drug.made} ${L('ui_units')}` }))) : el('small', { class: 'muted', text: L('ui_nothing_yet') }),
            ),
            el('div', { class: 'card flush' },
                el('div', { class: 'card-head padded' }, el('strong', { class: 'card-title', text: L('ui_activity') })),
                recent.length ? recent.map((entry) => {
                    const [iconName, kind] = LOOK[entry.action] || ['log', 'grey'];
                    return el('div', { class: 'info-row' },
                        el('span', { class: `tile-icon small ${kind}` }, icon(iconName, 14, 2)),
                        el('span', { class: 'grow' }, ...line(entry)),
                        el('small', { class: 'muted', text: ago(entry.time) }));
                }) : el('div', { class: 'list-empty', text: L('ui_log_empty') }),
            ),
        ),
        ...controls(member),
    );
}
