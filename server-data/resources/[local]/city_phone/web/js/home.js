// The home screen: every app in a grid, the dock apps at the bottom. Settings is built in; the rest come from other
// resources (exports.city_phone:RegisterApp).
import { label } from './i18n.js';
import { state, on, emit } from './state.js';
import { $, el, appIcon } from './util.js';

export const SETTINGS_APP = {
    id: 'settings',
    label: 'Settings',
    labels: { 'pt-br': 'Ajustes' },
    color: 'linear-gradient(180deg, #a2a2a7, #6e6e73)',
    builtinIcon: 'settings',
    builtin: true,
    order: 1000,
};

export function allApps() {
    return [...state.apps, SETTINGS_APP];
}

export function findApp(id) {
    return allApps().find((app) => app.id === id);
}

function tile(app) {
    const button = el('button', 'app-icon');
    button.append(appIcon(app), el('span', '', label(app)));
    button.addEventListener('click', () => emit('launch', app.id));
    return button;
}

function render() {
    const apps = allApps();

    $('home-grid').replaceChildren(...apps.filter((app) => !app.dock).map(tile));
    $('dock').replaceChildren(...apps.filter((app) => app.dock).slice(0, 4).map(tile));
}

export function initHome() {
    on('apps', render);
    on('language', render);
    render();
}
