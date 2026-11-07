// Control center: click the icons at the top right of the status bar. Silent, Do Not Disturb, flashlight, dark mode
// and a brightness slider.
import { saveSetting } from './settings.js';
import { t } from './i18n.js';
import { state, on, emit } from './state.js';
import { $, el, icon, post } from './util.js';

export function isControlOpen() {
    return $('control').classList.contains('control--open');
}

export function closeControl() {
    $('control').classList.remove('control--open');
}

function toggle(name, iconName, active, onClick) {
    const button = el('button', `toggle toggle--${name}${active ? ' toggle--on' : ''}`);
    button.append(icon(iconName), el('span', '', t(`control.${name}`)));
    button.addEventListener('click', (event) => {
        event.stopPropagation();
        onClick();
    });
    return button;
}

function slider() {
    const node = el('div', 'slider');
    const fill = el('div', 'slider__fill');
    const { min, max } = { min: 30, max: 100 };

    const show = (value) => { fill.style.height = `${((value - min) / (max - min)) * 100}%`; };
    show(state.settings.brightness);

    const pick = (event) => {
        const box = node.getBoundingClientRect();
        const ratio = Math.min(1, Math.max(0, (box.bottom - event.clientY) / box.height));
        return Math.round(min + ratio * (max - min));
    };

    let dragging = false;
    node.addEventListener('pointerdown', (event) => {
        event.stopPropagation();
        dragging = true;
        node.setPointerCapture(event.pointerId);
        show(pick(event));
    });
    node.addEventListener('pointermove', (event) => {
        if (!dragging) return;
        const value = pick(event);
        show(value);
        // Live preview; saved when released
        state.settings.brightness = value;
        emit('settings', 'brightness');
    });
    node.addEventListener('pointerup', (event) => {
        dragging = false;
        saveSetting('brightness', pick(event));
    });

    node.append(fill, icon('sun'));
    return node;
}

function render() {
    const { silent, dnd, theme } = state.settings;

    $('control-grid').replaceChildren(
        toggle('silent', 'silent', silent, () => saveSetting('silent', !silent)),
        toggle('dnd', 'moon', dnd, () => saveSetting('dnd', !dnd)),
        toggle('flashlight', 'flashlight', state.flashlight, toggleFlashlight),
        slider(),
        toggle('dark', 'contrast', theme === 'dark', () => saveSetting('theme', theme === 'dark' ? 'light' : 'dark')),
    );
}

export function setFlashlight(value) {
    state.flashlight = value;
    $('lock-flashlight').classList.toggle('lock__corner--on', value);
    if (isControlOpen()) render();
}

export async function toggleFlashlight() {
    const result = await post('flashlight', { on: !state.flashlight });
    setFlashlight(result === true);
}

export function initControl() {
    // The flashlight button on the lock screen
    const lockButton = $('lock-flashlight');
    lockButton.append(icon('flashlight'));
    lockButton.addEventListener('pointerdown', (event) => event.stopPropagation());
    lockButton.addEventListener('click', (event) => {
        event.stopPropagation();
        toggleFlashlight();
    });

    $('status-icons').addEventListener('click', () => {
        render();
        $('control').classList.toggle('control--open');
    });

    $('control').addEventListener('click', closeControl);

    // Not while dragging the brightness slider: redrawing would drop the drag
    on('settings', (key) => { if (isControlOpen() && key !== 'brightness') render(); });
    on('language', () => { if (isControlOpen()) render(); });
}
