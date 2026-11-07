// The chat list, starting a chat with someone, and making a group
import {
    state, call, t, h, button, icon, input, avatar, toast, openSheet, closeSheet, navBar, titleOf, clock, formatNumber,
} from './lib.js';

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
    return button('k-item', null, onClick,
        avatar(contact.name, 'small'),
        h('span', 'k-item__main', null, h('span', 'k-item__title', contact.name), h('span', 'k-item__subtitle', formatNumber(contact.number))),
        right,
    );
}

function compose() {
    const number = input('', t('compose.number'), 15);
    number.addEventListener('keydown', (event) => { if (event.key === 'Enter') startWith(number.value.replace(/\D/g, '')); });

    openSheet(
        navBar(button('k-link', t('cancel'), closeSheet), t('compose.title'), button('k-link', t('compose.start'), () => startWith(number.value.replace(/\D/g, '')))),
        h('label', 'k-search', null, h('span', 'to', t('compose.to')), number),
        h('div', 'k-list', null, state.contacts.map((contact) => contactRow(contact, () => startWith(contact.number)))),
    );
}

function newGroup() {
    const name = input('k-field', t('group.name'), 30);
    const extra = input('k-field', t('compose.number'), 15);
    const picked = new Set();

    const rows = state.contacts.map((contact) => {
        const mark = h('span', 'k-check', null, icon('check'));
        return contactRow(contact, () => {
            if (picked.has(contact.number)) picked.delete(contact.number); else picked.add(contact.number);
            mark.classList.toggle('k-check--on', picked.has(contact.number));
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

    openSheet(
        navBar(button('k-link', t('cancel'), closeSheet), t('group.new'), button('k-link', t('group.create'), create)),
        h('div', 'k-group', null, name, extra),
        h('div', 'k-group__label', t('group.people')),
        h('div', 'k-list', null, rows),
    );
}

export function renderList() {
    const rows = state.conversations.map((conversation) => {
        const title = titleOf(conversation);
        const unread = Number(conversation.unread) || 0;

        return button(`k-item chat-row${unread ? ' chat-row--unread' : ''}`, null, () => openChat(conversation.id),
            conversation.is_group ? avatar(title, '', 'group') : avatar(title),
            h('span', 'k-item__main', null, h('span', 'k-item__title', title), h('span', 'k-item__subtitle chat-row__preview', preview(conversation))),
            h('span', 'k-item__side', null, h('span', '', clock(conversation.last_at)), unread ? h('span', 'k-count', String(unread)) : null),
        );
    });

    document.getElementById('content').replaceChildren(
        navBar(button('k-link', t('group.new'), newGroup), null, button('k-link', null, compose, icon('compose'))),
        h('h1', 'k-large-title', t('title')),
        rows.length ? h('div', 'k-list', null, rows) : h('div', 'k-empty', null, icon('message'), h('span', '', t('empty'))),
    );
}
