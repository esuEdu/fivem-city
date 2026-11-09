import { applyTheme, post, svg, GLYPHS } from './util.js';
import { state, render, onRender, go, applySettings, timeText, dateText } from './state.js';
import * as lock from './lock.js';
import * as home from './home.js';
import * as notes from './notes.js';
import * as apps from './apps.js';
import * as settings from './settings.js';

const tablet = document.getElementById('tablet');
const status = document.getElementById('status');
let closing;

function fit() {
    const scale = Math.max(Math.min((window.innerHeight * 0.9) / 768, (window.innerWidth * 0.92) / 1068), 0.4);
    // zoom, not a scale transform: clicks inside the app iframes only land right when the browser lays the page out
    // at that size (style.css #tablet)
    document.documentElement.style.zoom = String(scale);
}

function renderStatus() {
    const onPage = state.screen === 'app' || state.screen === 'settings';

    status.classList.toggle('on-page', onPage);
    document.getElementById('status-time').textContent = state.screen === 'locked' ? '' : timeText();
    document.getElementById('status-date').textContent = state.screen === 'locked' ? '' : dateText(false);

    document.getElementById('homebar').classList.toggle('hidden', state.screen === 'locked' || state.screen === 'passcode');
    document.getElementById('homebar').classList.toggle('on-page', onPage);
    document.getElementById('status-tap').classList.toggle('hidden', state.screen === 'locked' || state.screen === 'passcode' || state.notesOpen);
    document.getElementById('dim').classList.toggle('hidden', !onPage);
}

function open(message) {
    clearTimeout(closing);

    Object.assign(state, {
        tablet: message.tablet,
        settings: message.tablet.settings,
        apps: message.tablet.apps || [],
        badges: message.tablet.badges || {},
        notes: message.tablet.notifications || [],
        labels: message.labels || {},
        theme: message.theme || {},
        wallpapers: message.wallpapers || [],
        deviceColors: message.deviceColors || [],
        customWallpaper: message.customWallpaper || false,
        config: message.config || {},
        clock: message.clock,
        unlocked: !message.tablet.hasCode,
        notesOpen: false,
        pendingApp: null,
    });

    applyTheme(state.theme);
    applySettings();
    settings.reset();
    lock.reset();
    go('locked');

    tablet.classList.remove('hidden');
    requestAnimationFrame(() => tablet.classList.add('shown'));
}

function close() {
    tablet.classList.remove('shown');
    apps.hideAll();
    closing = setTimeout(() => tablet.classList.add('hidden'), 300);
}

// Esc (and Backspace outside a text field): close what's on top, go home, then put the tablet away
function back() {
    if (state.notesOpen) {
        state.notesOpen = false;
        return render();
    }

    if (state.screen === 'app' || state.screen === 'settings') return go('home');
    if (state.screen === 'passcode') return go('locked');

    post('close');
}

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message.action !== 'string') return;

    switch (message.action) {
        case 'open': return open(message);
        case 'close': return close();
        case 'clock':
            state.clock = message.clock;
            return render();
        case 'apps':
            state.apps = message.apps || [];
            state.badges = message.badges || {};
            return render();
        case 'notify': return notes.add(message.note);
        case 'appMessage': return apps.forward(message.app, message.data);
        case 'openApp':
            // locked with a passcode: opens after unlocking (lock.js)
            if (state.tablet && !state.tablet.hasCode) state.unlocked = true;
            if (state.unlocked) return apps.openApp(message.app, message.args);
            state.pendingApp = { id: message.app, args: message.args };
            return;
    }
});

document.addEventListener('keydown', (event) => {
    if (tablet.classList.contains('hidden')) return;

    const typing = event.target instanceof HTMLInputElement;

    if (event.key === 'Escape' || (event.key === 'Backspace' && !typing)) {
        event.preventDefault();
        back();
    } else if (event.key === 'F2') {
        post('close');
    }
});

document.getElementById('homebar').addEventListener('click', () => go('home'));
document.getElementById('status-icons').append(svg(GLYPHS.wifi, 17, 2.2));

window.addEventListener('resize', fit);
fit();

onRender(renderStatus);
lock.init();
home.init();
notes.init();
apps.init();
settings.init();
