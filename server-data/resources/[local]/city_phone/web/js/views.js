// Open apps. Each one keeps its view (and its frame) alive while it is in the multitask list, so switching back is
// instant. Apps from other resources run in a frame and talk to the phone with postMessage.
import { allApps, findApp } from './home.js';
import { label } from './i18n.js';
import { openSettings } from './settings.js';
import { state, on, emit } from './state.js';
import { $, el, post } from './util.js';

const FONTS = { inter: 'Inter', poppins: 'Poppins', roboto: 'Roboto', nunito: 'Nunito' };

// id -> { app, view, frame }
const running = new Map();
let active = null;

export function runningApps() {
    return [...running.values()].map((entry) => entry.app).reverse();
}

export function activeApp() {
    return active;
}

function context() {
    return {
        type: 'city_phone:context',
        theme: state.settings.theme,
        language: state.settings.language,
        font: FONTS[state.settings.font] || 'Inter',
        profile: state.profile,
        // city_ui colors, so apps match the rest of the city
        colors: Object.fromEntries(['accent', 'accent-text', 'success', 'danger'].map((name) => [
            name, getComputedStyle(document.documentElement).getPropertyValue(`--${name}`).trim(),
        ])),
    };
}

function sendTo(entry, message) {
    entry.frame?.contentWindow?.postMessage(message, '*');
}

function create(app) {
    const view = el('div', 'view');
    const entry = { app, view, frame: null };

    if (app.builtin) {
        openSettings(view);
    } else {
        const frame = el('iframe');
        frame.src = app.page;
        frame.title = label(app);
        frame.addEventListener('load', () => sendTo(entry, context()));
        view.append(frame);
        entry.frame = frame;
    }

    $('views').append(view);
    return entry;
}

function setActive(id) {
    active = id;

    for (const [key, entry] of running) entry.view.classList.toggle('view--active', key === id);

    $('home').classList.toggle('home--behind', id !== null);
    $('phone').classList.toggle('phone--app', id !== null);
    emit('active', id);
}

export function launch(id) {
    const app = findApp(id);
    if (!app) return;

    let entry = running.get(id);

    if (!entry) {
        entry = create(app);
        post('appState', { app: id, open: true });
    } else {
        running.delete(id);
    }

    // Most recent last
    running.set(id, entry);
    requestAnimationFrame(() => setActive(id));
}

export function goHome() {
    setActive(null);
}

export function closeApp(id) {
    const entry = running.get(id);
    if (!entry) return;

    running.delete(id);
    entry.view.remove();
    if (!entry.app.builtin) post('appState', { app: id, open: false });
    if (active === id) setActive(null);
}

// Lua -> an app's page
export function messageApp(id, data) {
    const entry = running.get(id);
    if (entry) sendTo(entry, { type: 'city_phone:message', data });
}

// An app's page -> the phone. Only our own frames are listened to.
window.addEventListener('message', (event) => {
    const entry = [...running.values()].find((item) => item.frame && item.frame.contentWindow === event.source);
    if (!entry || !event.data) return;

    if (event.data.type === 'city_phone:home') goHome();
    if (event.data.type === 'city_phone:close') emit('requestClose');
});

export function initViews() {
    on('launch', launch);

    // A setting changed: every open app gets the new theme/language/font
    on('settings', () => {
        for (const entry of running.values()) sendTo(entry, context());
    });

    // An app removed (its resource stopped) closes it
    on('apps', () => {
        for (const id of [...running.keys()]) {
            if (!allApps().some((app) => app.id === id)) closeApp(id);
        }
    });
}
