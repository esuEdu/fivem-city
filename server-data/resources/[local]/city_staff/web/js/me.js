import { el, L, run, icon, heading } from './ui.js';
import { app, can } from './main.js';

const TOOLS = ['noclip', 'invisible', 'godmode', 'names', 'blips'];

// city_clothing's photo tool: everything, or one tab and a range of the numbers the shop cards show.
// Overwrite takes pictures that exist again.
function photosForm() {
    const category = el('select', { class: 'field', 'aria-label': L('ui_photos_category') },
        el('option', { value: 'all', text: L('ui_photos_all') }),
        app.clothingCategories.map((c) => el('option', { value: c.id, text: c.label })));
    const sex = el('select', { class: 'field', 'aria-label': L('ui_photos_sex') },
        ['both', 'm', 'f'].map((value) => el('option', { value, text: L(`ui_photos_sex_${value}`) })));
    const number = (key) => el('input', { class: 'field', type: 'number', min: '1', max: '2001', placeholder: L(key), 'aria-label': L(key) });
    const from = number('ui_photos_from');
    const to = number('ui_photos_to');
    const overwrite = el('input', { type: 'checkbox' });

    const read = (input) => (input.value === '' ? null : Number(input.value));

    const start = () => run('clothingPhotos', {
        category: category.value,
        sex: sex.value,
        from: read(from),
        to: read(to),
        overwrite: overwrite.checked,
    });

    return el('div', { class: 'card form' },
        el('div', { class: 'tool-top' }, icon('camera', 22), el('strong', { text: L('tool_clothingPhotos') })),
        el('small', { class: 'muted', text: L('tool_clothingPhotos_help') }),
        el('div', { class: 'form-row' }, category, sex),
        el('div', { class: 'form-row' }, from, to),
        el('label', { class: 'form-row muted' }, overwrite, L('ui_photos_overwrite')),
        el('button', { class: 'kit-btn accent', text: L('ui_photos_start'), onclick: start }),
    );
}

// ox_doorlock's panel: the whole list, or straight to the door the staff member stands next to
function doorlockCard() {
    return el('div', { class: 'card form' },
        el('div', { class: 'tool-top' }, icon('door', 22), el('strong', { text: L('tool_doorlock') })),
        el('small', { class: 'muted', text: L('tool_doorlock_help') }),
        el('div', { class: 'form-row' },
            el('button', { class: 'kit-btn accent', text: L('ui_doorlock_open'), onclick: () => run('doorlock', { closest: false }) }),
            el('button', { class: 'kit-btn', text: L('ui_doorlock_closest'), onclick: () => run('doorlock', { closest: true }) }),
        ),
    );
}

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
        can('doorlock') && app.doorlock ? doorlockCard() : null,
        can('clothingPhotos') && app.clothingCategories ? photosForm() : null,
        vehicles.length ? el('div', { class: 'card form' }, el('strong', { text: L('ui_vehicles') }), el('div', { class: 'form-row' }, vehicles), el('small', { class: 'muted', text: L('ui_vehicles_foot') })) : null,
    );
}
