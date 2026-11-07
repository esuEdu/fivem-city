import { el, L, run, icon, searchField, empty } from './ui.js';
import { app } from './main.js';

let filter = '';

export async function renderCameras() {
    app.editing = false;

    const states = (await window.CityOS.send('cameraStates')) || {};
    const grid = el('div', { class: 'camera-grid' });

    const draw = () => {
        const shown = app.cameras.map((camera, index) => ({ ...camera, index: index + 1 }))
            .filter((camera) => !filter || camera.label.toLowerCase().includes(filter));

        grid.replaceChildren(...(shown.length ? shown.map((camera) => {
            // Lua sends the 1-based list as a JSON array
            const online = (Array.isArray(states) ? states[camera.index - 1] : states[camera.index]) !== false;

            return el('button', { class: `camera${online ? '' : ' offline'}`, onclick: () => run('viewCamera', { index: camera.index }) },
                el('span', { class: 'camera-icon' }, icon('camera', 22)),
                el('span', { class: 'who' }, el('strong', { text: camera.label }), el('small', { text: online ? L('ui_camera_online') : L('ui_camera_offline') })),
            );
        }) : [empty(L('ui_no_results'))]));
    };

    draw();

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_cameras') }), el('span', { class: 'pill', text: String(app.cameras.length) })),
        el('p', { class: 'muted', text: L('ui_camera_hint') }),
        searchField(L('ui_search_cameras'), (value) => {
            filter = value;
            draw();
        }),
        grid,
    );
}
