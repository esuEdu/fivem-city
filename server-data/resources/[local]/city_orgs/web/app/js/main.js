// The faction app: the WorkApp shell (city_os/web/kit/workapp.js) with the faction's tabs. One page serves every
// faction; the server resolves which one from the viewer's gang and sends its name and color.
import { renderDashboard } from './dashboard.js';
import { renderVault } from './vault.js';
import { renderGoals } from './goals.js';
import { renderTeam } from './team.js';
import { renderActivity } from './activity.js';

const { el, L, setLabels, run, shell, addIcons } = window.WorkApp;

addIcons({
    vault: 'M4 8l8-4 8 4v8l-8 4-8-4zM4 8l8 4 8-4M12 12v8',
    target: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 11.5a0.5 0.5 0 1 0 0 1 0.5 0.5 0 0 0 0-1z',
});

// What every tab shares: who is looking, their grade and the faction the server resolved
export const state = { me: '', citizenid: '', faction: '', color: '', boss: false, gradeLevel: 0, grade: '', grades: [], farmItems: [] };

export const app = shell({
    logo: 'shield',
    title: () => state.faction || L('ui_loading'),
    subtitle: () => [state.me, state.grade || ''],
    tabs: [
        { id: 'dashboard', icon: 'dashboard', label: () => L('ui_tab_dashboard'), render: renderDashboard },
        { id: 'vault', icon: 'vault', label: () => L('ui_tab_vault'), render: renderVault },
        { id: 'goals', icon: 'target', label: () => L('ui_tab_goals'), render: renderGoals },
        { id: 'team', icon: 'players', label: () => L('ui_tab_management'), render: renderTeam },
        { id: 'activity', icon: 'log', label: () => L('ui_tab_activity'), render: renderActivity },
    ],
});

// Each app type has its own color (Config.Apps); the page is shared, so it comes from the server
function applyColor(hex) {
    if (!/^#[0-9a-fA-F]{6}$/.test(hex || '')) return;

    const root = document.documentElement.style;
    root.setProperty('--app-accent', hex);
    root.setProperty('--app-accent-soft', `${hex}29`);
    root.setProperty('--app-logo', `linear-gradient(160deg, ${hex}cc, ${hex} 55%, #000000)`);
}

async function start() {
    const response = await run('app');
    if (!response) {
        app.fail(L('error_no_permission'));
        return;
    }

    setLabels(response.data.labels);
    Object.assign(state, response.data);
    applyColor(state.color);
    app.go('dashboard');
}

// The server pokes every member when the vault, goals, money or team change; redraw whatever is open
window.CityOS.on('message', (message) => {
    if (message && app.tab) app.go(app.tab);
});

start();
