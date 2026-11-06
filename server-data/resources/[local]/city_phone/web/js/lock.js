// The lock screen: shown every time the phone opens. Drag it up (or click the hint) to get to the home screen.
// There is no passcode: the phone always shows its user's own things.
import { t } from './i18n.js';
import { on } from './state.js';
import { $ } from './util.js';

const UNLOCK_DISTANCE = 110;
let locked = true;

export function isLocked() {
    return locked;
}

export function lock() {
    locked = true;
    $('phone').classList.add('phone--locked');
    const node = $('lock');
    node.style.transform = '';
    node.classList.remove('lock--hidden');
}

export function unlock() {
    locked = false;
    $('phone').classList.remove('phone--locked');
    const node = $('lock');
    node.style.transform = '';
    node.classList.remove('lock--dragging');
    node.classList.add('lock--hidden');
}

export function initLock() {
    const node = $('lock');
    let startY = null;
    let fromHint = false;

    $('lock-hint').textContent = t('lock.hint');
    on('language', () => { $('lock-hint').textContent = t('lock.hint'); });

    node.addEventListener('pointerdown', (event) => {
        if (event.target.closest('button')) return;
        fromHint = event.target.id === 'lock-hint';
        startY = event.clientY;
        node.setPointerCapture(event.pointerId);
        node.style.transition = 'none';
    });

    node.addEventListener('pointermove', (event) => {
        if (startY === null) return;
        const moved = Math.min(0, event.clientY - startY);
        node.style.transform = `translateY(${moved}px)`;
    });

    node.addEventListener('pointerup', (event) => {
        if (startY === null) return;

        const moved = startY - event.clientY;
        startY = null;
        node.style.transition = '';

        // A drag up, or a plain click on the hint
        if (moved > UNLOCK_DISTANCE || (fromHint && Math.abs(moved) < 8)) unlock();
        else node.style.transform = '';
    });
}
