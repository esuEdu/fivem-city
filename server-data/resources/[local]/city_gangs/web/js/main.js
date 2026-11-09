import { el, L, setLabels, run, icon, drugLabels } from './ui.js';
import { renderOverview } from './overview.js';
import { renderMembers } from './members.js';
import { renderRecruit } from './recruit.js';
import { renderDrugs } from './drugs.js';
import { renderLog } from './log.js';

// Everything the tabs share: who this member is, what their rank may do, the gang's grades
export const app = { permissions: {}, grades: [], tab: 'overview', period: 7 };

const content = document.getElementById('content');
const nav = document.getElementById('nav');

const TABS = [
    { id: 'overview', icon: 'overview', permission: 'app', render: renderOverview },
    { id: 'members', icon: 'members', permission: 'app', render: renderMembers },
    { id: 'recruit', icon: 'recruit', permission: 'recruit', render: renderRecruit },
    { id: 'drugs', icon: 'drugs', permission: 'app', render: renderDrugs },
    { id: 'log', icon: 'log', permission: 'log', render: renderLog },
];

export function can(action) {
    return app.permissions[action] === true;
}

export async function go(tab, args) {
    app.tab = tab;
    drawNav();

    if (!content.firstChild) content.replaceChildren(el('div', { class: 'loading', text: L('ui_loading') }));

    const view = await TABS.find((entry) => entry.id === tab).render(args);
    if (app.tab === tab) content.replaceChildren(view);
}

export function setOnline(online, total) {
    document.getElementById('online-count').textContent = L('ui_online_count', online, total);
}

function drawNav() {
    nav.replaceChildren(...TABS.filter((tab) => can(tab.permission)).map((tab) =>
        el('button', { class: `nav${app.tab === tab.id ? ' on' : ''}`, onclick: () => go(tab.id) },
            icon(tab.icon),
            el('span', { class: 'label', text: L(`ui_tab_${tab.id}`) }))));
}

// After leaving the gang (or being kicked out) the app has nothing to show
export function closed(text) {
    nav.replaceChildren();
    content.replaceChildren(el('div', { class: 'empty', text }));
}

async function start() {
    const response = await run('app');
    if (!response) {
        closed(L('error_no_gang'));
        return;
    }

    Object.assign(app, response.data);
    app.period = response.data.period;
    setLabels(response.data.labels);

    // Drug names for the overview and log come from the guide; the guide may be missing if city_drugs is stopped
    const guide = await window.CityOS.send('run', { action: 'drugs' });
    if (guide && guide.ok) {
        app.guide = guide.data;
        for (const drug of guide.data.drugs) drugLabels[drug.id] = drug.label;
    }

    document.getElementById('logo').append(icon('gang', 22, 2));
    document.getElementById('title').textContent = app.gang;
    document.getElementById('me').textContent = app.me;
    document.getElementById('grade').textContent = app.gradeName;
    document.getElementById('online-label').textContent = L('ui_online');

    go('overview');
}

start();
