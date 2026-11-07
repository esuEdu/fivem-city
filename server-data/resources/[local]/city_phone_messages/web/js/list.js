// The chat list, starting a chat with someone, and making a group
import { state, call, t, h, button, input, toast, sheet, closeSheet, titleOf, initials, clock, formatNumber } from './lib.js';

let openChat = () => {};
let refresh = () => {};

export function setHandlers(open, reload) {
    openChat = open;
    refresh = reload;
}

function preview(conversation) {
    if (conversation.last_kind === 'location') return t('preview.location');
    if (conversation.last_kind === 'live') return t('preview.live');
    if (conversation.last_kind === 'system') return t('preview.system');
    return conversation.last_body || '';
}

function errorText(reason) {
    return t(`error.${reason || 'invalid'}`);
}

export async function startWith(number) {
    const result = await call('startDirect', { number });
    if (!result.ok) return toast(errorText(result.reason));

    closeSheet();
    await refresh();
    openChat(result.result);
}

function contactRow(contact, onClick, right) {
    return button('item', null, onClick,
        h('span', 'avatar', initials(contact.name)),
        h('span', 'item__main', null, h('strong', '', contact.name), h('small', '', formatNumber(contact.number))),
        right,
    );
}

function compose() {
    const number = input('search', t('compose.number'), 15);

    sheet(
        h('div', 'head', null, button('link', t('cancel'), closeSheet), button('link', t('compose.start'), () => startWith(number.value.replace(/\D/g, '')))),
        h('h1', 'title', t('compose.title')),
        number,
        h('div', 'list', null, state.contacts.map((contact) => contactRow(contact, () => startWith(contact.number)))),
    );
}

function newGroup() {
    const name = input('search', t('group.name'), 30);
    const extra = input('search', t('compose.number'), 15);
    const picked = new Set();

    const rows = state.contacts.map((contact) => {
        const mark = h('span', 'check', '');
        return contactRow(contact, () => {
            if (picked.has(contact.number)) picked.delete(contact.number); else picked.add(contact.number);
            mark.textContent = picked.has(contact.number) ? '✓' : '';
        }, mark);
    });

    const create = async () => {
        const numbers = [...picked];
        if (extra.value.trim()) numbers.push(extra.value.replace(/\D/g, ''));

        const result = await call('createGroup', { name: name.value, numbers });
        if (!result.ok) return toast(errorText(result.reason));

        closeSheet();
        await refresh();
        openChat(result.result);
    };

    sheet(
        h('div', 'head', null, button('link', t('cancel'), closeSheet), button('link', t('group.create'), create)),
        h('h1', 'title', t('group.new')),
        name,
        extra,
        h('div', 'list', null, rows),
    );
}

export function renderList() {
    const rows = state.conversations.map((conversation) => {
        const title = titleOf(conversation);
        const unread = Number(conversation.unread) || 0;

        return button(`item${unread ? ' item--unread' : ''}`, null, () => openChat(conversation.id),
            h('span', `avatar${conversation.is_group ? ' avatar--group' : ''}`, conversation.is_group ? '\u{1F465}' : initials(title)),
            h('span', 'item__main', null, h('strong', '', title), h('small', '', preview(conversation))),
            h('span', 'item__side', null, h('span', '', clock(conversation.last_at)), unread ? h('span', 'dot', String(unread)) : null),
        );
    });

    document.getElementById('content').replaceChildren(
        h('div', 'head', null, button('link', t('group.new'), newGroup), button('link link--big', '✎', compose)),
        h('h1', 'title', t('title')),
        rows.length ? h('div', 'list', null, rows) : h('p', 'empty', t('empty')),
    );
}
