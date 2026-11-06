import { el, L, run, section } from './ui.js';
import { app, can } from './main.js';

const TOOLS = ['noclip', 'invisible', 'godmode', 'names', 'blips'];

export async function renderMe() {
    const switches = TOOLS.filter(can).map((tool) => {
        const toggle = el('button', { class: `kit-switch${app.tools[tool] ? ' on' : ''}` });

        toggle.addEventListener('click', async () => {
            const response = await run(tool);
            if (!response) return;

            app.tools[tool] = response.data === true;
            toggle.classList.toggle('on', app.tools[tool]);
        });

        return el('div', { class: 'kit-row' }, el('span', { class: 'who' }, el('strong', { text: L(`tool_${tool}`) }), el('small', { text: L(`tool_${tool}_help`) })), toggle);
    });

    const vehicles = [];

    if (can('spawnVehicle')) {
        const model = el('input', { class: 'kit-input wide', type: 'text', maxlength: '40', placeholder: L('ui_model') });
        const spawn = () => model.value.trim() && run('spawnVehicle', { model: model.value.trim() }, L('ui_spawned'));
        model.addEventListener('keydown', (event) => event.key === 'Enter' && spawn());
        vehicles.push(el('div', { class: 'kit-row form' }, model, el('button', { class: 'kit-btn accent', text: L('ui_spawn'), onclick: spawn })));
    }

    const buttons = [
        can('fixVehicle') ? el('button', { class: 'kit-btn', text: L('ui_fix'), onclick: () => run('fixVehicle', {}, L('ui_fixed')) }) : null,
        can('deleteVehicle') ? el('button', { class: 'kit-btn', text: L('ui_delete_vehicle'), onclick: () => run('deleteVehicle', {}, L('ui_deleted')) }) : null,
        can('saveVehicle') ? el('button', { class: 'kit-btn', text: L('ui_save_vehicle'), onclick: () => run('saveVehicle', {}, L('vehicle_saved')) }) : null,
    ].filter(Boolean);

    if (buttons.length) vehicles.push(el('div', { class: 'kit-row form' }, buttons));

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { class: 'kit-heading', text: L('ui_tab_me') })),
        switches.length ? section(L('ui_tools'), switches) : null,
        vehicles.length ? section(L('ui_vehicles'), vehicles, L('ui_vehicles_foot')) : null,
    );
}
