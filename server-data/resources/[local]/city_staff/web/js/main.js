import { el, L, setLabels, run } from './ui.js';
import { renderPlayers, renderPlayer } from './players.js';
import { renderReports, openReports } from './reports.js';
import { renderBans, renderLog } from './records.js';
import { renderMe } from './me.js';

// Everything the tabs share: what this staff member may do, and the lists the forms use
export const app = { permissions: {}, tab: 'players', openReports: 0 };

const content = document.getElementById('content');
const nav = document.getElementById('nav');

const TABS = [
    { id: 'players', permission: 'app', render: renderPlayers },
    { id: 'player', permission: 'app', render: renderPlayer, hidden: true },
    { id: 'reports', permission: 'reports', render: renderReports },
    { id: 'bans', permission: 'ban', render: renderBans },
    { id: 'log', permission: 'log', render: renderLog },
    { id: 'me', permission: null, render: renderMe },
];

export function can(action) {
    return app.permissions[action] === true;
}

// Each tab draws into the content area; `args` lets a tab open on one item (a report from a notification)
export async function go(tab, args) {
    app.tab = tab;
    drawNav();
    content.replaceChildren(el('div', { class: 'loading', text: L('ui_loading') }));

    const view = await TABS.find((entry) => entry.id === tab).render(args);
    if (app.tab === tab) content.replaceChildren(view);
}

export function setReportsBadge(count) {
    app.openReports = count;
    drawNav();
}

function drawNav() {
    // A player's page belongs under Players
    const current = app.tab === 'player' ? 'players' : app.tab;

    nav.replaceChildren(...TABS
        .filter((tab) => !tab.hidden && (tab.permission ? can(tab.permission) : hasSelfTools()))
        .map((tab) => el('button', { class: `kit-nav${current === tab.id ? ' on' : ''}`, onclick: () => go(tab.id) },
            el('span', { text: L(`ui_tab_${tab.id}`) }),
            tab.id === 'reports' && app.openReports > 0 ? el('span', { class: 'badge', text: String(app.openReports) }) : null,
        )));
}

function hasSelfTools() {
    return ['noclip', 'invisible', 'godmode', 'names', 'blips', 'spawnVehicle', 'fixVehicle', 'deleteVehicle', 'saveVehicle'].some(can);
}

async function start() {
    const response = await run('app');
    if (!response) {
        content.replaceChildren(el('div', { class: 'empty', text: L('error_no_permission') }));
        return;
    }

    Object.assign(app, response.data);
    setLabels(response.data.labels);
    document.getElementById('title').textContent = L('ui_title');
    document.getElementById('level').textContent = L(`level_${app.level}`);

    if (can('reports')) await openReports();
    go('players');
}

window.CityOS.on('message', async (message) => {
    if (message && message.type === 'reports' && can('reports')) {
        await openReports();
        if (app.tab === 'reports') go('reports');
    }
});

// A tapped "new report" notification opens that report
window.CityOS.on('open', (args) => {
    if (args && args.tab === 'reports' && can('reports')) go('reports', { id: args.id });
});

start();
