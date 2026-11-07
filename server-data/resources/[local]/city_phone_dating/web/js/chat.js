// A match's private chat, and unmatching
import { state, call, t, h, button, iconButton, icon, toast, openSheet, closeSheet, navBar, backButton, lazyImage, photo, nameAge } from './lib.js';

let refresh = async () => {};

export function setRefresh(fn) {
    refresh = fn;
}

function time(at) {
    const date = new Date(at * 1000);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export async function loadChat() {
    const chat = state.chat;
    if (!chat) return;

    const result = await call('messages', { id: chat.match.id });
    if (!result.ok) {
        state.chat = null;
        closeSheet();
        return refresh();
    }

    const rows = Array.isArray(result.result) ? result.result.reverse() : [];

    chat.list.replaceChildren(...(rows.length
        ? rows.map((message) => h('div', `bubble${message.mine ? ' bubble--mine' : ''}`, null,
            h('span', 'bubble__text', message.text),
            h('span', 'bubble__time', time(message.createdAt)),
        ))
        : [h('div', 'k-empty', null, icon('heart'), h('span', '', t('chat.empty', chat.match.name)))]));

    chat.list.scrollTop = chat.list.scrollHeight;
}

export function openChat(match) {
    const list = h('div', 'messages');
    const field = h('input', 'composer__input');
    Object.assign(field, { placeholder: t('chat.placeholder'), maxLength: 500 });

    state.chat = { match, list };

    const send = async () => {
        const text = field.value.trim();
        if (!text) return;

        const result = await call('send', { id: match.id, text });
        if (!result.ok) return toast(t(result.reason === 'slow' ? 'error.slow' : 'error.invalid'));

        field.value = '';
        loadChat();
    };

    field.addEventListener('keydown', (event) => { if (event.key === 'Enter') send(); });

    const unmatch = button('k-link k-link--danger', t('chat.unmatch'), async () => {
        if (!(await call('unmatch', { id: match.id })).ok) return toast(t('error.invalid'));
        state.chat = null;
        closeSheet();
        toast(t('chat.unmatched'));
        await refresh();
    });

    openSheet(
        navBar(backButton(t('back'), async () => { state.chat = null; closeSheet(); await refresh(); }),
            h('span', 'chat__title', null, lazyImage('chat__avatar', () => photo(match.profileId, 1)), h('span', '', nameAge(match.name, match.age))),
            unmatch),
        list,
        h('div', 'composer', null, field, iconButton('composer__send', 'send', send)),
    );

    loadChat();
}
