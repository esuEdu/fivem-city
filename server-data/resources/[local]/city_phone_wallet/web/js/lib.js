// Wallet helpers: city_bank requests (through our client), texts and money
export {
    h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, applyContext, formatNumber,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const dictionaries = {};
let language = 'en';

export const state = { tab: 'home', accounts: [], cards: [], history: [], account: null, pending: null };

// city_bank:app:<name>(...args) through our client; always answers a table with ok
export async function bank(name, ...args) {
    try {
        const response = await fetch('https://city_phone_wallet/bank', { method: 'POST', body: JSON.stringify({ name, args }) });
        return (await response.json()) || { ok: false };
    } catch {
        return { ok: false };
    }
}

export async function local(name, data = {}) {
    try {
        const response = await fetch(`https://city_phone_wallet/${name}`, { method: 'POST', body: JSON.stringify(data) });
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
    const amount = Math.round(Number(value) || 0);
    return `${amount < 0 ? '-' : ''}$${Math.abs(amount).toLocaleString(language === 'pt-br' ? 'pt-BR' : 'en-US')}`;
}

// What a bank error code means to the player
export function errorText(code) {
    const key = `error.${code || 'failed'}`;
    const text = t(key);
    return text === key ? t('error.failed') : text;
}

// Shops and hospital fees come with a suffix (shop-24/7, hospital-bed): those are read by their prefix
const PREFIXES = ['shop', 'hospital'];

export function reasonText(reason) {
    const prefix = PREFIXES.find((name) => (reason || '').startsWith(`${name}-`));
    if (prefix) return t(`reason.${prefix}`);

    const key = `reason.${(reason || '').replace(/-/g, '_')}`;
    const text = t(key);
    return text === key ? t('reason.other') : text;
}

export function when(time) {
    const date = new Date(time * 1000);
    return date.toLocaleString(language === 'pt-br' ? 'pt-BR' : 'en-US', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
}
