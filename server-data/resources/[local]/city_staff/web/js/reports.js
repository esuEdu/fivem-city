import { el, L, run, pill, segmented, stars, shortName, ago, confirmButton } from './ui.js';
import { can, go, setReportsBadge } from './main.js';

let reports = [];
let selected = null;
let filter = 'open';

// Fetches the reports and updates the sidebar badge
export async function loadReports() {
    const response = await run('reports');
    reports = response ? response.data : [];
    setReportsBadge(reports.filter((report) => !report.closed).length);
}

function status(report) {
    if (report.closed) return pill(L('ui_closed'));
    return report.claimedBy ? pill(L('ui_claimed'), 'blue') : pill(L('ui_new'), 'accent');
}

export async function renderReports(args) {
    await loadReports();

    if (args && args.id) {
        selected = args.id;
        const report = reports.find((entry) => entry.id === selected);
        if (report) filter = report.closed ? 'closed' : 'open';
    }

    const shown = reports.filter((report) => filter === 'closed' ? report.closed : !report.closed && (filter === 'open' || report.mine));
    if (!shown.some((report) => report.id === selected)) selected = shown.length ? shown[0].id : null;

    const open = reports.filter((report) => !report.closed).length;

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_reports') }), pill(L('ui_open_reports', open), open ? 'accent' : '')),
            segmented([['open', L('ui_filter_open')], ['mine', L('ui_filter_mine')], ['closed', L('ui_filter_closed')]], filter, (value) => {
                filter = value;
                selected = null;
                go('reports');
            }),
            el('div', { class: 'cards' }, shown.length ? shown.map((report) => el('button', { class: `report-card${report.id === selected ? ' on' : ''}`, onclick: () => go('reports', { id: report.id }) },
                el('div', { class: 'report-top' }, el('strong', { class: 'muted', text: `#${report.id}` }), el('strong', { text: shortName(report.name) }), el('span', { class: 'spacer' }), status(report)),
                el('span', { class: 'report-msg', text: report.message }),
                el('small', { text: [ago(report.time), report.rating ? stars(report.rating) : report.claimedBy ? shortName(report.claimedBy) : null].filter(Boolean).join(' · ') }),
            )) : el('div', { class: 'list-empty', text: L(`ui_no_reports_${filter}`) })),
        ),
        el('div', { class: 'split-detail' }, selected ? detail(reports.find((report) => report.id === selected)) : el('div', { class: 'empty', text: L('ui_pick_report') })),
    );
}

function detail(report) {
    const refresh = () => go('reports', { id: report.id });
    const reply = el('input', { class: 'field', type: 'text', maxlength: '300', placeholder: L('ui_reply_placeholder'), 'aria-label': L('ui_reply_placeholder') });
    const send = async () => {
        if (!reply.value.trim()) return reply.focus();
        if (await run('replyReport', { id: report.id, text: reply.value }, L('ui_reply_sent'))) refresh();
    };
    reply.addEventListener('keydown', (event) => event.key === 'Enter' && send());

    const button = (label, onclick) => el('button', { class: 'kit-btn', text: label, onclick });

    return el('div', { class: 'card conversation' },
        el('div', { class: 'heading' },
            el('div', { class: 'who' }, el('h2', { text: L('ui_report_n', report.id) }),
                el('small', { text: [shortName(report.name), report.target ? L('ui_id_n', report.target) : L('ui_offline'), ago(report.time)].join(' · ') })),
            el('span', { class: 'spacer' }), status(report)),
        el('div', { class: 'bubble player', text: report.message }),
        report.replies.map((entry) => el('div', { class: 'bubble staff' }, el('small', { text: `${shortName(entry.name)} · ${ago(entry.time)}` }), el('span', { text: entry.text }))),
        report.claimedBy && !report.closed ? el('small', { class: 'muted', text: L('ui_claimed_by', shortName(report.claimedBy)) }) : null,
        report.closed ? el('div', { class: 'rated' },
            el('small', { text: report.rating ? L('ui_rating_for', shortName(report.closedBy)) : L('ui_closed_by', shortName(report.closedBy)) }),
            report.rating ? el('span', { class: 'gold big-stars', text: stars(report.rating) }) : el('small', { class: 'muted', text: L('ui_not_rated') }),
            report.ratingComment ? el('span', { text: `“${report.ratingComment}”` }) : null,
            report.ratingTags ? el('div', { class: 'chips' }, report.ratingTags.split(',').map((tag) => el('span', { class: 'chip', text: tag }))) : null,
        ) : null,
        el('span', { class: 'grow' }),
        report.closed ? null : el('div', { class: 'stack small' },
            report.target ? el('div', { class: 'form-row' }, reply, el('button', { class: 'kit-btn accent', text: L('ui_reply'), onclick: send })) : el('small', { class: 'bad', text: L('ui_reporter_offline') }),
            el('div', { class: 'form-row' },
                report.claimedBy ? null : button(L('ui_claim'), async () => (await run('claimReport', { id: report.id })) && refresh()),
                report.target && can('goto') ? button(L('ui_goto_player'), () => run('goto', { target: report.target }, L('ui_done'))) : null,
                report.target && can('bring') ? button(L('ui_bring'), () => run('bring', { target: report.target }, L('ui_done'))) : null,
                report.target ? button(L('ui_open_player'), () => go('players', { id: report.target })) : null,
                el('span', { class: 'spacer' }),
                confirmButton(L(report.target ? 'ui_close_and_rate' : 'ui_close_report'), async () => (await run('closeReport', { id: report.id }, L('ui_report_closed'))) && refresh(), 'success'),
            ),
        ),
    );
}
