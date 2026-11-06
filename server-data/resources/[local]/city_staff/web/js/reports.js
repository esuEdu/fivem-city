import { el, L, run, ago, confirmButton } from './ui.js';
import { go, setReportsBadge } from './main.js';

let reports = [];
let selected = null;

// Fetches the reports and updates the sidebar badge
export async function openReports() {
    const response = await run('reports');
    reports = response ? response.data : [];
    setReportsBadge(reports.filter((report) => !report.closed).length);
}

export async function renderReports(args) {
    await openReports();
    if (args && args.id) selected = args.id;

    const open = reports.filter((report) => !report.closed);
    const closed = reports.filter((report) => report.closed);

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { class: 'kit-heading', text: L('ui_tab_reports') }), el('span', { class: 'kit-pill', text: L('ui_open_reports', open.length) })),
        open.length ? el('div', { class: 'reports' }, open.map(card)) : el('div', { class: 'empty', text: L('ui_no_reports') }),
        closed.length ? el('div', { class: 'kit-head', text: L('ui_closed_reports') }) : null,
        closed.length ? el('div', { class: 'reports' }, closed.map(card)) : null,
    );
}

function card(report) {
    const expanded = selected === report.id;
    const refresh = () => go('reports');

    const head = el('button', { class: 'report-head', onclick: () => {
        selected = expanded ? null : report.id;
        refresh();
    } },
        el('span', { class: 'id', text: `#${report.id}` }),
        el('span', { class: 'who' }, el('strong', { text: report.name }), el('small', { text: report.message })),
        el('span', { class: 'kit-value', text: ago(report.time) }),
        report.claimedBy ? el('span', { class: 'kit-pill', text: L('ui_claimed') }) : el('span', { class: 'kit-pill accent', text: L('ui_new') }),
    );

    if (!expanded) return el('div', { class: `kit-card report${report.closed ? ' closed' : ''}` }, head);

    const reply = el('input', { class: 'kit-input wide', type: 'text', maxlength: '300', placeholder: L('ui_reply_placeholder') });
    const send = async () => {
        if (!reply.value.trim()) return reply.focus();
        if (await run('replyReport', { id: report.id, text: reply.value }, L('ui_reply_sent'))) refresh();
    };
    reply.addEventListener('keydown', (event) => event.key === 'Enter' && send());

    return el('div', { class: `kit-card report open${report.closed ? ' closed' : ''}` },
        head,
        el('p', { class: 'message', text: report.message }),
        report.claimedBy ? el('div', { class: 'meta', text: L('ui_claimed_by', report.claimedBy) }) : null,
        report.target ? null : el('div', { class: 'meta bad', text: L('ui_reporter_offline') }),
        report.replies.map((entry) => el('div', { class: 'reply' }, el('strong', { text: entry.name }), el('span', { text: entry.text }), el('small', { text: ago(entry.time) }))),
        report.closed ? null : el('div', { class: 'row-actions' },
            report.target ? reply : null,
            report.target ? el('button', { class: 'kit-btn accent', text: L('ui_reply'), onclick: send }) : null,
        ),
        report.closed ? null : el('div', { class: 'row-actions' },
            report.claimedBy ? null : el('button', { class: 'kit-btn', text: L('ui_claim'), onclick: async () => (await run('claimReport', { id: report.id })) && refresh() }),
            report.target ? el('button', { class: 'kit-btn', text: L('ui_goto'), onclick: () => run('goto', { target: report.target }, L('ui_done')) }) : null,
            report.target ? el('button', { class: 'kit-btn', text: L('ui_open_player'), onclick: () => go('player', report.target) }) : null,
            el('span', { class: 'spacer' }),
            confirmButton(L('ui_close_report'), async () => (await run('closeReport', { id: report.id }, L('ui_report_closed'))) && refresh(), ''),
        ),
    );
}
