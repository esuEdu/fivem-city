import { el, iconTile } from './util.js';
import { state, L, onRender, allApps, dockApps, timeText, dateText } from './state.js';
import { openApp } from './apps.js';

const home = document.getElementById('home');

function appButton(app, small) {
    const button = el('button', 'app');
    button.setAttribute('aria-label', app.label);

    const tile = iconTile(app, state.settings.iconStyle, small ? 'tile tile-sm' : 'tile', small ? 28 : 32);
    const count = state.badges[app.id];

    if (state.settings.badges && count > 0) tile.append(el('span', 'badge', count > 99 ? '99+' : String(count)));

    button.append(tile);
    if (!small && state.settings.labels) button.append(el('span', 'label', app.label));
    button.addEventListener('click', () => openApp(app.id));

    return button;
}

function renderHome() {
    home.classList.toggle('hidden', state.screen !== 'home');
    if (state.screen !== 'home') return;

    const widgets = state.settings.widgets;
    document.getElementById('widgets').classList.toggle('hidden', !widgets);
    document.getElementById('widget-time').textContent = timeText();
    document.getElementById('widget-date').textContent = dateText(true);
    document.getElementById('widget-city').textContent = L('city');

    const grid = document.getElementById('grid');
    const empty = document.getElementById('empty');
    const noApps = state.apps.length === 0;

    grid.classList.toggle('wide', !widgets);
    empty.classList.toggle('wide', !widgets);
    grid.replaceChildren(...allApps().map((app) => appButton(app, false)));

    // A tablet with nothing but Settings explains where apps come from
    empty.classList.toggle('hidden', !noApps);
    document.getElementById('empty-title').textContent = L('no_apps_title');
    document.getElementById('empty-text').textContent = L('no_apps_text');

    document.getElementById('dock').replaceChildren(...dockApps().map((app) => appButton(app, true)));
}

export function init() {
    onRender(renderHome);
}
