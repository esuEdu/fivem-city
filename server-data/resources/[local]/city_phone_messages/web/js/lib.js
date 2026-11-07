// Messages helpers: talking to our resource, texts, names, and the kit's building blocks
import { formatNumber } from 'https://cfx-nui-city_phone/web/kit/kit.js';

export {
    h, button, iconButton, icon, input, avatar, toast, openSheet, closeSheet, navBar, backButton, applyContext, formatNumber,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

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

export function clock(at) {
    const date = new Date(at * 1000);
    return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

// What a system message says ("Ana added Bruno")
export function systemText(body) {
    let data = {};
    try { data = JSON.parse(body); } catch { return ''; }

    return t(`system.${data.event}`, nameFor(data.by), data.who ? nameFor(data.who) : data.name || '');
}
