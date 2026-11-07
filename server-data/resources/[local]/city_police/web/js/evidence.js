import { el, L, run, icon, pill, formatTime, empty } from './ui.js';
import { app, go } from './main.js';

const KIND_ICON = { casing: 'weapons', blood: 'evidence', fingerprint: 'fingerprint' };

function findingsCard(item) {
    const rows = [];
    const row = (label, value, onclick) => rows.push(el('div', { class: 'info-row' }, el('span', { text: label }),
        onclick ? el('button', { class: 'link value', text: value, onclick }) : el('span', { class: 'value', text: value || '—' })));

    if (item.kind === 'casing') {
        row(L('ui_weapon'), item.weapon);
        row(L('ui_serial'), item.serial, item.serial ? () => go('weapons', { serial: item.serial }) : null);
    } else if (item.kind === 'blood') {
        row(L('ui_bloodtype'), item.bloodtype);
    } else if (item.kind === 'fingerprint') {
        row(L('ui_fingerprint'), item.fingerprint);
    }

    row(L('ui_match'), item.owner || L('ui_no_match'), item.ownerCid ? () => go('people', { citizenid: item.ownerCid }) : null);

    return el('div', { class: 'card flush' },
        el('div', { class: 'card-head padded' }, icon(KIND_ICON[item.kind], 18), el('strong', { text: `#${item.id} ${L(`evidence_kind_${item.kind}`)}` }),
            el('span', { class: 'spacer' }), el('small', { class: 'muted', text: item.place || '' })),
        ...rows,
        el('div', { class: 'info-row' }, el('span', { text: L('ui_collected') }), el('span', { class: 'value', text: `${item.collectedBy} · ${formatTime(item.collectedAt)}` })),
        item.analyzedAt ? el('div', { class: 'info-row' }, el('span', { text: L('ui_analyzed') }), el('span', { class: 'value', text: `${item.analyzedBy} · ${formatTime(item.analyzedAt)}` })) : null,
    );
}

export async function renderEvidence(args) {
    app.editing = false;

    if (args && args.id) {
        const response = await run('evidenceItem', { id: args.id });
        return el('div', { class: 'stack' },
            el('div', { class: 'heading' }, el('button', { class: 'kit-btn', onclick: () => go('evidence') }, icon('back', 16)), el('h1', { text: L('ui_tab_evidence') })),
            response ? (response.data.analyzedAt ? findingsCard(response.data) : el('div', { class: 'card' }, el('p', { text: L('ui_not_analyzed_yet', response.data.id) })))
                : empty(L('error_not_found')),
        );
    }

    const response = await run('evidence');
    const data = response ? response.data : { bags: [], results: [], atLab: false, forensics: false };

    const scanTarget = el('div', { class: 'button-row' });

    const bags = el('div', { class: 'card flush' },
        el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_my_bags') }), el('span', { class: 'spacer' }),
            data.atLab ? pill(L('ui_at_lab'), 'green') : pill(L('ui_not_at_lab'))),
        data.bags.length ? data.bags.map((bag) => el('div', { class: 'info-row tall' },
            icon(KIND_ICON[bag.kind] || 'evidence', 18),
            el('strong', { class: 'grow', text: bag.label }),
            el('button', { class: 'kit-btn accent', disabled: !data.atLab || !data.forensics, onclick: async () => {
                const result = await run('analyze', { slot: bag.slot }, L('ui_analysis_done'));
                if (result) go('evidence', { id: result.data.id });
            } }, L('ui_analyze')),
        )) : empty(L('ui_no_bags')),
        !data.forensics ? el('p', { class: 'muted padded small', text: L('ui_needs_forensics') }) : null,
    );

    const scanner = el('div', { class: 'card' },
        el('div', { class: 'card-head' }, icon('fingerprint', 18), el('strong', { text: L('ui_fingerprint_scanner') })),
        el('small', { class: 'muted', text: L('ui_scanner_hint') }),
        scanTarget,
    );

    if (data.atLab) {
        const nearby = await run('nearby');
        const people = nearby ? nearby.data : [];

        scanTarget.replaceChildren(...(people.length ? people.map((person) => el('button', { class: 'kit-btn', onclick: async () => {
            const result = await run('scanFingerprint', { target: person.id });
            if (result) scanTarget.replaceChildren(el('div', { class: 'scan-result' }, icon('fingerprint', 22),
                el('span', { class: 'grow' }, el('strong', { text: result.data.fingerprint }), el('small', { class: 'block muted', text: result.data.name })),
                el('button', { class: 'kit-btn', onclick: () => go('people', { citizenid: result.data.citizenid }) }, L('ui_open_file'))));
        } }, icon('user', 14), ' ', person.name)) : [el('small', { class: 'muted', text: L('ui_nobody_near') })]));
    }

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_evidence') })),
        el('div', { class: 'two-cols even' }, bags, scanner),
        el('div', { class: 'card-head' }, el('strong', { text: L('ui_lab_results') })),
        data.results.length ? el('div', { class: 'two-cols even' }, data.results.map(findingsCard)) : empty(L('ui_no_results_yet')),
    );
}
