import { format, post, SETTINGS_APP } from './util.js';

// Everything the tablet page knows, filled by the 'open' message from client/main.lua
export const state = {
    tablet: null,
    settings: null,
    apps: [],
    badges: {},
    notes: [],
    labels: {},
    theme: {},
    wallpapers: [],
    deviceColors: [],
    customWallpaper: false,
    config: {},
    clock: { hours: 0, minutes: 0 },
    screen: 'locked', // locked | passcode | home | app | settings
    app: null, // id of the open app
    notesOpen: false,
};

const renderers = [];
let saveTimer;

export function L(key, ...values) {
    return format(state.labels[key] ?? key, ...values);
}

export function onRender(fn) {
    renderers.push(fn);
}

export function render() {
    for (const fn of renderers) fn();
}

export function go(screen, app = null) {
    state.screen = screen;
    state.app = app;
    state.notesOpen = false;
    render();
}

// Registered apps plus the tablet's own Settings, in home screen order
export function allApps() {
    return [...state.apps, SETTINGS_APP];
}

export function findApp(id) {
    return allApps().find((app) => app.id === id);
}

export function dockApps() {
    const apps = allApps();
    const chosen = (state.settings.dock || []).map((id) => apps.find((app) => app.id === id)).filter(Boolean);
    if (chosen.length) return chosen;

    // Until the player picks: the first apps (never hidden ones, which a search would see), then Settings
    return [...state.apps.filter((app) => !app.hidden).slice(0, state.config.dockSize - 1), SETTINGS_APP];
}

export function wallpaperCss() {
    const id = state.settings.wallpaper;

    if (id === 'custom' && state.customWallpaper) {
        return `url("${state.customWallpaper}") center / cover no-repeat, #0b0c10`;
    }

    const wallpaper = state.wallpapers.find((w) => w.id === id) || state.wallpapers[0];
    return wallpaper ? wallpaper.css : '#0b0c10';
}

export function applySettings() {
    const screen = document.getElementById('screen');
    const s = state.settings;

    screen.classList.toggle('light', s.appearance === 'light');
    screen.classList.toggle('dark', s.appearance !== 'light');
    screen.classList.toggle('text-small', s.textSize === 'small');
    screen.classList.toggle('text-large', s.textSize === 'large');
    screen.classList.toggle('bold', s.bold);
    screen.classList.toggle('no-motion', !s.motion);
    screen.style.background = wallpaperCss();

    const color = deviceColor();
    const tablet = document.getElementById('tablet').style;
    if (!color) return;
    tablet.setProperty('--frame-a', color.frame[0]);
    tablet.setProperty('--frame-b', color.frame[1]);
    tablet.setProperty('--frame-c', color.frame[2]);
    tablet.setProperty('--frame-edge', color.edge);
}

export function deviceColor() {
    return state.deviceColors.find((c) => c.id === state.settings.deviceColor) || state.deviceColors[0];
}

// Changes settings right away and saves them a moment later (one save for several quick changes)
export function changeSettings(patch) {
    Object.assign(state.settings, patch);
    applySettings();
    render();

    clearTimeout(saveTimer);
    saveTimer = setTimeout(async () => {
        const result = await post('saveSettings', { settings: state.settings });
        if (result && result.ok && result.settings) state.settings = result.settings;
    }, 600);
}

export function timeText() {
    const { hours, minutes } = state.clock;
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

export function dateText(long) {
    return new Date().toLocaleDateString('en-GB', long
        ? { weekday: 'long', day: 'numeric', month: 'long' }
        : { weekday: 'short', day: 'numeric', month: 'short' });
}
