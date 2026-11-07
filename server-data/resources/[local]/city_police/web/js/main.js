import { el, L, setLabels, run, icon } from './ui.js';
import { renderDashboard } from './dashboard.js';
import { renderDispatch } from './dispatch.js';
import { renderMap } from './map.js';
import { renderUnits, pickStatus } from './units.js';
import { renderPeople } from './people.js';
import { renderVehicles } from './vehicles.js';
import { renderWeapons } from './weapons.js';
import { renderReports } from './reports.js';
import { renderWarrants } from './warrants.js';
import { renderCharges } from './charges.js';
import { renderImpounds } from './impounds.js';
import { renderLicences } from './licences.js';
import { renderEvidence } from './evidence.js';
import { renderCameras } from './cameras.js';
import { renderCerts } from './certs.js';
import { renderManagement } from './management.js';

// What every tab shares: this officer, what they may do, the penal code and lists from the server
export const app = { permissions: {}, tab: 'dashboard', openCalls: 0, me: {} };

const content = document.getElementById('content');
const nav = document.getElementById('nav');

const SECTIONS = [
    { id: 'operations', tabs: [
        { id: 'dashboard', icon: 'dashboard', permission: 'app', render: renderDashboard },
        { id: 'dispatch', icon: 'dispatch', permission: 'dispatch', render: renderDispatch },
        { id: 'map', icon: 'map', permission: 'app', render: renderMap },
        { id: 'units', icon: 'units', permission: 'app', render: renderUnits },
    ] },
    { id: 'records', tabs: [
        { id: 'people', icon: 'people', permission: 'people', render: renderPeople },
        { id: 'vehicles', icon: 'vehicles', permission: 'vehicles', render: renderVehicles },
        { id: 'weapons', icon: 'weapons', permission: 'weapons', render: renderWeapons },
        { id: 'reports', icon: 'reports', permission: 'reports', render: renderReports },
        { id: 'warrants', icon: 'warrants', permission: 'warrants', render: renderWarrants },
        { id: 'charges', icon: 'charges', permission: 'charge', render: renderCharges },
    ] },
    { id: 'tools', tabs: [
        { id: 'impounds', icon: 'impounds', permission: 'impound', render: renderImpounds },
        { id: 'licences', icon: 'licences', permission: 'licences', render: renderLicences },
        { id: 'evidence', icon: 'evidence', permission: 'evidence', render: renderEvidence },
        { id: 'cameras', icon: 'cameras', permission: 'cameras', render: renderCameras },
    ] },
    { id: 'department', tabs: [
        { id: 'certs', icon: 'certs', permission: 'certs', render: renderCerts },
        { id: 'management', icon: 'management', permission: 'management', render: renderManagement },
    ] },
];

const TABS = SECTIONS.flatMap((section) => section.tabs);

// Tabs that redraw on their own when the server says calls or units changed
const LIVE = { calls: ['dashboard', 'dispatch', 'map'], units: ['units', 'map', 'dashboard'] };

export function can(action) {
    return app.permissions[action] === true;
}

let drawing = 0;

// Each tab draws into the content area; `args` opens it on one item (a person, a call from a notification)
export async function go(tab, args) {
    app.tab = tab;
    drawNav();

    const ticket = ++drawing;
    if (!content.firstChild) content.replaceChildren(el('div', { class: 'loading', text: L('ui_loading') }));

    const view = await TABS.find((entry) => entry.id === tab).render(args);
    if (ticket === drawing && app.tab === tab) {
        content.replaceChildren(view);
        content.scrollTop = 0;
    }
}

// Redraws the open tab in place (keeps the scroll)
export async function refresh(args) {
    const tab = app.tab;
    const top = content.scrollTop;
    const view = await TABS.find((entry) => entry.id === tab).render(args);

    if (app.tab === tab) {
        content.replaceChildren(view);
        content.scrollTop = top;
    }
}

export function setCallCount(count) {
    app.openCalls = count;
    drawNav();
}

export function setMyStatus(status) {
    app.me.status = status;
    document.getElementById('status-value').textContent = L(`status_${status || 'available'}`);
    document.getElementById('status-dot').className = `dot ${status || 'available'}`;
}

function drawNav() {
    const children = [];

    for (const section of SECTIONS) {
        const tabs = section.tabs.filter((tab) => can(tab.permission));
        if (!tabs.length) continue;

        children.push(el('div', { class: 'nav-head', text: L(`ui_section_${section.id}`) }));

        for (const tab of tabs) {
            children.push(el('button', { class: `nav${app.tab === tab.id ? ' on' : ''}`, onclick: () => go(tab.id) },
                icon(tab.icon, 18),
                el('span', { class: 'label', text: L(`ui_tab_${tab.id}`) }),
                tab.id === 'dispatch' && app.openCalls > 0 ? el('span', { class: 'badge', text: String(app.openCalls) }) : null,
            ));
        }
    }

    nav.replaceChildren(...children);
}

async function start() {
    const response = await run('app');
    if (!response) {
        content.replaceChildren(el('div', { class: 'empty' }, icon('lock', 40), el('p', { text: L('error_off_duty') })));
        return;
    }

    Object.assign(app, response.data);
    setLabels(response.data.labels);

    document.getElementById('logo').append(icon('shield', 22, 2));
    document.getElementById('title').textContent = L('ui_title');
    document.getElementById('me').textContent = app.me.callsign ? `${app.me.callsign} · ${app.me.name}` : app.me.name;
    document.getElementById('rank').textContent = app.me.gradeLabel;
    document.getElementById('status-label').textContent = L('ui_my_status');
    document.getElementById('status-card').addEventListener('click', () => pickStatus());
    setMyStatus(app.me.status);

    go('dashboard');
}

window.CityOS.on('message', (message) => {
    if (!message || message.type !== 'refresh' || !message.what) return;

    for (const [what, tabs] of Object.entries(LIVE)) {
        if (message.what[what] && tabs.includes(app.tab) && !app.editing) refresh();
    }
});

// A tapped call notification opens that call
window.CityOS.on('open', (args) => {
    if (args && args.tab === 'dispatch' && can('dispatch')) go('dispatch', { id: args.call });
});

start();
