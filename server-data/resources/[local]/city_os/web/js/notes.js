import { el, iconTile, post } from './util.js';
import { state, L, onRender, render, findApp } from './state.js';
import { openApp } from './apps.js';

const center = document.getElementById('nc');
const banner = document.getElementById('banner');
let bannerTimer;

function age(time) {
    const minutes = Math.floor((Date.now() / 1000 - time) / 60);

    if (minutes < 1) return L('now');
    if (minutes < 60) return L('minutes_ago', minutes);
    return L('hours_ago', Math.floor(minutes / 60));
}

function tap(note) {
    state.notesOpen = false;
    banner.classList.add('hidden');

    // Only when the tablet is unlocked and the player still sees that app
    if (state.screen === 'locked' || state.screen === 'passcode' || !note.app || !findApp(note.app)) return render();

    openApp(note.app, note.open);
}

export function noteCard(note, tag = 'button') {
    const card = el(tag, 'glass note');
    const icon = note.icon && iconTile({ icon: note.icon }, state.settings.iconStyle, 'tile tile-xs', 18);

    const head = el('span', 'note-head');
    head.append(el('span', '', note.appLabel), el('span', 'muted', age(note.time)));

    const text = el('span', 'note-text');
    text.append(head, el('span', '', note.title));
    if (note.body) text.append(el('span', 'note-body', note.body));

    if (icon) card.append(icon);
    card.append(text);
    card.style.borderRadius = '22px';
    if (tag === 'button') card.addEventListener('click', () => tap(note));

    return card;
}

function visibleNotes() {
    return state.notes.filter((note) => !state.settings.muted[note.app] && (!note.app || findApp(note.app)));
}

function renderCenter() {
    center.classList.toggle('hidden', !state.notesOpen);
    if (!state.notesOpen) return;

    document.getElementById('nc-title').textContent = L('notifications');

    const list = document.getElementById('nc-list');
    const notes = visibleNotes();
    const clear = document.getElementById('nc-clear');

    clear.textContent = L('clear_all');
    clear.classList.toggle('hidden', !notes.length);
    list.replaceChildren();

    if (!notes.length) {
        list.append(Object.assign(el('div', 'muted', L('no_notifications')), { style: 'padding: 60px 0; text-align: center; font-size: 15px;' }));
        return;
    }

    // Grouped by app, newest group first
    const groups = new Map();

    for (const note of notes) {
        const key = note.app || 'ifruit';
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push(note);
    }

    for (const items of groups.values()) {
        const group = el('div', 'nc-group');
        for (const note of items) group.append(noteCard(note));
        list.append(group);
    }
}

function showBanner(note) {
    clearTimeout(bannerTimer);

    banner.replaceChildren(...noteCard(note, 'div').childNodes);
    banner.onclick = () => tap(note);
    banner.classList.remove('hidden');

    bannerTimer = setTimeout(() => banner.classList.add('hidden'), (state.config.bannerSeconds || 5) * 1000);
}

export function add(note) {
    state.notes.unshift(note);
    state.notes.length = Math.min(state.notes.length, 50);

    const muted = state.settings.muted[note.app];
    if (note.banner && !muted && state.screen !== 'locked' && state.screen !== 'passcode') showBanner(note);

    render();
}

export function init() {
    document.getElementById('status-tap').addEventListener('click', () => {
        state.notesOpen = true;
        render();
    });

    document.getElementById('nc-back').addEventListener('click', () => {
        state.notesOpen = false;
        render();
    });

    document.getElementById('nc-clear').addEventListener('click', async () => {
        state.notes = [];
        render();
        await post('clearNotifications');
    });

    onRender(renderCenter);
}
