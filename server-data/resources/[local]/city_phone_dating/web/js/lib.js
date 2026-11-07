// Matchy helpers: talking to our resource, texts, photos, and the kit's building blocks
export {
    h, button, iconButton, icon, input, avatar, toast, openSheet, closeSheet, navBar, backButton, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_dating';
const dictionaries = {};
let language = 'en';

export const state = {
    tab: 'discover',
    me: null,
    deck: [],
    matches: [],
    chat: null,
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

function isImage(data) {
    return typeof data === 'string' && data.startsWith('data:image/');
}

// Profile photos are loaded once and kept while the app is open
const photos = new Map();

export function photo(profileId, slot) {
    const key = `${profileId}:${slot}`;
    if (!photos.has(key)) photos.set(key, call('photo', { profileId, slot }).then((r) => (r.ok && isImage(r.result) ? r.result : null)));
    return photos.get(key);
}

export function forgetPhotos(profileId) {
    for (const key of [...photos.keys()]) if (key.startsWith(`${profileId}:`)) photos.delete(key);
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

export function nameAge(name, age) {
    return age ? `${name}, ${age}` : name;
}

// Your own photos as a grid; calls onPick(id)
export function photoGrid(onPick) {
    const grid = document.createElement('div');
    grid.className = 'picker';
    grid.append(document.createTextNode(t('profile.loading')));

    call('myPhotos').then((result) => {
        const ids = result.ok && Array.isArray(result.result) ? result.result : [];
        grid.replaceChildren();

        if (ids.length === 0) {
            grid.append(document.createTextNode(t('profile.noPhotos')));
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
