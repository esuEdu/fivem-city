import { el, L, run, icon, formatTime, empty } from './ui.js';
import { app, can, go } from './main.js';
import { personPicker } from './picker.js';

let selected = null;

export async function renderLicences(args) {
    app.editing = false;
    if (args && args.citizenid) selected = args.citizenid;

    const picker = personPicker((person) => go('licences', { citizenid: person.citizenid }));

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_licences') })),
        el('div', { class: 'card' }, picker),
        selected ? await licencePage(selected) : el('div', { class: 'empty' }, icon('licences', 40), el('p', { text: L('ui_pick_person') })),
    );
}

async function licencePage(citizenid) {
    const response = await run('licences', { citizenid });
    if (!response) return empty(L('error_not_found'));

    const data = response.data;
    const percent = Math.min(100, Math.round((data.points / app.maxPoints) * 100));

    const toggle = (kind) => {
        const on = data.licences[kind] === true;
        const allowed = kind === 'weapon' ? can('weaponLicence') : can('licences');

        return el('div', { class: 'info-row tall' },
            icon('licences', 18),
            el('span', { class: 'grow' }, el('strong', { text: L(`licence_${kind}`) }), el('small', { class: 'block muted', text: on ? L('ui_valid') : L('ui_not_held') })),
            el('button', { class: `kit-switch${on ? ' on' : ''}`, disabled: !allowed, 'aria-label': L(`licence_${kind}`), onclick: async () => {
                if (await run('setLicence', { citizenid, licence: kind, on: !on }, L('ui_saved'))) go('licences', { citizenid });
            } }),
        );
    };

    return el('div', { class: 'stack' },
        el('div', { class: 'card profile' },
            el('div', { class: 'who grow' },
                el('button', { class: 'link big', text: data.name, onclick: () => go('people', { citizenid }) }),
                el('small', { text: citizenid })),
        ),
        el('div', { class: 'card flush' }, toggle('driver'), toggle('weapon')),
        el('div', { class: 'card' },
            el('div', { class: 'card-head' }, el('strong', { text: L('ui_driving_points') }), el('span', { class: 'spacer' }),
                el('strong', { class: percent >= 100 ? 'bad' : '', text: `${data.points} / ${app.maxPoints}` })),
            el('span', { class: 'meter' }, el('span', { class: percent >= 75 ? 'bad' : percent >= 40 ? 'warn' : 'ok', style: `width: ${percent}%` })),
            el('small', { class: 'muted', text: L('ui_points_rule', app.pointsDays, app.maxPoints) }),
            data.history.length ? el('div', { class: 'stack small' }, data.history.map((row) => el('div', { class: 'warning' },
                el('span', { text: (row.charges || []).map((charge) => charge.title).join(', ') }),
                el('strong', { text: `+${row.points}` }),
                el('small', { text: `${row.officer} · ${formatTime(row.created)}` })))) : null,
        ),
    );
}
