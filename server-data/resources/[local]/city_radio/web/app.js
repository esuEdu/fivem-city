// The radio list. Lua sends the whole state on every change; in edit mode the header drags it and the corner
// resizes it, and the new place goes back to Lua (saved per computer). Game data goes in with textContent only.

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_radio';
const $ = (id) => document.getElementById(id);
const list = $('list');

let range = { min: 200, max: 420 };
let editing = false;

function post(event, data = {}) {
    return fetch(`https://${RESOURCE}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => null);
}

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        document.documentElement.style.setProperty(`--${key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`, value);
    }
}

function initials(name) {
    const words = String(name).replace(/^[\w-]*\d[\w-]*\s+/, '').split(/\s+/).filter(Boolean);
    return (words.slice(0, 2).map((word) => word[0]).join('') || '?').toUpperCase();
}

function memberRow(member) {
    const row = document.createElement('li');
    row.className = `member${member.talking ? ' talking' : ''}${member.me ? ' me' : ''}`;

    const avatar = document.createElement('span');
    avatar.className = 'avatar';
    avatar.textContent = initials(member.name);

    const name = document.createElement('span');
    name.className = 'name';
    name.textContent = member.name;

    const bars = document.createElement('span');
    bars.className = 'bars';
    bars.append(document.createElement('i'), document.createElement('i'), document.createElement('i'));

    row.append(avatar, name, bars);
    return row;
}

function place(layout) {
    list.style.width = `${layout.width}px`;

    if (Number.isFinite(layout.x) && Number.isFinite(layout.y)) {
        const x = Math.max(0, Math.min(window.innerWidth - 80, layout.x));
        const y = Math.max(0, Math.min(window.innerHeight - 60, layout.y));
        Object.assign(list.style, { left: `${x}px`, top: `${y}px`, right: 'auto' });
    }
}

function draw(message) {
    const labels = message.labels || {};
    range = message.widthRange || range;
    editing = message.editing === true;

    list.classList.toggle('hidden', !message.visible);
    list.classList.toggle('editing', editing);
    $('edit-bar').classList.toggle('hidden', !editing);
    $('resize').classList.toggle('hidden', !editing);
    if (!message.visible) return;

    const talkingSelf = (message.members || []).some((member) => member.me && member.talking);
    $('title').textContent = labels.title || 'Radio';
    $('live').textContent = talkingSelf ? labels.tx : labels.live;
    $('live').classList.toggle('tx', talkingSelf);
    $('channel-label').textContent = labels.channel || '';
    $('channel-name').textContent = message.channelName ? `${message.channel} - ${message.channelName}` : String(message.channel);
    $('members-label').textContent = labels.members || '';
    $('count').textContent = String((message.members || []).length);
    $('members').replaceChildren(...(message.members || []).map(memberRow));
    $('done').textContent = labels.done || 'Done';

    place(message.layout || {});
}

function sendLayout() {
    const box = list.getBoundingClientRect();
    post('layout', { x: Math.round(box.left), y: Math.round(box.top), width: Math.round(box.width) });
}

// Dragging by the header and resizing from the corner, only in edit mode
let drag = null;

$('head').addEventListener('mousedown', (event) => {
    if (!editing) return;
    const box = list.getBoundingClientRect();
    drag = { kind: 'move', dx: event.clientX - box.left, dy: event.clientY - box.top };
});

$('resize').addEventListener('mousedown', (event) => {
    if (!editing) return;
    event.stopPropagation();
    drag = { kind: 'size', startX: event.clientX, width: list.getBoundingClientRect().width };
});

window.addEventListener('mousemove', (event) => {
    if (!drag) return;

    if (drag.kind === 'move') {
        const x = Math.max(0, Math.min(window.innerWidth - 80, event.clientX - drag.dx));
        const y = Math.max(0, Math.min(window.innerHeight - 60, event.clientY - drag.dy));
        Object.assign(list.style, { left: `${x}px`, top: `${y}px`, right: 'auto' });
    } else {
        const width = Math.max(range.min, Math.min(range.max, drag.width + event.clientX - drag.startX));
        list.style.width = `${width}px`;
    }
});

window.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = null;
    sendLayout();
});

$('done').addEventListener('click', () => post('done'));

document.addEventListener('keydown', (event) => {
    if (editing && (event.key === 'Escape' || event.key === 'Enter')) post('done');
});

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || message.action !== 'list') return;

    if (message.theme) applyTheme(message.theme);
    draw(message);
});
