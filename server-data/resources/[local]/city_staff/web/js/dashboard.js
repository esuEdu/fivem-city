import { el, L, run, icon, heading, segmented, stars, initials, shortName, duration, ago } from './ui.js';
import { go, can, setStaffOnline } from './main.js';

let period = 'today';

function tile(iconName, kind, label, value, sub, subKind = '') {
    return el('div', { class: 'card tile' },
        el('div', { class: 'tile-head' }, el('span', { class: `tile-icon ${kind}` }, icon(iconName, 18, 2)), el('span', { text: label })),
        el('strong', { class: 'tile-value', text: value }),
        el('small', { class: `tile-sub ${subKind}`, text: sub }),
    );
}

function chart(days) {
    const max = Math.max(1, ...days.map((day) => Math.max(day.sent, day.closed)));
    const height = (n) => `height: ${Math.round((n / max) * 160)}px`;

    return el('div', { class: 'card' },
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_chart_title') }), el('span', { class: 'spacer' }),
            el('span', { class: 'legend' }, el('i', { class: 'sent' }), L('ui_chart_sent')),
            el('span', { class: 'legend' }, el('i', { class: 'closed' }), L('ui_chart_closed'))),
        el('div', { class: 'bars' }, days.map((day) => el('div', { class: 'bar-day' },
            el('div', { class: 'bar-pair' },
                el('span', { class: 'bar sent', style: height(day.sent), title: L('ui_chart_sent_n', day.sent) }),
                el('span', { class: 'bar closed', style: height(day.closed), title: L('ui_chart_closed_n', day.closed) })),
            el('small', { text: day.day })))),
    );
}

function myCard(data) {
    const me = data.me;
    const percent = me.goal ? Math.min(100, Math.round((me.closed / me.goal) * 100)) : 0;

    return el('div', { class: 'card' },
        el('strong', { class: 'card-title', text: L(`ui_your_${data.period}`) }),
        el('div', { class: 'ring-row' },
            el('div', { class: 'ring', style: `--ring: ${percent}%` },
                el('div', { class: 'ring-inner' }, el('strong', { text: String(me.closed) }), el('small', { text: L('ui_of_goal', me.goal) }))),
            el('div', { class: 'who' }, el('small', { text: L('ui_reports_you_closed') }),
                el('span', { text: me.rank ? L('ui_rank', me.rank, data.teamSize) : L('ui_no_rank') })),
        ),
        el('div', { class: 'mini-grid' },
            el('div', { class: 'mini' }, el('small', { text: L('ui_your_rating') }), el('strong', { class: 'gold', text: me.rating ? `${me.rating} ★` : '—' }),
                el('small', { text: L('ui_from_players', me.ratings || 0) })),
            el('div', { class: 'mini' }, el('small', { text: L('ui_first_reply') }), el('strong', { text: duration(me.response) }),
                el('small', { class: 'good', text: L('ui_team_reply', duration(data.response)) })),
        ),
    );
}

function team(members) {
    return el('div', { class: 'card flush' },
        el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_team') }), el('span', { class: 'spacer' }), el('small', { text: L(`ui_period_${period}`) })),
        el('div', { class: 'table-head team-cols' }, ['ui_staff', 'ui_closed', 'ui_rating', 'ui_first_reply'].map((key) => el('span', { text: L(key) }))),
        members.length ? members.map((member) => el('div', { class: 'table-row team-cols' },
            el('div', { class: 'person' },
                el('span', { class: 'avatar' }, initials(member.name), el('i', { class: `presence${member.online ? ' on' : ''}` })),
                el('div', { class: 'who' }, el('strong', { text: shortName(member.name) }), el('small', { text: member.level ? L(`level_${member.level}`) : '' }))),
            el('strong', { text: String(member.closed) }),
            el('span', { class: 'gold', text: member.rating ? `${member.rating} ★` : '—' }),
            el('span', { class: 'muted', text: duration(member.response) }),
        )) : el('div', { class: 'table-row muted', text: L('ui_no_team') }),
    );
}

export function ratingCard(rating) {
    return el('div', { class: 'rating-card' },
        el('div', { class: 'rating-top' }, el('span', { class: 'gold stars', text: stars(rating.rating) }), el('span', { class: 'spacer' }), el('small', { text: ago(rating.rated_at) })),
        rating.rating_comment ? el('span', { text: `“${rating.rating_comment}”` }) : null,
        rating.rating_tags ? el('div', { class: 'chips' }, rating.rating_tags.split(',').map((tag) => el('span', { class: 'chip', text: tag }))) : null,
        el('small', { text: L('ui_rating_from', shortName(rating.name), shortName(rating.closed_name), rating.id) }),
    );
}

export async function renderDashboard() {
    const response = await run('dashboard', { period });
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;
    setStaffOnline(data.staffOnline);

    const delta = data.closed - data.closedBefore;
    const waiting = data.waitingSince ? L('ui_waiting', duration(data.waitingSince)) : L('ui_none_waiting');

    return el('div', { class: 'stack' },
        heading(L('ui_tab_dashboard'), el('span', { class: 'spacer' }),
            segmented([['today', L('ui_today')], ['week', L('ui_week')], ['month', L('ui_month')]], period, (value) => {
                period = value;
                go('dashboard');
            })),
        el('div', { class: 'tiles' },
            tile('reports', 'blue', L('ui_open_reports_tile'), String(data.open), waiting, data.waitingSince ? 'warn' : ''),
            tile('check', 'green', L(`ui_closed_${data.period}`), String(data.closed), L('ui_delta', delta >= 0 ? `+${delta}` : String(delta)), delta >= 0 ? 'good' : 'bad'),
            tile('clock', 'gold', L('ui_first_reply'), duration(data.response), L('ui_average')),
            tile('star', 'red', L('ui_staff_rating'), data.rating ? `${data.rating} ★` : '—', L('ui_ratings_count', data.ratings)),
        ),
        el('div', { class: 'two-cols' }, chart(data.chart), myCard(data)),
        el('div', { class: 'two-cols' }, team(data.team),
            el('div', { class: 'card' },
                el('div', { class: 'card-head' }, el('strong', { text: L('ui_latest_ratings') }), el('span', { class: 'spacer' }),
                    can('ratings') ? el('button', { class: 'link', text: L('ui_see_all'), onclick: () => go('ratings') }) : null),
                data.latest.length ? data.latest.map(ratingCard) : el('small', { class: 'muted', text: L('ui_no_ratings') }))),
    );
}
