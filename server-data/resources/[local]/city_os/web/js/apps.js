import { el, post, svg, GLYPHS } from './util.js';
import { state, L, go, onRender, findApp } from './state.js';

const container = document.getElementById('apps');
const unavailable = document.getElementById('unavailable');

// One iframe per app, kept a while after it's closed so going back is instant
const frames = new Map(); // id -> { frame, origin, ready, queue, timer }

function themeMessage() {
    const s = state.settings;
    return { type: 'theme', data: { appearance: s.appearance, iconStyle: s.iconStyle, textSize: s.textSize, bold: s.bold, colors: state.theme } };
}

function send(entry, message) {
    if (!entry.ready) return entry.queue.push(message);
    entry.frame.contentWindow.postMessage(message, entry.origin);
}

function frameFor(app) {
    let entry = frames.get(app.id);
    if (entry) return entry;

    const frame = el('iframe');
    frame.src = app.url;
    frame.title = app.label;
    frame.classList.add('hidden');

    entry = { frame, origin: new URL(app.url).origin, ready: false, queue: [], timer: null };
    frames.set(app.id, entry);
    container.append(frame);

    return entry;
}

function drop(id) {
    const entry = frames.get(id);
    if (!entry) return;

    entry.frame.remove();
    frames.delete(id);
}

function showOnly(id) {
    for (const [frameId, entry] of frames) {
        const visible = frameId === id;
        entry.frame.classList.toggle('hidden', !visible);

        if (visible) {
            clearTimeout(entry.timer);
            entry.timer = null;
        } else if (!entry.timer) {
            entry.timer = setTimeout(() => drop(frameId), (state.config.appIdleSeconds || 120) * 1000);
        }
    }
}

function showUnavailable(app) {
    showOnly(null);
    unavailable.classList.remove('hidden');
    document.getElementById('unavailable-title').textContent = L('app_unavailable', app.label);
    document.getElementById('unavailable-text').textContent = L('app_unavailable_text');

    const retry = document.getElementById('unavailable-retry');
    retry.textContent = L('try_again');
    retry.onclick = () => {
        drop(app.id);
        openApp(app.id);
    };
}

// args: what a tapped notification asked the app to show
export async function openApp(id, args) {
    if (id === 'settings') return go('settings');

    const app = findApp(id);
    if (!app) return;

    go('app', id);
    unavailable.classList.add('hidden');

    const result = await post('openApp', { id });
    if (state.app !== id) return;
    if (!result || !result.ok) return showUnavailable(app);

    const entry = frameFor(app);
    showOnly(id);
    send(entry, themeMessage());
    if (args) send(entry, { type: 'open', data: args });
}

// From the app's client script (exports.city_os:SendAppMessage)
export function forward(id, data) {
    const entry = frames.get(id);
    if (entry) send(entry, { type: 'message', data });
}

export function hideAll() {
    showOnly(null);
}

export function init() {
    document.getElementById('unavailable-icon').append(Object.assign(svg(GLYPHS.warning, 40, 2), { style: 'color: #ffb03b' }));

    window.addEventListener('message', (event) => {
        const message = event.data;
        if (!message || typeof message.cityOS !== 'string') return;

        for (const [id, entry] of frames) {
            if (entry.frame.contentWindow !== event.source || event.origin !== entry.origin) continue;

            if (message.cityOS === 'ready') {
                entry.ready = true;
                send(entry, themeMessage());
                for (const queued of entry.queue.splice(0)) send(entry, queued);
            } else if (message.cityOS === 'home' && state.app === id) {
                go('home');
            }
        }
    });

    onRender(() => {
        container.classList.toggle('hidden', state.screen !== 'app');
        if (state.screen !== 'app') showOnly(null);

        // Appearance and text size changes reach open apps
        for (const entry of frames.values()) {
            if (entry.ready) entry.frame.contentWindow.postMessage(themeMessage(), entry.origin);
        }
    });
}
