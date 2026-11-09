import { el, post, svg, GLYPHS } from './util.js';
import { state, L, go, onRender, render, timeText, dateText } from './state.js';
import { noteCard } from './notes.js';
import { openApp } from './apps.js';

const UNLOCK_DISTANCE = 140;
const lockScreen = document.getElementById('lock');
const passcode = document.getElementById('passcode');
let dragStart = null;
let code = '';

function setShift(px) {
    lockScreen.style.transition = px ? 'none' : 'transform 0.35s cubic-bezier(0.2, 0.8, 0.2, 1), opacity 0.35s';
    lockScreen.style.transform = `translateY(${-px}px)`;
    lockScreen.style.opacity = String(Math.max(0, 1 - px / 300));
}

// Past the lock: the app a script asked for (exports.city_os:OpenApp), or home
function enter() {
    const pending = state.pendingApp;
    state.pendingApp = null;

    if (pending) return openApp(pending.id, pending.args);
    go('home');
}

function afterSwipe() {
    setShift(0);

    if (state.unlocked) return enter();

    code = '';
    renderPasscode('');
    go('passcode');
}

function renderLock() {
    lockScreen.classList.toggle('hidden', state.screen !== 'locked');
    if (state.screen !== 'locked') return;

    document.getElementById('lock-date').textContent = dateText(true);
    document.getElementById('lock-time').textContent = timeText();
    document.getElementById('unlock-text').textContent = L('swipe_unlock');

    // Hidden apps and muted apps never show here
    const list = document.getElementById('lock-notes');
    list.replaceChildren();
    if (!state.settings.lockNotes) return;

    for (const note of state.notes.filter((n) => !n.hidden && !state.settings.muted[n.app]).slice(0, 3)) {
        list.append(noteCard(note, 'div'));
    }
}

function renderPasscode(message, shake) {
    const dots = document.getElementById('dots');
    dots.replaceChildren(...[0, 1, 2, 3].map((i) => el('span', i < code.length ? 'dot on' : 'dot')));

    dots.classList.remove('shake');
    if (shake) {
        void dots.offsetWidth;
        dots.classList.add('shake');
    }

    document.getElementById('code-message').textContent = message;
}

async function press(digit) {
    if (code.length >= 4) return;

    code += digit;
    renderPasscode('');
    if (code.length < 4) return;

    const result = await post('unlock', { code });
    code = '';

    if (result && result.ok) {
        state.unlocked = true;
        state.apps = result.apps || [];
        state.badges = result.badges || {};
        return enter();
    }

    const message = result && result.reason === 'wait' ? L('wait_code', result.wait) : L('wrong_code');
    renderPasscode(message, true);
}

function buildKeypad() {
    const keypad = document.getElementById('keypad');
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'cancel', '0', 'delete'];

    keypad.replaceChildren(...keys.map((key) => {
        const button = el('button', key.length > 1 ? 'key ghost' : 'key', key.length > 1 ? L(key) : key);

        button.addEventListener('click', () => {
            if (key === 'cancel') return go('locked');

            if (key === 'delete') {
                code = code.slice(0, -1);
                return renderPasscode('');
            }

            press(key);
        });

        return button;
    }));
}

export function init() {
    lockScreen.addEventListener('pointerdown', (event) => {
        dragStart = event.clientY;
        lockScreen.setPointerCapture(event.pointerId);
    });

    lockScreen.addEventListener('pointermove', (event) => {
        if (dragStart === null) return;
        setShift(Math.max(0, dragStart - event.clientY));
    });

    const release = (event) => {
        if (dragStart === null) return;

        const distance = dragStart - event.clientY;
        dragStart = null;

        if (distance > UNLOCK_DISTANCE) afterSwipe();
        else setShift(0);
    };

    lockScreen.addEventListener('pointerup', release);
    lockScreen.addEventListener('pointercancel', release);
    document.getElementById('unlock-hint').addEventListener('click', afterSwipe);

    // Typing the code works too
    document.addEventListener('keydown', (event) => {
        if (state.screen === 'passcode' && /^\d$/.test(event.key)) press(event.key);
    });

    document.getElementById('passcode-icon').append(svg(GLYPHS.lock, 24, 2));

    onRender(() => {
        renderLock();
        passcode.classList.toggle('hidden', state.screen !== 'passcode');

        if (state.screen === 'passcode') {
            document.getElementById('passcode-title').textContent = L('enter_code');
            if (!document.getElementById('keypad').childElementCount) buildKeypad();
        }
    });
}

export function reset() {
    code = '';
    setShift(0);
    document.getElementById('keypad').replaceChildren();
    render();
}
