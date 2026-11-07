// Shared helpers for the Messages page: talking to our resource, texts, names, building elements
const RESOURCE = 'city_phone_messages';
const dictionaries = {};
let language = 'en';

export const REACTIONS = { heart: '❤️', like: '👍', laugh: '😂', wow: '❗', question: '❓' };

export const state = {
    number: '',
    conversations: [],
    contacts: [],
    chat: null, // the open chat: { id, name, owner, group, members, messages }
    live: {}, // session -> latest position
};

export async function call(name, data = {}) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, { method: 'POST', body: JSON.stringify(data) });
        return await response.json();
    } catch {
        return { ok: false };
    }
}

export async function loadTexts() {
    for (const lang of ['en', 'pt-br']) {
        dictionaries[lang] = await fetch(`locales/${lang}.json`).then((r) => r.json()).catch(() => ({}));
    }
}

// Kept as asked even before the texts finish loading; t() falls back to English
export function setLanguage(lang) {
    language = lang === 'pt-br' ? 'pt-br' : 'en';
}

export function t(key, ...values) {
    const text = dictionaries[language]?.[key] ?? dictionaries.en?.[key] ?? key;
    let index = 0;
    return text.replace(/%s/g, () => String(values[index++] ?? ''));
}

export function formatNumber(number) {
    if (!number) return '';
    if (number.length === 10) return `(${number.slice(0, 3)}) ${number.slice(3, 6)}-${number.slice(6)}`;
    return number;
}

export function nameFor(number) {
    if (number === state.number) return t('you');
    return state.contacts.find((contact) => contact.number === number)?.name || formatNumber(number);
}

// A chat's title: the group's name, or the other person
export function titleOf(conversation) {
    if (conversation.is_group || conversation.group) return conversation.name || t('group');
    const members = conversation.members.map((member) => member.number || member);
    return nameFor(members.find((number) => number !== state.number) || state.number);
}

export function initials(name) {
    return (name || '?').split(/\s+/).map((part) => part[0] || '').join('').slice(0, 2).toUpperCase();
}

export function clock(at) {
    const date = new Date(at * 1000);
    return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

export function h(tag, className, text, ...children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null && text !== '') node.textContent = text;
    node.append(...children.flat(Infinity).filter(Boolean));
    return node;
}

export function button(className, text, onClick, ...children) {
    const node = h('button', className, text, ...children);
    node.addEventListener('click', onClick);
    return node;
}

export function input(className, placeholder, maxLength) {
    const node = h('input', className);
    Object.assign(node, { placeholder, maxLength });
    return node;
}

let toastTimer = null;

export function toast(text) {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.classList.add('toast--on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => node.classList.remove('toast--on'), 2200);
}

export function sheet(...children) {
    const node = document.getElementById('sheet');
    node.replaceChildren(...children.flat(Infinity).filter(Boolean));
    node.classList.add('sheet--open');
}

export function closeSheet() {
    document.getElementById('sheet').classList.remove('sheet--open');
}

// What a system message says ("Ana added Bruno")
export function systemText(body) {
    let data = {};
    try { data = JSON.parse(body); } catch { return ''; }

    return t(`system.${data.event}`, nameFor(data.by), data.who ? nameFor(data.who) : data.name || '');
}
