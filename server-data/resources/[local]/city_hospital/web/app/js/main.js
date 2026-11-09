// The EMS app: the WorkApp shell (city_os/web/kit/workapp.js) with this job's tabs. Copied from the Mechanic app
// (docs/work-apps.md).
import { renderDashboard } from './dashboard.js';
import { renderCalls, loadCalls } from './calls.js';
import { renderManagement } from './management.js';
import { renderRecords } from './records.js';

const { el, L, setLabels, run, shell, addIcons } = window.WorkApp;

addIcons({
    heart: 'M12 20.3S3.8 15.6 3.8 9.4A4.2 4.2 0 0 1 12 7.2a4.2 4.2 0 0 1 8.2 2.2c0 6.2-8.2 10.9-8.2 10.9zM7 12.2h2.6l1.4-2.4 2.1 4.6 1.3-2.2H17',
    sos: 'M12 3l9.5 17h-19zM12 10v4.5M12 17.5v.01',
    officer: 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6zM12 8.5v4M12 15.5v.01',
});

// What every tab shares: who is looking, their grade, and the lists from the server
export const state = { calls: 0, boss: false, onDuty: false, grades: [], prices: null, me: '', citizenid: '' };

export const app = shell({
    logo: 'heart',
    title: () => L('ui_title'),
    subtitle: () => [state.me, state.grade || ''],
    tabs: [
        { id: 'dashboard', icon: 'dashboard', label: () => L('ui_tab_dashboard'), render: renderDashboard },
        { id: 'calls', icon: 'bell', label: () => L('ui_tab_calls'), badge: () => (state.onDuty ? state.calls : 0), render: renderCalls },
        { id: 'management', icon: 'players', label: () => L('ui_tab_management'), render: renderManagement },
        { id: 'records', icon: 'list', label: () => L('ui_tab_records'), render: renderRecords },
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
    if (!message) return;

    if (message.type === 'team') {
        if (app.tab === 'management') app.go('management');
        return;
    }

    if (message.type !== 'calls') return;

    await loadCalls();
    if (app.tab === 'calls' || app.tab === 'dashboard') app.go(app.tab);
});

// A tapped "new call" notification opens that call
window.CityOS.on('open', (args) => {
    if (args && args.tab === 'calls') app.go('calls', { id: args.id });
});

start();
