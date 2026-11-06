import { el, L, run, section, infoRow, confirmButton, searchField, formatTime } from './ui.js';
import { app, can, go } from './main.js';

let filter = '';

export async function renderPlayers() {
    const response = await run('players');
    const players = response ? response.data : [];

    const list = el('div', { class: 'kit-group' });
    const draw = () => {
        const shown = players.filter((player) => !filter || [String(player.id), player.name, player.account, player.citizenid]
            .some((value) => value && value.toLowerCase().includes(filter)));

        list.replaceChildren(...(shown.length ? shown.map((player) => el('button', { class: 'kit-row player', onclick: () => go('player', player.id) },
            el('span', { class: 'id', text: String(player.id) }),
            el('span', { class: 'who' }, el('strong', { text: player.name }), el('small', { text: player.account })),
            el('span', { class: 'kit-value', text: player.job }),
        )) : [el('div', { class: 'kit-row muted', text: L('ui_no_players') })]));
    };

    draw();

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { class: 'kit-heading', text: L('ui_tab_players') }), el('span', { class: 'kit-pill', text: L('ui_online', players.length) }),
            el('button', { class: 'kit-btn', text: L('ui_refresh'), onclick: () => go('players') })),
        searchField(L('ui_search_players'), (value) => {
            filter = value;
            draw();
        }),
        list,
    );
}

// One player's page: info, actions, job and gang, sanctions, warnings
export async function renderPlayer(id) {
    const response = await run('player', { target: id });
    if (!response) return el('div', { class: 'stack' }, backButton(), el('div', { class: 'empty', text: L('error_no_player') }));

    const player = response.data;
    const target = player.id;
    const refresh = () => go('player', target);

    // Runs an action on this player and shows the page again with the new state
    const act = (action, extra = {}, done = L('ui_done')) => async () => {
        const result = await run(action, { target, ...extra }, done);
        if (result && !['inventory', 'spectate', 'kick', 'ban'].includes(action)) refresh();
        if (result && (action === 'kick' || action === 'ban')) go('players');
    };

    const button = (action, label, kind) => can(action) ? el('button', { class: `kit-btn ${kind || ''}`, text: label, onclick: act(action) }) : null;

    const status = [
        player.staff ? el('span', { class: 'kit-pill accent', text: L(`level_${player.staff}`) }) : null,
        player.frozen ? el('span', { class: 'kit-pill', text: L('ui_frozen') }) : null,
        player.dead ? el('span', { class: 'kit-pill bad', text: L('ui_down') }) : null,
        player.cuffed ? el('span', { class: 'kit-pill', text: L('ui_cuffed') }) : null,
    ];

    const actions = [
        button('goto', L('ui_goto')),
        button('bring', L('ui_bring')),
        button('spectate', L('ui_spectate')),
        button('heal', L('ui_heal')),
        button('revive', L('ui_revive')),
        button('freeze', player.frozen ? L('ui_unfreeze') : L('ui_freeze')),
        button('cuff', player.cuffed ? L('ui_uncuff') : L('ui_cuff')),
        button('inventory', L('ui_inventory')),
        button('clothing', L('ui_clothing')),
        can('kill') ? confirmButton(L('ui_kill'), act('kill')) : null,
    ].filter(Boolean);

    return el('div', { class: 'stack' },
        backButton(),
        el('div', { class: 'kit-card profile' },
            el('div', { class: 'big-id', text: String(target) }),
            el('div', { class: 'who' }, el('h1', { text: player.name }), el('small', { text: `${player.account} · ${player.citizenid}` }), el('div', { class: 'pills' }, status)),
        ),
        section(L('ui_info'), [
            infoRow(L('ui_job'), player.jobGrade ? `${player.job} · ${player.jobGrade}` : player.job),
            infoRow(L('ui_gang'), player.gangGrade ? `${player.gang} · ${player.gangGrade}` : player.gang),
            infoRow(L('ui_ping'), `${player.ping} ms`),
            infoRow(L('ui_bucket'), String(player.bucket)),
            infoRow(L('ui_license'), player.license),
        ]),
        actions.length ? section(L('ui_actions'), [el('div', { class: 'actions' }, actions)]) : null,
        groupForms(player, act),
        sanctions(act),
        section(L('ui_warnings', player.warnings.length), player.warnings.length
            ? player.warnings.map((warning) => el('div', { class: 'kit-row entry' }, el('span', { text: warning.reason }), el('small', { class: 'kit-value', text: `${warning.staff_name} · ${formatTime(warning.time)}` })))
            : [el('div', { class: 'kit-row muted', text: L('ui_no_warnings') })]),
    );
}

