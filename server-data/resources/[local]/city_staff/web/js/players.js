import { el, L, run, icon, pill, confirmButton, searchField, formatTime, duration, money, healthKind } from './ui.js';
import { app, can, go } from './main.js';
import { characterCard } from './character.js';

let filter = '';
let selected = null;

// The list on the left and the selected player on the right
export async function renderPlayers(args) {
    if (args && args.id) selected = args.id;

    const response = await run('players');
    const players = response ? response.data : [];
    if (!players.some((player) => player.id === selected)) selected = players.length ? players[0].id : null;

    const list = el('div', { class: 'list' });
    const draw = () => {
        const shown = players.filter((player) => !filter || [String(player.id), player.name, player.account, player.citizenid]
            .some((value) => value && value.toLowerCase().includes(filter)));

        list.replaceChildren(...(shown.length ? shown.map((player) => el('button', { class: `list-row${player.id === selected ? ' on' : ''}`, onclick: () => go('players', { id: player.id }) },
            el('span', { class: 'id', text: String(player.id) }),
            el('span', { class: 'who' }, el('strong', { text: player.name }), el('small', { text: `${player.job} · ${duration(player.online)}` })),
            el('span', { class: 'meter small' }, el('span', { class: healthKind(player.health), style: `width: ${player.health}%` })),
        )) : [el('div', { class: 'list-empty', text: L('ui_no_players') })]));
    };

    draw();

    return el('div', { class: 'split' },
        el('div', { class: 'split-list' },
            el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_players') }), el('span', { class: 'pill', text: L('ui_online', players.length) }),
                el('span', { class: 'spacer' }), el('button', { class: 'kit-btn', text: L('ui_refresh'), onclick: () => go('players') })),
            searchField(L('ui_search_players'), (value) => {
                filter = value;
                draw();
            }),
            list,
        ),
        el('div', { class: 'split-detail' }, selected ? await playerDetail(selected) : el('div', { class: 'empty', text: L('ui_no_players') })),
    );
}

