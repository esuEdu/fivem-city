// Market helpers: talking to our resource, texts, prices and the kit's building blocks
export {
    h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, applyContext, formatNumber,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_market';
const dictionaries = {};
let language = 'en';

export const CATEGORIES = ['vehicles', 'property', 'services', 'items', 'jobs', 'other'];

export const state = {
    tab: 'browse',
    category: null,
    search: '',
    ads: [],
    noMore: false,
    staff: false,
    fee: 0,
    days: 7,
    mine: [],
    max: 0,
    favorites: [],
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

export function money(value) {
    return value === 0 ? t('free') : `$${Number(value).toLocaleString('en-US')}`;
}

export function ago(at) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000) - at);
    if (seconds < 3600) return t('time.minutes', Math.max(1, Math.floor(seconds / 60)));
    if (seconds < 86400) return t('time.hours', Math.floor(seconds / 3600));
    return t('time.days', Math.floor(seconds / 86400));
}

export function daysLeft(expiresAt) {
    const seconds = expiresAt - Math.floor(Date.now() / 1000);
    if (seconds <= 0) return t('ad.expired');
    return t('ad.daysLeft', Math.max(1, Math.ceil(seconds / 86400)));
}

// Ad photos are loaded once and kept while the app is open
const photos = new Map();

export function photo(id) {
    if (!photos.has(id)) {
        photos.set(id, call('photo', { id }).then((result) => (result.ok ? result.result : null)));
    }
    return photos.get(id);
}

export function forgetPhoto(id) {
    photos.delete(id);
}

// An <img> that fills in when the image arrives
export function lazyImage(className, load) {
    const img = document.createElement('img');
    img.className = className;
    load().then((data) => {
        if (typeof data !== 'string' || !data.startsWith('data:image/')) return;
        img.src = data;
        img.onload = () => img.classList.add('loaded');
    });
    return img;
}
