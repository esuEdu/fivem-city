// A group's info: rename and manage people (only whoever owns the group), or leave it
import {
    state, call, t, h, button, input, avatar, toast, openSheet, closeSheet, navBar, nameFor, formatNumber,
} from './lib.js';

let afterLeave = () => {};

export function setAfterLeave(fn) {
    afterLeave = fn;
}

export function openGroupInfo() {
    const chat = state.chat;
    const owner = chat.owner === state.number;

    const name = input('grow', t('group.name'), 30);
    name.value = chat.name || '';

    const add = input('grow', t('compose.number'), 15);

    const members = chat.members.map((member) => h('div', 'k-item', null,
        avatar(nameFor(member.number), 'small'),
        h('span', 'k-item__main', null,
            h('span', 'k-item__title', nameFor(member.number)),
            h('span', 'k-item__subtitle', member.number === chat.owner ? t('group.owner') : formatNumber(member.number)),
        ),
        owner && member.number !== state.number ? button('k-link k-link--danger', t('group.remove'), async () => {
            if ((await call('removeMember', { id: chat.id, number: member.number })).ok) closeSheet();
        }) : null,
    ));

    openSheet(
        navBar(null, chat.name || t('group'), button('k-link', t('done'), closeSheet)),
        h('div', 'card', null, avatar(chat.name || t('group'), 'big', 'group')),
        owner ? h('div', 'k-group', null,
            h('div', 'k-row', null, name, button('k-link', t('group.rename'), async () => {
                if ((await call('rename', { id: chat.id, name: name.value })).ok) closeSheet();
                else toast(t('error.invalid'));
            })),
            chat.members.length < 10 ? h('div', 'k-row', null, add, button('k-link', t('group.add'), async () => {
                const result = await call('addMember', { id: chat.id, number: add.value.replace(/\D/g, '') });
                if (result.ok) closeSheet();
                else toast(t(`error.${result.reason || 'invalid'}`));
            })) : null,
        ) : null,
        h('div', 'k-group__label', t('group.people')),
        h('div', 'k-list', null, members),
        h('div', 'k-group leave', null, button('k-row k-row--danger', t('group.leave'), async () => {
            if ((await call('leave', { id: chat.id })).ok) {
                closeSheet();
                afterLeave();
            }
        })),
    );
}
