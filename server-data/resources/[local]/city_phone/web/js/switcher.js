// Multitask: hold the home bar (or drag it up) to see the open apps as cards. Click a card to go back to it, drag it
// up or press x to close it.
import { label, t } from './i18n.js';
import { on } from './state.js';
import { $, el, appIcon } from './util.js';
import { runningApps, launch, closeApp, goHome } from './views.js';

const HOLD_MS = 350;
const SWIPE_CLOSE = 90;

export function isSwitcherOpen() {
    return $('switcher').classList.contains('switcher--open');
}

export function closeSwitcher() {
    $('switcher').classList.remove('switcher--open');
}

function card(app) {
    const node = el('div', 'switcher__card');
    const title = el('div', 'switcher__title');
    const close = el('button', '', '×');
    const preview = el('div', 'switcher__preview');

    const finish = () => {
        node.classList.add('switcher__card--closing');
        setTimeout(() => {
            closeApp(app.id);
            render();
        }, 220);
    };

    close.addEventListener('click', finish);
    title.append(appIcon(app), el('span', '', label(app)), close);

    preview.style.background = app.color;
    preview.append(appIcon(app));

    let startY = null;
    preview.addEventListener('pointerdown', (event) => { startY = event.clientY; });
    preview.addEventListener('pointerup', (event) => {
        const moved = startY === null ? 0 : startY - event.clientY;
        startY = null;

        if (moved > SWIPE_CLOSE) return finish();

        closeSwitcher();
        launch(app.id);
    });

    node.append(title, preview);
    return node;
}

function render() {
    const apps = runningApps();
    $('switcher-cards').replaceChildren(...apps.map(card));
    $('switcher-empty').textContent = apps.length === 0 ? t('switcher.empty') : '';
}

export function openSwitcher() {
    render();
    $('switcher').classList.add('switcher--open');
}

export function initSwitcher() {
    const bar = $('homebar');
    let timer = null;
    let startY = null;
    let held = false;

    bar.addEventListener('pointerdown', (event) => {
        // Keep getting the release even when the pointer leaves the thin bar
        bar.setPointerCapture(event.pointerId);
        startY = event.clientY;
        held = false;
        timer = setTimeout(() => {
            held = true;
            openSwitcher();
        }, HOLD_MS);
    });

    bar.addEventListener('pointerup', (event) => {
        clearTimeout(timer);
        const dragged = startY !== null && startY - event.clientY > 40;
        startY = null;

        if (held) return;
        if (dragged) return openSwitcher();

        // A tap on the home bar: home screen (and closes the multitask view)
        closeSwitcher();
        goHome();
    });

    // Clicking the empty space around the cards goes back
    $('switcher').addEventListener('click', (event) => {
        if (event.target.id === 'switcher' || event.target.id === 'switcher-cards') closeSwitcher();
    });

    on('language', () => { if (isSwitcherOpen()) render(); });
}
