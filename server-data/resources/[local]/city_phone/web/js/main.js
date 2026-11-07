// Starts the phone page and handles the messages from Lua (city_phone client).
import { initClock } from './clock.js';
import { initControl, closeControl, isControlOpen, setFlashlight } from './control.js';
import { initHome } from './home.js';
import { loadLanguages, setLanguage } from './i18n.js';
import { setActivity } from './island.js';
import { initLock, lock } from './lock.js';
import { initNotifications, addNotification } from './notifications.js';
import { setRings } from './ring.js';
import { fit, initResize } from './resize.js';
import { refreshSettings } from './settings.js';
import { state, on, emit } from './state.js';
import { initSwitcher, closeSwitcher, isSwitcherOpen } from './switcher.js';
import { $, post, applyTheme } from './util.js';
import { initViews, launch, goHome, messageApp, activeApp } from './views.js';

const FONTS = { inter: 'Inter', poppins: 'Poppins', roboto: 'Roboto', nunito: 'Nunito' };
let pendingApp = null;

function applySettings(key) {
    const { theme, font, wallpaper, brightness, language } = state.settings;
    const phone = $('phone');
    const screen = $('screen');

    phone.dataset.theme = theme;
    phone.style.setProperty('--font', FONTS[font] || 'Inter');
    document.documentElement.style.setProperty('--font', FONTS[font] || 'Inter');
    screen.className = `screen wp-${wallpaper}`;
    $('dim').style.opacity = String(((100 - brightness) / 100) * 0.75);
    fit();

    if (key === undefined || key === 'language') {
        setLanguage(language);
        emit('language');
        refreshSettings();
    }
}

function open(message) {
    state.open = true;
    state.profile = message.profile;
    state.settings = { ...state.settings, ...message.profile.settings };
    state.apps = message.apps || [];
    state.clock = message.clock;

    applySettings();
    emit('apps');
    emit('clock');
    lock();
    emit('opened');

    $('phone').classList.add('phone--open');

    if (pendingApp) {
        launch(pendingApp);
        pendingApp = null;
    }
}

function close() {
    state.open = false;
    closeControl();
    closeSwitcher();
    $('phone').classList.remove('phone--open');
}

const handlers = {
    open,
    close,
    clock: (message) => { state.clock = message.clock; emit('clock'); },
    apps: (message) => { state.apps = message.apps || []; emit('apps'); },
    notify: (message) => addNotification(message.notification, message.quiet),
    activity: (message) => setActivity(message.id, message.data),
    appMessage: (message) => messageApp(message.app, message.data),
    openApp: (message) => { if (state.open) launch(message.app); else pendingApp = message.app; },
    flashlight: (message) => setFlashlight(message.on === true),
    ring: (message) => setRings(message.rings),
};

window.addEventListener('message', (event) => {
    const message = event.data || {};
    const handler = message.action && handlers[message.action];
    if (handler) handler(message);
});

// Escape steps back: control center or multitask first, then the app, then closes the phone
document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || !state.open) return;

    if (isControlOpen()) return closeControl();
    if (isSwitcherOpen()) return closeSwitcher();
    if (activeApp()) return goHome();

    post('close');
});

on('requestClose', () => post('close'));
on('settings', applySettings);

async function start() {
    initResize();
    fit();

    await loadLanguages();
    setLanguage(state.settings.language);

    initClock();
    initLock();
    initHome();
    initViews();
    initSwitcher();
    initControl();
    initNotifications();
    applySettings();

    const setup = await post('ready');
    if (setup) applyTheme(setup.theme);
}

start();
