// The panel for the prop being placed or edited, and the card for a clicked map prop.
import { t, post, el, button, round } from './util.js';
import { nameOf } from './catalog.js';

const state = {
    target: null,
    groups: [],
    keepPlacing: true,
};

export function setGroups(groups) {
    state.groups = groups || [];
    if (state.target) render();
}

export function getTarget() {
    return state.target;
}

function field(label, key, value) {
    const wrap = el('label', 'field');
    wrap.append(el('span', '', label));

    const input = el('input', 'input');
    input.type = 'number';
    input.step = key.startsWith('r') ? '1' : '0.01';
    input.value = round(value, key.startsWith('r') ? 2 : 3);
    input.dataset.key = key;
    input.addEventListener('change', () => {
        const number = Number(input.value);
        if (Number.isFinite(number)) post('set', { [key]: number });
    });

    wrap.append(input);
    return wrap;
}

function groupSelect(current) {
    const select = el('select', 'input grow');
    const none = el('option', '', t('no_group'));
    none.value = '0';
    select.append(none);

    for (const group of state.groups) {
        const option = el('option', '', group.name);
        option.value = String(group.id);
        if (group.id === current) option.selected = true;
        select.append(option);
    }

    select.addEventListener('change', () => post('set', { group: Number(select.value) || 0 }));
    return select;
}

export async function save() {
    if (!state.target) return;
    await post('save', { again: !state.target.id && state.keepPlacing });
}

export function remove() {
    if (state.target && state.target.id) post('delete');
}

function render() {
    const panel = document.getElementById('inspector');
    const target = state.target;

    if (!target) {
        panel.classList.add('hidden');
        return;
    }

    // Don't rebuild the inputs under the cursor while typing; only refresh their values
    const focused = document.activeElement;
    if (focused && panel.contains(focused) && focused.dataset.key && panel.dataset.model === `${target.id}:${target.model}`) {
        for (const input of panel.querySelectorAll('input[data-key]')) {
            if (input !== focused) input.value = round(target[input.dataset.key], input.dataset.key.startsWith('r') ? 2 : 3);
        }
        return;
    }

    panel.dataset.model = `${target.id}:${target.model}`;
    panel.replaceChildren();
    panel.classList.remove('hidden');

    const head = el('div', 'head');
    head.append(el('div', 'title', target.id ? t('edit_prop', target.id) : t('new_prop')), el('div', 'model', target.model));
    panel.append(head);

    panel.append(el('div', 'label', t('position')));
    const position = el('div', 'fields');
    position.append(field('X', 'x', target.x), field('Y', 'y', target.y), field('Z', 'z', target.z));
    panel.append(position);

    panel.append(el('div', 'label', t('rotation')));
    const rotation = el('div', 'fields');
    rotation.append(field('P', 'rx', target.rx), field('R', 'ry', target.ry), field('Y', 'rz', target.rz));
    panel.append(rotation);

    const line = el('div', 'line');
    const collision = el('label', 'check');
    const box = el('input');
    box.type = 'checkbox';
    box.checked = target.collision;
    box.addEventListener('change', () => post('set', { collision: box.checked }));
    collision.append(box, document.createTextNode(t('collision')));
    line.append(collision, groupSelect(target.group));
    panel.append(line);

    if (target.follow) panel.append(el('div', 'status', t('following')));

    const tools = el('div', 'actions');
    tools.append(
        button(t('follow'), target.follow ? 'small on' : 'small', () => post('follow')),
        button(t('ground'), 'small', () => post('ground')),
    );
    if (target.id) {
        tools.append(button(t('duplicate'), 'small', () => post('duplicate')), button(t('delete'), 'small danger', remove));
    }
    panel.append(tools);

    if (!target.id) {
        const keep = el('label', 'check');
        keep.style.marginTop = '10px';
        const keepBox = el('input');
        keepBox.type = 'checkbox';
        keepBox.checked = state.keepPlacing;
        keepBox.addEventListener('change', () => { state.keepPlacing = keepBox.checked; });
        keep.append(keepBox, document.createTextNode(t('keep_placing')));
        panel.append(keep);
    }

    const actions = el('div', 'actions');
    actions.append(el('div', 'grow'), button(t('cancel'), '', () => post('cancel')), button(t('save'), 'accent', save));
    panel.append(actions);
}

export function setTarget(target) {
    state.target = target;
    render();
}

export function setPicked(picked, hideRadius) {
    const panel = document.getElementById('picked');
    panel.replaceChildren();

    if (!picked) {
        panel.classList.add('hidden');
        return;
    }

    const name = nameOf(picked.hash);
    const label = name || `0x${(picked.hash >>> 0).toString(16).toUpperCase().padStart(8, '0')}`;

    const head = el('div', 'head');
    head.append(el('div', 'title', t('map_prop')), el('div', 'model', label));
    panel.append(head);
    panel.append(el('div', 'note', t('hide_note', hideRadius)));

    const actions = el('div', 'actions');
    actions.append(
        el('div', 'grow'),
        button(t('cancel'), '', () => setPicked(null)),
        button(t('hide_prop'), 'accent', () => post('hide', { label: name })),
    );
    panel.append(actions);
    panel.classList.remove('hidden');
}
