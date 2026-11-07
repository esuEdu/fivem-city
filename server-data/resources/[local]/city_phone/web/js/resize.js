// The phone's size: a percentage saved in the settings (Settings > Appearance, or drag the round grip at the phone's
// top-left corner). The phone stays anchored to the bottom-right of the screen and always fits on it.
import { icon } from '../kit/icons.js';
import { saveSetting } from './settings.js';
import { state } from './state.js';
import { $ } from './util.js';

const PHONE_HEIGHT = 868;
const DEFAULT_SHARE = 0.86; // at 100%, the phone takes this much of the screen height
const MAX_SHARE = 0.97;
export const SIZE = { min: 70, max: 130 };

function clampSize(size) {
    return Math.min(SIZE.max, Math.max(SIZE.min, Math.round(size)));
}

export function fit(size = state.settings.size || 100) {
    const base = Math.min(1, (window.innerHeight * DEFAULT_SHARE) / PHONE_HEIGHT);
    const largest = (window.innerHeight * MAX_SHARE) / PHONE_HEIGHT;
    const scale = Math.min(largest, base * (size / 100));

    $('phone').style.setProperty('--scale', scale.toFixed(3));
}

export function initResize() {
    const grip = $('resize');
    grip.replaceChildren(icon('resize'));

    let start = null;

    grip.addEventListener('pointerdown', (event) => {
        event.preventDefault();
        try { grip.setPointerCapture(event.pointerId); } catch { /* a pointer the page did not see start */ }
        grip.classList.add('phone__resize--active');

        const height = $('phone').getBoundingClientRect().height;
        start = { y: event.clientY, x: event.clientX, height, size: state.settings.size || 100 };
    });

    grip.addEventListener('pointermove', (event) => {
        if (!start) return;

        // Dragging up or left (away from the bottom-right corner) makes it bigger
        const up = start.y - event.clientY;
        const left = (start.x - event.clientX) * (PHONE_HEIGHT / 414);
        const grow = Math.abs(up) >= Math.abs(left) ? up : left;
        const size = clampSize(start.size * ((start.height + grow) / start.height));

        state.settings.size = size;
        fit(size);
    });

    const finish = () => {
        if (!start) return;

        const size = clampSize(state.settings.size || 100);
        start = null;
        grip.classList.remove('phone__resize--active');
        saveSetting('size', size);
    };

    grip.addEventListener('pointerup', finish);
    grip.addEventListener('pointercancel', finish);

    window.addEventListener('resize', () => fit());
}
