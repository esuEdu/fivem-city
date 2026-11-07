import { el, L, run, icon, heading } from './ui.js';
import { app, can } from './main.js';

const TOOLS = ['noclip', 'invisible', 'godmode', 'names', 'blips'];

export async function renderMe() {
    const cards = TOOLS.filter(can).map((tool) => {
        const state = el('small', { class: 'state', text: app.tools[tool] ? L('ui_on') : L('ui_off') });
        const card = el('button', { class: `tool${app.tools[tool] ? ' on' : ''}`, 'aria-pressed': app.tools[tool] ? 'true' : 'false' },
            el('div', { class: 'tool-top' }, icon(tool, 22), el('span', { class: 'spacer' }), state),
            el('strong', { text: L(`tool_${tool}`) }),
            el('small', { text: L(`tool_${tool}_help`) }),
        );

        card.addEventListener('click', async () => {
            const response = await run(tool);
            if (!response) return;

            app.tools[tool] = response.data === true;
            card.classList.toggle('on', app.tools[tool]);
            card.setAttribute('aria-pressed', app.tools[tool] ? 'true' : 'false');
            state.textContent = app.tools[tool] ? L('ui_on') : L('ui_off');
        });

        return card;
    });

    const vehicles = [];

    if (can('spawnVehicle')) {
        const model = el('input', { class: 'field', type: 'text', maxlength: '40', placeholder: L('ui_model'), 'aria-label': L('ui_model') });
        const spawn = () => model.value.trim() && run('spawnVehicle', { model: model.value.trim() }, L('ui_spawned'));
        model.addEventListener('keydown', (event) => event.key === 'Enter' && spawn());
        vehicles.push(model, el('button', { class: 'kit-btn accent', text: L('ui_spawn'), onclick: spawn }));
    }

    return el('div', { class: 'stack' },
        heading(L('ui_tab_me')),
        cards.length ? el('div', { class: 'tools' }, cards) : null,
        vehicles.length ? el('div', { class: 'card form' }, el('strong', { text: L('ui_vehicles') }), el('div', { class: 'form-row' }, vehicles), el('small', { class: 'muted', text: L('ui_vehicles_foot') })) : null,
    );
}