async function playerDetail(id) {
    const response = await run('player', { target: id });
    if (!response) return el('div', { class: 'empty', text: L('error_no_player') });

    const player = response.data;
    const target = player.id;
    const refresh = () => go('players', { id: target });

    // Runs an action on this player and shows the page again with the new state
    const act = (action, extra = {}, done = L('ui_done')) => async () => {
        const result = await run(action, { target, ...extra }, done);
        if (!result) return;
        if (action === 'kick' || action === 'ban') return go('players');
        if (action !== 'inventory' && action !== 'spectate') refresh();
    };

    const pills = [
        player.staff ? pill(L(`level_${player.staff}`), 'accent') : null,
        player.frozen ? pill(L('ui_frozen'), 'blue') : null,
        player.dead ? pill(L('ui_down'), 'bad') : null,
        player.cuffed ? pill(L('ui_cuffed')) : null,
        pill(L('ui_warnings_count', player.warnings.length)),
    ];

    const stat = (label, value, percent, kind) => el('div', { class: 'card stat' },
        el('small', { text: label }), el('strong', { text: value }),
        percent === undefined ? null : el('span', { class: 'meter' }, el('span', { class: kind, style: `width: ${percent}%` })));

    const infoRow = (iconName, label, value) => el('div', { class: 'info-row' }, icon(iconName, 18), el('span', { text: label }), el('span', { class: 'value', text: value || '—' }));

    // state: 'on' while the player is frozen or cuffed, 'attention' when the button is what they need (Revive while down)
    const actionButton = (action, iconName, label, state = '') => can(action)
        ? el('button', { class: `action ${state}`, 'aria-pressed': state === 'on' ? 'true' : null, onclick: act(action) }, el('span', { class: 'action-icon' }, icon(iconName, 26, 1.8)), el('span', { text: label }))
        : null;

    const actions = [
        actionButton('goto', 'goto', L('ui_goto')),
        actionButton('bring', 'bring', L('ui_bring')),
        actionButton('spectate', 'spectate', L('ui_spectate')),
        actionButton('heal', 'heal', L('ui_heal')),
        actionButton('revive', 'revive', player.dead ? L('ui_revive') : L('ui_full_health'), player.dead ? 'attention' : ''),
        actionButton('freeze', 'freeze', player.frozen ? L('ui_unfreeze') : L('ui_freeze'), player.frozen ? 'on' : ''),
        actionButton('cuff', 'cuff', player.cuffed ? L('ui_uncuff') : L('ui_cuff'), player.cuffed ? 'on' : ''),
        actionButton('inventory', 'inventory', L('ui_inventory')),
        actionButton('clothing', 'clothing', L('ui_clothing')),
        can('kill') ? confirmButton([el('span', { class: 'action-icon' }, icon('kill', 26, 1.8)), el('span', { text: L('ui_kill') })], act('kill'), 'danger', 'action') : null,
    ].filter(Boolean);

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('div', { class: 'big-id', text: String(target) }),
            el('div', { class: 'who' }, el('h2', { text: player.name }),
                el('small', { text: `${player.account} · ${player.citizenid} · ${L('ui_online_for', duration(player.online))}` }),
                el('div', { class: 'pills' }, pills)),
        ),
        el('div', { class: 'stats' },
            stat(L('ui_health'), `${player.health}%`, player.health, healthKind(player.health)),
            stat(L('ui_armor'), `${player.armor}%`, player.armor, 'blue'),
            stat(L('ui_cash'), money(player.cash)),
            stat(L('ui_bank'), money(player.bank)),
        ),
        el('div', { class: 'card flush' },
            // Job, gang and bucket move to the Character card for staff who can change them
            can('setJob') && app.jobs ? null : infoRow('job', L('ui_job'), player.jobGrade ? `${player.job} · ${player.jobGrade}` : player.job),
            can('setGang') && app.gangs ? null : infoRow('gang', L('ui_gang'), player.gangGrade ? `${player.gang} · ${player.gangGrade}` : player.gang),
            infoRow('place', L('ui_location'), player.place),
            infoRow('vehicle', L('ui_vehicle'), player.vehicle ? `${player.vehicle.name || L('ui_unknown_vehicle')} · ${player.vehicle.plate}` : L('ui_on_foot')),
            infoRow('clock', L('ui_ping'), `${player.ping} ms`),
            can('bucket') ? null : infoRow('bucket', L('ui_bucket'), String(player.bucket)),
            infoRow('license', L('ui_license'), player.license),
        ),
        actions.length ? el('div', { class: 'card actions' }, actions) : null,
        characterCard(player, act),
        sanctions(player, act),
    );
}

function sanctions(player, act) {
    if (!can('warn') && !can('kick') && !can('ban')) return null;

    const reason = el('input', { class: 'field', type: 'text', maxlength: '200', placeholder: L('ui_reason'), 'aria-label': L('ui_reason') });
    const withReason = (action, extra) => () => {
        if (!reason.value.trim()) return reason.focus();
        act(action, { reason: reason.value, ...extra }, L(`ui_${action}_done`))();
    };

    const lengths = app.banLengths.filter((hours) => can('banLong') || (hours > 0 && hours <= app.maxBanHours));
    const length = el('select', { class: 'field', 'aria-label': L('ui_ban_length') }, lengths.map((hours) => el('option', { value: String(hours), text: hours === 0 ? L('permanent') : L('hours', hours) })));

    return el('div', { class: 'card form' },
        el('strong', { text: L('ui_sanctions') }),
        reason,
        el('div', { class: 'form-row' },
            can('warn') ? el('button', { class: 'kit-btn', text: L('ui_warn'), onclick: withReason('warn') }) : null,
            can('kick') ? confirmButton(L('ui_kick'), withReason('kick')) : null,
            el('span', { class: 'spacer' }),
            can('ban') ? length : null,
            can('ban') ? confirmButton(L('ui_ban'), () => withReason('ban', { hours: Number(length.value) })()) : null,
        ),
        player.warnings.length
            ? el('div', { class: 'warnings' }, player.warnings.map((warning) => el('div', { class: 'warning' },
                el('span', { text: warning.reason }), el('small', { text: `${warning.staff_name} · ${formatTime(warning.time)}` }))))
            : el('small', { class: 'muted', text: L('ui_no_warnings') }),
    );
}
