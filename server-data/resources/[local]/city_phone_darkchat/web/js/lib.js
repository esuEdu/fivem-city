// DarkChat helpers: talking to our resource, texts, and the kit's building blocks
export {
    h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_darkchat';
const dictionaries = {};
let language = 'en';

export const state = {
    alias: null,
    rooms: [],
    room: null,
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

export function setLanguage(lang) {
    language = lang === 'pt-br' ? 'pt-br' : 'en';
}

export function t(key, ...values) {
    const text = dictionaries[language]?.[key] ?? dictionaries.en?.[key] ?? key;
    let index = 0;
    return text.replace(/%s/g, () => String(values[index++] ?? ''));
}

export function time(at) {
    return new Date(at * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}
