// InstaPic helpers: talking to our resource, texts, images and avatars, and the kit's building blocks
import { avatar as initialsAvatar } from 'https://cfx-nui-city_phone/web/kit/kit.js';

export {
    h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_social';
const dictionaries = {};
let language = 'en';

export const state = {
    tab: 'home',
    me: null,
    staff: false,
    feed: [],
    explore: [],
    stories: [],
    profile: null,
    profilePosts: [],
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

function isImage(data) {
    return typeof data === 'string' && data.startsWith('data:image/');
}

// Images and avatars are loaded once and kept while the app is open
const images = new Map();
const avatars = new Map();

export function image(id) {
    if (!images.has(id)) images.set(id, call('image', { id }).then((r) => (r.ok && isImage(r.result) ? r.result : null)));
    return images.get(id);
}

export function forgetAvatar(username) {
    avatars.delete(username);
}

// An <img> that fills in when the image arrives
export function lazyImage(className, load) {
    const img = document.createElement('img');
    img.className = className;
    load().then((data) => {
        if (!isImage(data)) return;
        img.src = data;
        img.onload = () => img.classList.add('loaded');
    });
    return img;
}

// A round avatar: initials first, the profile photo over them once it arrives
export function avatar(username, name, size = '') {
    const node = initialsAvatar(name || username, `${size} avatar`);

    if (!avatars.has(username)) avatars.set(username, call('avatar', { username }).then((r) => (r.ok && isImage(r.result) ? r.result : null)));

    avatars.get(username).then((data) => {
        if (!data) return;
        const img = document.createElement('img');
        img.className = 'avatar__photo';
        img.src = data;
        node.append(img);
    });

    return node;
}

// Your own photos as a grid; calls onPick(id)
export function photoGrid(onPick) {
    const grid = document.createElement('div');
    grid.className = 'picker';
    grid.append(document.createTextNode(t('compose.loading')));

    call('myPhotos').then((result) => {
        const ids = result.ok && Array.isArray(result.result) ? result.result : [];
        grid.replaceChildren();

        if (ids.length === 0) {
            grid.append(document.createTextNode(t('compose.noPhotos')));
            return;
        }

        for (const id of ids) {
            const tile = document.createElement('button');
            tile.className = 'picker__tile';
            tile.append(lazyImage('picker__image', () => call('myPhoto', { id }).then((r) => (r.ok ? r.result : null))));
            tile.addEventListener('click', () => onPick(id));
            grid.append(tile);
        }
    });

    return grid;
}
