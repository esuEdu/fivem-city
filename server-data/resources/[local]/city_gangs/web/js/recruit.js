// The Recruit tab: people standing close by who aren't in a gang. Inviting asks them on their own screen; they join at
// the lowest rank only if they accept.

import { el, L, run, icon, initials, heading } from './ui.js';
import { app, go } from './main.js';

export async function renderRecruit() {
    const response = await run('nearby');
    const people = response ? response.data : [];
    const lowest = app.grades.length ? app.grades[0].name : '';

    const invite = async (person) => {
        if (await run('invite', { target: person.id }, L('ui_invite_sent'))) go('recruit');
    };

    return el('div', { class: 'stack' },
        heading(L('ui_tab_recruit'), el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn', onclick: () => go('recruit') }, icon('refresh', 16, 2), ` ${L('ui_refresh')}`)),
        el('small', { class: 'muted', text: L('ui_recruit_help', app.inviteDistance ?? 5, lowest) }),
        el('div', { class: 'list grow-none' }, people.length ? people.map((person) => el('div', { class: 'list-row static' },
            el('span', { class: 'avatar' }, initials(person.name)),
            el('span', { class: 'who grow' }, el('strong', { text: person.name })),
            person.invited
                ? el('span', { class: 'pill', text: L('ui_invited') })
                : el('button', { class: 'kit-btn accent', text: L('ui_invite'), onclick: () => invite(person) }),
        )) : el('div', { class: 'list-empty', text: L('ui_nobody_near') })),
    );
}
