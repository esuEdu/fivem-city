// Music helpers: talking to our resource, texts, track pictures, and the kit's building blocks
import { ICONS } from 'https://cfx-nui-city_phone/web/kit/kit.js';

// Player icons the kit doesn't have (same drawing style as the kit's)
const line = (body) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">${body}</svg>`;
const solid = (body) => `<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">${body}</svg>`;

Object.assign(ICONS, {
    play: solid('<path d="M7 4.5v15a1 1 0 0 0 1.5.9l12-7.5a1 1 0 0 0 0-1.8l-12-7.5A1 1 0 0 0 7 4.5z"/>'),
    pause: solid('<rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/>'),
    next: solid('<path d="M4 5.5v13a1 1 0 0 0 1.5.8L15 12.8V18a1 1 0 0 0 2 0V6a1 1 0 0 0-2 0v5.2L5.5 4.7A1 1 0 0 0 4 5.5z"/>'),
    previous: solid('<path d="M20 5.5v13a1 1 0 0 1-1.5.8L9 12.8V18a1 1 0 0 1-2 0V6a1 1 0 0 1 2 0v5.2l9.5-6.5a1 1 0 0 1 1.5.8z"/>'),
    shuffle: line('<path d="M16 3h5v5M4 20 21 3M21 16v5h-5M15 15l6 6M4 4l5 5"/>'),
    repeat: line('<path d="M17 2l4 4-4 4"/><path d="M3 11V9a3 3 0 0 1 3-3h15"/><path d="M7 22l-4-4 4-4"/><path d="M21 13v2a3 3 0 0 1-3 3H3"/>'),
    repeatOne: line('<path d="M17 2l4 4-4 4"/><path d="M3 11V9a3 3 0 0 1 3-3h15"/><path d="M7 22l-4-4 4-4"/><path d="M21 13v2a3 3 0 0 1-3 3H3"/><path d="M11 10h1v5"/>'),
    volume: line('<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/>'),
    volumeLow: line('<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16.5 8.5a5 5 0 0 1 0 7"/>'),
});

export {
    h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_music';
const dictionaries = {};
let language = 'en';

export const state = {
    tab: 'search',
    tracks: [],
    playlists: [],
    canSearch: false,
    query: '',
    results: [],
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

export function reasonText(reason) {
    return t(`error.${reason || 'invalid'}`);
}

// A YouTube track's picture; audio links get a note icon
export function cover(track, className = 'cover') {
    const box = document.createElement('span');
    box.className = className;

    if (track.kind === 'youtube' && /^[\w-]{11}$/.test(track.ref)) {
        const img = document.createElement('img');
        img.src = `https://i.ytimg.com/vi/${track.ref}/mqdefault.jpg`;
        img.alt = '';
        box.append(img);
    } else {
        box.classList.add('cover--note');
        box.textContent = '♪';
    }

    return box;
}

export function clock(seconds) {
    if (!Number.isFinite(seconds) || seconds < 0) return '0:00';
    const minutes = Math.floor(seconds / 60);
    return `${minutes}:${String(Math.floor(seconds % 60)).padStart(2, '0')}`;
}

export function sameTrack(a, b) {
    return a && b && a.kind === b.kind && a.ref === b.ref;
}
