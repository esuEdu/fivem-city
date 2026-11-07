import { el, L, run, heading, stars, shortName } from './ui.js';
import { ratingCard } from './dashboard.js';

export async function renderRatings() {
    const response = await run('ratings');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data;
    const most = Math.max(1, ...data.stars);
    const ratedShare = data.closed ? Math.round((data.ratings / data.closed) * 100) : 0;

    return el('div', { class: 'stack' },
        heading(L('ui_tab_ratings'), el('small', { class: 'muted', text: L('ui_ratings_sub') })),
        el('div', { class: 'two-cols reverse' },
            el('div', { class: 'card overall' },
                el('div', { class: 'overall-top' }, el('strong', { class: 'score', text: data.rating ? String(data.rating) : '—' }), el('span', { class: 'gold big-stars', text: stars(data.rating) })),
                el('small', { class: 'muted', text: L('ui_ratings_summary', data.ratings, `${ratedShare}%`) }),
                [5, 4, 3, 2, 1].map((n) => el('div', { class: 'spread' },
                    el('span', { class: 'muted', text: `${n} ★` }),
                    el('span', { class: 'meter' }, el('span', { class: 'gold-fill', style: `width: ${Math.round((data.stars[n - 1] / most) * 100)}%` })),
                    el('span', { class: 'muted count', text: String(data.stars[n - 1]) }))),
            ),
            el('div', { class: 'card flush' },
                el('div', { class: 'table-head rating-cols' }, ['ui_staff', 'ui_rating', 'ui_ratings', 'ui_closed', 'ui_trend'].map((key) => el('span', { text: L(key) }))),
                data.team.length ? data.team.map((member) => el('div', { class: 'table-row rating-cols' },
                    el('strong', { text: shortName(member.name) }),
                    el('span', { class: 'gold', text: member.rating ? `${member.rating} ★` : '—' }),
                    el('span', { class: 'muted', text: String(member.ratings) }),
                    el('span', { class: 'muted', text: String(member.closed) }),
                    el('strong', { class: member.trend > 0 ? 'good' : member.trend < 0 ? 'bad' : 'muted', text: member.trend === null || member.trend === undefined ? '—' : `${member.trend > 0 ? '+' : ''}${member.trend}` }),
                )) : el('div', { class: 'table-row muted', text: L('ui_no_team') }),
            ),
        ),
        data.latest.length ? el('div', { class: 'rating-grid' }, data.latest.map(ratingCard)) : el('div', { class: 'empty', text: L('ui_no_ratings') }),
    );
}
