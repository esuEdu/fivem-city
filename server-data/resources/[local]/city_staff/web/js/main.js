import { el, L, setLabels, run, icon } from './ui.js';
import { renderDashboard } from './dashboard.js';
import { renderPlayers } from './players.js';
import { renderReports, loadReports } from './reports.js';
import { renderRatings } from './ratings.js';
import { renderBans, renderLog } from './records.js';
import { renderTeam } from './team.js';
import { renderMe } from './me.js';

// Everything the tabs share: what this staff member may do, and the lists the forms use
export const app = { permissions: {}, tab: 'dashboard', openReports: 0 };

const content = document.getElementById('content');
const nav = document.getElementById('nav');

const SELF_TOOLS = ['noclip', 'invisible', 'godmode', 'names', 'blips', 'spawnVehicle', 'clothingPhotos'];

const TABS = [
    { id: 'dashboard', icon: 'dashboard', permission: 'app', render: renderDashboard },
    { id: 'players', icon: 'players', permission: 'app', render: renderPlayers },
    { id: 'reports', icon: 'reports', permission: 'reports', render: renderReports },
    { id: 'ratings', icon: 'star', permission: 'ratings', render: renderRatings },
    { id: 'team', icon: 'players', permission: 'team', render: renderTeam },
    { id: 'bans', icon: 'ban', permission: 'ban', render: renderBans },
    { id: 'log', icon: 'log', permission: 'log', render: renderLog },
    { id: 'me', icon: 'tools', permission: null, render: renderMe },
];

export function can(action) {
    return app.permissions[action] === true;
}

// Each tab draws into the content area; `args` lets a tab open on one item (a player, a report from a notification)
export async function go(tab, args) {
    app.tab = tab;
    drawNav();

    if (!content.firstChild) content.replaceChildren(el('div', { class: 'loading', text: L('ui_loading') }));

    const view = await TABS.find((entry) => entry.id === tab).render(args);
    if (app.tab === tab) content.replaceChildren(view);
}

export function setReportsBadge(count) {
    app.openReports = count;
    drawNav();
}

export function setStaffOnline(count) {
    document.getElementById('online-count').textContent = L('ui_staff_online_count', count);
}

function drawNav() {
    nav.replaceChildren(...TABS
        .filter((tab) => tab.permission ? can(tab.permission) : SELF_TOOLS.some(can))
        .map((tab) => el('button', { class: `nav${app.tab === tab.id ? ' on' : ''}`, onclick: () => go(tab.id) },
            icon(tab.icon),
            el('span', { class: 'label', text: L(`ui_tab_${tab.id}`) }),
            tab.id === 'reports' && app.openReports > 0 ? el('span', { class: 'badge', text: String(app.openReports) }) : null,
        )));
}

async function start() {
    const response = await run('app');
    if (!response) {
        content.replaceChildren(el('div', { class: 'empty', text: L('error_no_permission') }));
        return;
    }

    Object.assign(app, response.data);
    setLabels(response.data.labels);

    document.getElementById('logo').append(icon('shield', 22, 2));
    document.getElementById('title').textContent = L('ui_title');
    document.getElementById('me').textContent = app.me;
    document.getElementById('level').textContent = L(`level_${app.level}`);
    document.getElementById('online-label').textContent = L('ui_staff_online');
    setStaffOnline(app.staffOnline);

    if (can('reports')) await loadReports();
    go('dashboard');
}

window.CityOS.on('message', async (message) => {
    if (message && message.type === 'reports' && can('reports')) {
        await loadReports();
        if (app.tab === 'reports' || app.tab === 'dashboard') go(app.tab);
    }
});

// A tapped "new report" notification opens that report
window.CityOS.on('open', (args) => {
    if (args && args.tab === 'reports' && can('reports')) go('reports', { id: args.id });
});

start();
