import { ICONS } from './icons.js';

export const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_phone';

export function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    })
        .then((response) => response.json())
        .catch(() => null);
}

// Text always goes in with textContent; only our own constant icons are parsed as markup
export function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

export function icon(name) {
    const template = document.createElement('template');
    template.innerHTML = ICONS[name] || ICONS.app;
    return template.content.firstElementChild;
}

// An app icon tile: the app's own picture, or one of ours on its color
export function appIcon(app) {
    const tile = el('span', 'icon');
    tile.style.background = app.color || '#8e8e93';

    if (app.icon) {
        const image = el('img');
        image.src = app.icon;
        image.alt = '';
        tile.append(image);
    } else {
        tile.append(icon(app.builtinIcon || 'app'));
    }

    return tile;
}

// city_ui's theme.lua: { accentText = '#15181d' } -> --accent-text
export function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

export const $ = (id) => document.getElementById(id);
