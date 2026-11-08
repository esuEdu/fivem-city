// Weazel News helpers: talking to our resource, texts, and the kit's building blocks
export {
    h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_news';
const dictionaries = {};
let language = 'en';

export const CATEGORIES = ['city', 'police', 'economy', 'sports', 'entertainment', 'other'];

export const state = {
    category: null,
    articles: [],
    rights: { write: false, boss: false, staff: false },
    noMore: false,
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

export function ago(at) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000) - at);
    if (seconds < 60) return t('time.now');
    if (seconds < 3600) return t('time.minutes', Math.floor(seconds / 60));
    if (seconds < 86400) return t('time.hours', Math.floor(seconds / 3600));
    return t('time.days', Math.floor(seconds / 86400));
}