function backButton() {
    return el('button', { class: 'kit-btn back', text: `‹ ${L('ui_tab_players')}`, onclick: () => go('players') });
}

// Job, gang and routing bucket forms, for the levels that have them
function groupForms(player, act) {
    const rows = [];

    for (const kind of ['job', 'gang']) {
        const action = kind === 'job' ? 'setJob' : 'setGang';
        const groups = kind === 'job' ? app.jobs : app.gangs;
        if (!can(action) || !groups) continue;

        const grade = el('select', { class: 'kit-input' });
        const name = el('select', { class: 'kit-input wide', onchange: () => fillGrades() }, groups.map((group) => el('option', { value: group.name, text: group.label })));
        const fillGrades = () => {
            const group = groups.find((entry) => entry.name === name.value);
            grade.replaceChildren(...(group ? group.grades : []).map((entry) => el('option', { value: String(entry.level), text: `${entry.level} · ${entry.name}` })));
        };
        fillGrades();

        rows.push(el('div', { class: 'kit-row form' }, el('span', { class: 'label', text: L(`ui_${kind}`) }), name, grade,
            el('button', { class: 'kit-btn', text: L('ui_set'), onclick: () => act(action, { name: name.value, grade: Number(grade.value) })() })));
    }

    if (can('bucket')) {
        const bucket = el('input', { class: 'kit-input', type: 'number', min: '0', max: String(app.maxBucket), value: String(player.bucket) });
        rows.push(el('div', { class: 'kit-row form' }, el('span', { class: 'label', text: L('ui_bucket') }), bucket,
            el('button', { class: 'kit-btn', text: L('ui_set'), onclick: () => act('bucket', { bucket: Number(bucket.value) })() })));
    }

    return rows.length ? section(L('ui_change'), rows) : null;
}

function sanctions(act) {
    if (!can('warn') && !can('kick') && !can('ban')) return null;

    const reason = el('input', { class: 'kit-input wide', type: 'text', maxlength: '200', placeholder: L('ui_reason') });
    const withReason = (action, extra) => () => {
        if (!reason.value.trim()) return reason.focus();
        act(action, { reason: reason.value, ...extra }, L(`ui_${action}_done`))();
    };

    const lengths = app.banLengths.filter((hours) => can('banLong') || (hours > 0 && hours <= app.maxBanHours));
    const length = el('select', { class: 'kit-input' }, lengths.map((hours) => el('option', { value: String(hours), text: hours === 0 ? L('permanent') : L('hours', hours) })));

    return section(L('ui_sanctions'), [
        el('div', { class: 'kit-row form' }, reason),
        el('div', { class: 'kit-row form' },
            can('warn') ? el('button', { class: 'kit-btn', text: L('ui_warn'), onclick: withReason('warn') }) : null,
            can('kick') ? confirmButton(L('ui_kick'), withReason('kick')) : null,
            can('ban') ? el('span', { class: 'spacer' }) : null,
            can('ban') ? length : null,
            can('ban') ? confirmButton(L('ui_ban'), () => withReason('ban', { hours: Number(length.value) })()) : null,
        ),
    ], L('ui_sanctions_foot'));
}
