// One chat: the messages (bubbles, locations, live locations, system lines), reactions, delivered/read, and the bar
// to write, send a location or start sharing the live location
import { openGroupInfo } from './group.js';
import { state, call, t, h, button, toast, nameFor, titleOf, clock, systemText, REACTIONS, closeSheet } from './lib.js';

let back = () => {};

export function setBack(fn) {
    back = fn;
}

function parse(body) {
    try { return JSON.parse(body); } catch { return {}; }
}

function waypoint(x, y) {
    call('waypoint', { x, y });
    toast(t('map.set'));
}

// Hold a bubble to react
function reactions(message, bubble) {
    let timer = null;

    const pick = () => {
        const mine = message.reactions?.[state.number];
        const bar = h('div', 'picker', null, Object.entries(REACTIONS).map(([name, emoji]) => button(`picker__item${mine === name ? ' picker__item--on' : ''}`, emoji, async (event) => {
            event.stopPropagation();
            bar.remove();
            await call('react', { message: message.id, reaction: mine === name ? null : name });
        })));
        bubble.append(bar);
        setTimeout(() => document.addEventListener('click', () => bar.remove(), { once: true }), 0);
    };

    bubble.addEventListener('pointerdown', () => { timer = setTimeout(pick, 400); });
    bubble.addEventListener('pointerup', () => clearTimeout(timer));
    bubble.addEventListener('pointerleave', () => clearTimeout(timer));
    bubble.addEventListener('contextmenu', (event) => { event.preventDefault(); pick(); });
}

function reactionBadge(message) {
    const list = Object.values(message.reactions || {});
    if (list.length === 0) return null;

    const counts = {};
    for (const name of list) counts[name] = (counts[name] || 0) + 1;

    return h('div', 'reactions', Object.entries(counts).map(([name, n]) => `${REACTIONS[name] || ''}${n > 1 ? n : ''}`).join(' '));
}

function content(message, mine) {
    if (message.kind === 'location') {
        const at = parse(message.body);
        return [h('div', 'bubble__title', `\u{1F4CD} ${t('location')}`), button('bubble__link', t('map.show'), () => waypoint(at.x, at.y))];
    }

    if (message.kind === 'live') {
        const data = parse(message.body);
        const running = data.ends > Date.now() / 1000;
        const latest = state.live[data.session];

        return [
            h('div', 'bubble__title', `\u{1F4E1} ${t('live.title')}`),
            h('div', 'bubble__small', running ? t('live.until', clock(data.ends)) : t('live.ended')),
            running && mine ? button('bubble__link', t('live.stop'), () => call('stopLive', { session: data.session })) : null,
            running && !mine && latest ? button('bubble__link', t('map.show'), () => waypoint(latest.x, latest.y)) : null,
        ];
    }

    return [h('span', '', message.body)];
}

function bubble(message, previous) {
    if (message.kind === 'system') return h('div', 'system', systemText(message.body));

    const mine = message.sender === state.number;
    const node = h('div', `bubble bubble--${mine ? 'mine' : 'theirs'}`, null, content(message, mine));

    reactions(message, node);

    const showName = state.chat.group && !mine && previous?.sender !== message.sender;

    return h('div', `row row--${mine ? 'mine' : 'theirs'}`, null,
        showName ? h('div', 'sender', nameFor(message.sender)) : null,
        node,
        reactionBadge(message),
    );
}

// "Delivered" / "Read" under your last message, only in a chat between two people
function receipt() {
    const chat = state.chat;
    if (chat.group) return null;

    const last = [...chat.messages].reverse().find((message) => message.kind !== 'system');
    if (!last || last.sender !== state.number) return null;

    const other = chat.members.find((member) => member.number !== state.number);
    if (!other) return null;

    if (other.last_read >= last.id) return h('div', 'receipt', t('read'));
    if (other.last_delivered >= last.id) return h('div', 'receipt', t('delivered'));
    return null;
}

function markRead() {
    const last = state.chat.messages.at(-1);
    if (last) call('read', { id: state.chat.id, upTo: last.id });
}

async function older(list) {
    const first = state.chat.messages[0];
    if (!first || state.chat.loadingOlder || state.chat.noMore) return;

    state.chat.loadingOlder = true;
    const result = await call('open', { id: state.chat.id, before: first.id });
    state.chat.loadingOlder = false;

    if (!result.ok || result.result.messages.length === 0) {
        state.chat.noMore = true;
        return;
    }

    const height = list.scrollHeight;
    state.chat.messages = [...result.result.messages.reverse(), ...state.chat.messages];
    renderChat(false);
    list.scrollTop = list.scrollHeight - height;
}

function attachMenu() {
    const menu = document.getElementById('attach');
    menu.replaceChildren(
        button('attach__item', `\u{1F4CD} ${t('attach.location')}`, async () => {
            menu.classList.remove('attach--open');
            if (!(await call('sendLocation', { id: state.chat.id })).ok) toast(t('error.invalid'));
        }),
        button('attach__item', `\u{1F4E1} ${t('attach.live')}`, async () => {
            menu.classList.remove('attach--open');
            if (!(await call('startLive', { id: state.chat.id })).ok) toast(t('error.invalid'));
        }),
    );
    menu.classList.toggle('attach--open');
}

export function renderChat(scroll = true) {
    const chat = state.chat;
    if (!chat) return;

    const list = h('div', 'messages', null, chat.messages.map((message, index) => bubble(message, chat.messages[index - 1])), receipt());
    list.addEventListener('scroll', () => { if (list.scrollTop < 40) older(list); });

    // The draft and the focus survive a redraw (a message arriving while typing)
    const old = document.querySelector('.composer__input');
    const hadFocus = old && document.activeElement === old;

    const field = h('input', 'composer__input');
    Object.assign(field, { placeholder: t('placeholder'), maxLength: 500, value: chat.draft || '' });
    field.addEventListener('input', () => { chat.draft = field.value; });

    const send = async () => {
        const text = field.value.trim();
        if (!text) return;
        field.value = '';
        chat.draft = '';
        if (!(await call('send', { id: chat.id, text })).ok) toast(t('error.invalid'));
    };
    field.addEventListener('keydown', (event) => { if (event.key === 'Enter') send(); });

    const attach = h('div', 'attach');
    attach.id = 'attach';

    const view = document.getElementById('chat');
    view.replaceChildren(
        h('div', 'chat__head', null,
            button('link', `‹ ${t('title')}`, () => { closeSheet(); back(); }),
            h('strong', 'chat__title', titleOf(chat)),
            chat.group ? button('link', 'i', () => openGroupInfo()) : h('span'),
        ),
        list,
        h('div', 'composer', null,
            button('composer__plus', '+', attachMenu),
            field,
            button('composer__send', '↑', send),
        ),
        attach,
    );
    view.classList.add('chat--open');

    if (hadFocus) field.focus();
    if (scroll) list.scrollTop = list.scrollHeight;
    markRead();
}

export async function openChatById(id) {
    const result = await call('open', { id });
    if (!result.ok) return;

    state.chat = { ...result.result, messages: result.result.messages.reverse() };
    call('viewing', { id });
    renderChat();
}

export function closeChat() {
    state.chat = null;
    call('viewing', { id: null });
    document.getElementById('chat').classList.remove('chat--open');
}
