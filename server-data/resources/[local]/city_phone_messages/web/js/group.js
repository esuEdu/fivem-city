// A group's info: rename and manage people (only whoever owns the group), or leave it
import { state, call, t, h, button, input, toast, sheet, closeSheet, nameFor, formatNumber, initials } from './lib.js';

let afterLeave = () => {};

export function setAfterLeave(fn) {
    afterLeave = fn;
}

export function openGroupInfo() {
    const chat = state.chat;
    const owner = chat.owner === state.number;

    const name = input('search', t('group.name'), 30);
    name.value = chat.name || '';

    const add = input('search', t('compose.number'), 15);

    const members = chat.members.map((member) => h('div', 'item', null,
        h('span', 'avatar', initials(nameFor(member.number))),
        h('span', 'item__main', null, h('strong', '', nameFor(member.number)), h('small', '', member.number === chat.owner ? t('group.owner') : formatNumber(member.number))),
        owner && member.number !== state.number ? button('link link--danger', t('group.remove'), async () => {
            if ((await call('removeMember', { id: chat.id, number: member.number })).ok) closeSheet();
        }) : null,
    ));

    sheet(
        h('div', 'head', null, button('link', t('done'), closeSheet), h('span')),
        h('h1', 'title', chat.name || t('group')),
        owner ? h('div', 'field-row', null, name, button('link', t('group.rename'), async () => {
            if ((await call('rename', { id: chat.id, name: name.value })).ok) closeSheet();
            else toast(t('error.invalid'));
        })) : null,
        owner && chat.members.length < 10 ? h('div', 'field-row', null, add, button('link', t('group.add'), async () => {
            const result = await call('addMember', { id: chat.id, number: add.value.replace(/\D/g, '') });
            if (result.ok) closeSheet();
            else toast(t(`error.${result.reason || 'invalid'}`));
        })) : null,
        h('div', 'list', null, members),
        button('row-danger', t('group.leave'), async () => {
            if ((await call('leave', { id: chat.id })).ok) {
                closeSheet();
                afterLeave();
            }
        }),
    );
}
