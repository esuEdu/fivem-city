// The Messages page. Runs inside city_phone: the phone sends the context, our client sends new messages, reads,
// reactions and live positions; everything else comes from our resource's callbacks.
import { openChatById, closeChat, renderChat, setBack } from './chat.js';
import { setAfterLeave } from './group.js';
import { state, call, loadTexts, setLanguage } from './lib.js';
import { renderList, setHandlers, startWith } from './list.js';

async function refresh() {
    const [list, contacts] = await Promise.all([call('list'), call('contacts')]);
    if (list.ok) {
        state.number = list.result.number;
        state.conversations = list.result.conversations || [];
    }
    if (contacts.ok) state.contacts = contacts.result || [];

    renderList();
}

async function backToList() {
    closeChat();
    await refresh();
}

function applyContext(context) {
    const root = document.documentElement;
    root.dataset.theme = context.theme === 'light' ? 'light' : 'dark';
    root.style.setProperty('--font', context.font || 'Inter');

    for (const [name, value] of Object.entries(context.colors || {})) {
        if (value) root.style.setProperty(`--${name}`, value);
    }

    setLanguage(context.language);
    renderList();
    renderChat(false);
}

const handlers = {
    message: ({ message }) => {
        if (state.chat && state.chat.id === message.conversation) {
            state.chat.messages.push(message);
            // A group change (someone added or removed): reload the members
            if (message.kind === 'system') openChatById(state.chat.id);
            else renderChat();
        } else {
            refresh();
        }
    },
    read: ({ conversation, number, upTo }) => {
        const member = state.chat?.id === conversation && state.chat.members.find((item) => item.number === number);
        if (!member) return;
        member.last_read = Math.max(member.last_read, upTo);
        member.last_delivered = Math.max(member.last_delivered, upTo);
        renderChat(false);
    },
    reaction: ({ conversation, message, number, reaction }) => {
        const target = state.chat?.id === conversation && state.chat.messages.find((item) => item.id === message);
        if (!target) return;
        target.reactions = target.reactions || {};
        if (reaction) target.reactions[number] = reaction; else delete target.reactions[number];
        renderChat(false);
    },
    live: ({ session, data }) => {
        if (data) state.live[session] = data; else delete state.live[session];
        if (state.chat) renderChat(false);
    },
    left: ({ conversation }) => {
        if (state.chat?.id === conversation) backToList();
        else refresh();
    },
    openWith: ({ number }) => startWith(number),
};

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') applyContext(message);

    if (message.type === 'city_phone:message') {
        const handler = handlers[message.data?.action];
        if (handler) handler(message.data);
    }
});

async function start() {
    await loadTexts();
    setHandlers(openChatById, refresh);
    setBack(backToList);
    setAfterLeave(backToList);
    await refresh();
}

start();
