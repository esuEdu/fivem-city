// Shared helpers for the Phone app page: talking to our resource, texts, formatting, building elements
const RESOURCE = 'city_phone_calls';
const dictionaries = {};
let language = 'en';

export const state = {
    tab: 'keypad',
    number: '',
    contacts: [],
    recents: [],
    blocked: [],
    call: null,
    hidden: false,
};

// Our resource's callbacks always answer { ok, result, reason }
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

// 5551234567 -> (555) 123-4567
export function formatNumber(number) {
    if (!number) return t('unknown');
    if (number.length === 10) return `(${number.slice(0, 3)}) ${number.slice(3, 6)}-${number.slice(6)}`;
    return number;
}

export function contactFor(number) {
    return number ? state.contacts.find((contact) => contact.number === number) : null;
}

export function nameFor(number) {
    return contactFor(number)?.name || formatNumber(number);
}

export function initials(name) {
    return (name || '?').split(/\s+/).map((part) => part[0] || '').join('').slice(0, 2).toUpperCase();
}

// h('div', 'class', 'text', child, ...) - text always through textContent
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

let toastTimer = null;

export function toast(text) {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.classList.add('toast--on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => node.classList.remove('toast--on'), 2200);
}

// Why a call couldn't go through
export function reasonText(reason) {
    return t(`reason.${reason || 'invalid'}`);
}
