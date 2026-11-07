// Phone app helpers: talking to our resource, texts, and the kit's building blocks
import { formatNumber } from 'https://cfx-nui-city_phone/web/kit/kit.js';

export {
    h, button, iconButton, icon, input, avatar, toast, openSheet, closeSheet, navBar, backButton, applyContext, formatNumber,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_calls';
const dictionaries = {};
let language = 'en';

export const state = {
    tab: 'keypad',
    number: '',
    myNumber: '',
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

export function contactFor(number) {
    return number ? state.contacts.find((contact) => contact.number === number) : null;
}

export function nameFor(number) {
    if (!number) return t('unknown');
    return contactFor(number)?.name || formatNumber(number);
}

// Why a call couldn't go through
export function reasonText(reason) {
    return t(`reason.${reason || 'invalid'}`);
}
