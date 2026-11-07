// The home screen: every app in a grid, the dock apps at the bottom. Settings is built in; the rest come from other
// resources (exports.city_phone:RegisterApp).
import { formatTime } from './clock.js';
import { label, t } from './i18n.js';
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
    const icon = appIcon(app);
    if (app.badge > 0) icon.append(el('span', 'badge', app.badge > 99 ? '99+' : String(app.badge)));

    button.append(icon, el('span', '', label(app)));
    button.addEventListener('click', () => emit('launch', app.id));
    return button;
}

// The clock widget: weekday, day, month and the game time
function widget() {
    const { weekday, day, month } = state.clock;
    const days = t('time.days');
    const months = t('time.months');

    return el('div', 'widget', null,
        el('div', 'widget__day', null,
            el('span', 'widget__weekday', Array.isArray(days) ? days[weekday] : ''),
            el('span', 'widget__date', String(day)),
            el('span', 'widget__month', Array.isArray(months) ? months[month] : ''),
        ),
        el('span', 'widget__time', formatTime(state.clock)),
    );
}

function render() {
    const apps = allApps();

    $('home-grid').replaceChildren(widget(), ...apps.filter((app) => !app.dock).map(tile));
    $('dock').replaceChildren(...apps.filter((app) => app.dock).slice(0, 4).map(tile));
}

export function initHome() {
    on('apps', render);
    on('language', render);
    on('clock', render);
    render();
}
