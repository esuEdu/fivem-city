// The Mechanic app: the WorkApp shell (city_os/web/kit/workapp.js) with this job's tabs.
import { renderDashboard } from './dashboard.js';
import { renderCalls, loadCalls } from './calls.js';
import { renderTeam } from './team.js';
import { renderServices } from './services.js';

const { el, L, setLabels, run, shell, addIcons } = window.WorkApp;

addIcons({
    tow: 'M3 16h11V9h4l3 4v3h-2M3 16V7h8v9M7 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM17 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4z',
    tyre: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 3v5M12 16v5M3 12h5M16 12h5',
    engine: 'M4 10h3l2-3h5l1 2h3v3h2v4h-2v2H9l-2-2H4zM9 4h5',
});

// What every tab shares: who is looking, their grade, and the lists from the server
export const state = { calls: 0, boss: false, onDuty: false, grades: [], prices: null, me: '', citizenid: '' };

export const app = shell({
    logo: 'wrench',
    title: () => L('ui_title'),
    subtitle: () => [state.me, state.grade || ''],
    tabs: [
        { id: 'dashboard', icon: 'dashboard', label: () => L('ui_tab_dashboard'), render: renderDashboard },
        { id: 'calls', icon: 'bell', label: () => L('ui_tab_calls'), badge: () => (state.onDuty ? state.calls : 0), render: renderCalls },
        { id: 'team', icon: 'players', label: () => L('ui_tab_team'), render: renderTeam },
        { id: 'services', icon: 'list', label: () => L('ui_tab_services'), render: renderServices },
    ],
    footer: () => el('div', { class: 'wa-foot' },
        el('small', { text: state.shop || '' }),
        el('span', {}, el('i', { class: `dot${state.onDuty ? ' on' : ''}` }), state.onDuty ? L('ui_on_duty') : L('ui_off_duty'))),
});

export function setCalls(count) {
    state.calls = count;
    app.refresh();
}

export function setDuty(onDuty) {
    if (state.onDuty === onDuty) return;
    state.onDuty = onDuty;
    app.refresh();
}

async function start() {
    const response = await run('app');
    if (!response) {
        app.fail(L('error_no_permission'));
        return;
    }

    setLabels(response.data.labels);
    Object.assign(state, response.data);
    app.go('dashboard');
}

window.CityOS.on('message', async (message) => {
    if (!message || message.type !== 'calls') return;

    await loadCalls();
    if (app.tab === 'calls' || app.tab === 'dashboard') app.go(app.tab);
});

// A tapped "new call" notification opens that call
window.CityOS.on('open', (args) => {
    if (args && args.tab === 'calls') app.go('calls', { id: args.id });
});

start();
