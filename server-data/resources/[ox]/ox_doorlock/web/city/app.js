// fivem-city: ox_doorlock's panel in the city_ui look. Same NUI messages and callbacks as ox_doorlock's own page
// (updateDoorData, setSoundFiles, setVisible, playSound; createDoor, deleteDoor, teleportToDoor, exit, notify).
// Game data goes in with textContent only.

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ox_doorlock';
const $ = (id) => document.getElementById(id);
const DIFFICULTIES = ['easy', 'medium', 'hard'];

const doors = new Map();
let sounds = [];
let view = 'list';
let search = '';
let draft = null;
let copied = null;

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

function el(tag, attrs = {}, ...children) {
    const element = document.createElement(tag);

    for (const [key, value] of Object.entries(attrs)) {
        if (value === undefined || value === null || value === false) continue;
        if (key === 'text') element.textContent = String(value);
        else if (key.startsWith('on')) element.addEventListener(key.slice(2), value);
        else element.setAttribute(key, value === true ? '' : String(value));
    }

    for (const child of children.flat()) {
        if (child !== null && child !== undefined && child !== false) element.append(child);
    }

    return element;
}

function svg(d, size = 16) {
    const ns = 'http://www.w3.org/2000/svg';
    const icon = document.createElementNS(ns, 'svg');
    icon.setAttribute('viewBox', '0 0 24 24');
    icon.setAttribute('width', String(size));
    icon.setAttribute('height', String(size));
    const path = document.createElementNS(ns, 'path');
    path.setAttribute('d', d);
    icon.append(path);
    return icon;
}

const ICONS = {
    plus: 'M12 5v14M5 12h14',
    edit: 'M15.5 5.5l3 3M4 20l1-4 11-11a2.1 2.1 0 0 1 3 3L8 19z',
    goto: 'M4.5 11.2L19.5 4.5l-6.7 15-1.9-6.4z',
    trash: 'M5 7h14M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
    copy: 'M9 9h11v11H9zM5 15H4V4h11v1',
    paste: 'M8 4h8v3H8zM6 5H4v16h16V5h-2',
    search: 'M11 4.5a6.5 6.5 0 1 1 0 13a6.5 6.5 0 1 1 0-13zM16 16l4.5 4.5',
    lock: 'M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5z',
    unlock: 'M7 10V7a5 5 0 0 1 9.6-2M5 10h14v11H5z',
};

let toastTimer = null;

function toast(text) {
    $('toast').textContent = text;
    $('toast').classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => $('toast').classList.add('hidden'), 2500);
}

// ---- Door data ----

function setDoors(data) {
    if (typeof data === 'number') {
        doors.delete(data);
    } else if (data && typeof data === 'object' && data.id !== undefined && !Array.isArray(data)) {
        doors.set(Number(data.id), data);
    } else if (data && typeof data === 'object') {
        doors.clear();
        for (const door of Object.values(data)) if (door && door.id !== undefined) doors.set(Number(door.id), door);
    }

    if (view === 'list' && !$('panel').classList.contains('hidden')) drawList();
}

// A door as the form edits it; arrays and plain values only
function toDraft(door) {
    const groups = Object.entries(door?.groups || {}).map(([name, grade]) => ({ name, grade }));
    const difficulty = (door?.lockpickDifficulty || []).map((entry) => (typeof entry === 'string'
        ? { kind: entry }
        : { kind: 'custom', areaSize: entry.areaSize, speedMultiplier: entry.speedMultiplier }));

    return {
        id: door?.id,
        name: door?.name || '',
        passcode: door?.passcode || '',
        autolock: door?.autolock ?? '',
        maxDistance: door?.maxDistance ?? 2,
        doorRate: door?.doorRate ?? '',
        lockSound: door?.lockSound || '',
        unlockSound: door?.unlockSound || '',
        state: door ? door.state === 1 : true,
        double: Boolean(door?.doors),
        auto: Boolean(door?.auto),
        lockpick: Boolean(door?.lockpick),
        hideUi: Boolean(door?.hideUi),
        holdOpen: Boolean(door?.holdOpen),
        groups,
        characters: [...(door?.characters || [])],
        items: (door?.items || []).map((item) => ({
            name: typeof item === 'string' ? item : item.name || '',
            metadata: typeof item === 'object' && item.metadata ? String(item.metadata) : '',
            remove: typeof item === 'object' && item.remove === true,
        })),
        difficulty,
    };
}

const number = (value) => (value === '' || value === null || value === undefined || Number.isNaN(Number(value)) ? undefined : Number(value));
const text = (value) => (typeof value === 'string' && value.trim() !== '' ? value.trim() : undefined);

// What createDoor gets: the original door (coords, model, double door leaves) with the form's values on top.
// Empty values are left out, never sent as null.
function fromDraft() {
    const original = draft.id !== undefined ? doors.get(Number(draft.id)) : null;
    const data = original ? JSON.parse(JSON.stringify(original)) : {};

    for (const key of ['passcode', 'autolock', 'doorRate', 'lockSound', 'unlockSound', 'groups', 'characters', 'items', 'lockpickDifficulty']) delete data[key];

    data.name = text(draft.name);
    data.passcode = text(draft.passcode);
    data.autolock = number(draft.autolock) > 0 ? number(draft.autolock) : undefined;
    data.maxDistance = number(draft.maxDistance) ?? 2;
    data.doorRate = number(draft.doorRate);
    data.lockSound = text(draft.lockSound);
    data.unlockSound = text(draft.unlockSound);
    data.state = draft.state;
    data.auto = draft.auto;
    data.lockpick = draft.lockpick;
    data.hideUi = draft.hideUi;
    data.holdOpen = draft.holdOpen;
    if (!original) data.doors = draft.double || undefined;

    const groups = {};
    for (const group of draft.groups) if (text(group.name)) groups[group.name.trim()] = number(group.grade) ?? 0;
    data.groups = groups;
    data.characters = draft.characters.map(text).filter(Boolean);
    data.items = draft.items.filter((item) => text(item.name)).map((item) => ({
        name: item.name.trim(),
        metadata: text(item.metadata),
        remove: item.remove || undefined,
    }));
    data.lockpickDifficulty = draft.difficulty.map((entry) => (entry.kind === 'custom'
        ? { areaSize: number(entry.areaSize) ?? 50, speedMultiplier: number(entry.speedMultiplier) ?? 1 }
        : entry.kind));

    for (const key of Object.keys(data)) if (data[key] === undefined) delete data[key];

    return data;
}

// ---- Header ----

function headButton(icon, label, onclick, accent) {
    return el('button', { type: 'button', class: `btn${accent ? ' accent' : ''}`, onclick }, svg(ICONS[icon], 15), el('span', { text: label }));
}

function drawHead() {
    const editing = view === 'form';
    $('back').classList.toggle('hidden', !editing);

    if (!editing) {
        $('title').textContent = 'Door locks';
        $('subtitle').textContent = `${doors.size} door${doors.size === 1 ? '' : 's'}`;
        $('head-actions').replaceChildren(headButton('plus', 'New door', () => openForm(null), true));
        return;
    }

    $('title').textContent = draft.id !== undefined ? draft.name || `Door ${draft.id}` : 'New door';
    $('subtitle').textContent = draft.id !== undefined ? `#${draft.id}` : 'Save, then click the door in the world (right click cancels)';
    const actions = [headButton('copy', 'Copy settings', () => {
        copied = JSON.parse(JSON.stringify(draft));
        drawHead();
        toast('Settings copied');
    })];

    if (copied) {
        actions.push(headButton('paste', 'Apply copied', () => {
            const keep = { id: draft.id, name: draft.name, double: draft.double };
            draft = { ...JSON.parse(JSON.stringify(copied)), ...keep };
            drawForm();
            toast('Copied settings applied');
        }));
    }

    $('head-actions').replaceChildren(...actions);
}

// ---- List ----

function drawList() {
    view = 'list';
    drawHead();

    const input = el('input', { class: 'field', type: 'search', placeholder: 'Search by name, id or area', value: search, 'aria-label': 'Search doors' });
    input.addEventListener('input', () => {
        search = input.value;
        drawRows(rows);
    });

    const rows = el('div', { class: 'rows' });
    drawRows(rows);

    $('body').replaceChildren(el('div', { class: 'search' }, svg(ICONS.search, 16), input), rows);
    input.focus();
}

function drawRows(rows) {
    const query = search.trim().toLowerCase();
    const list = [...doors.values()]
        .filter((door) => !query || [door.id, door.name, door.zone].some((value) => String(value ?? '').toLowerCase().includes(query)))
        .sort((a, b) => Number(a.id) - Number(b.id));

    if (!list.length) return rows.replaceChildren(el('p', { class: 'empty', text: doors.size ? 'No door matches the search.' : 'No doors yet. Create the first one.' }));

    rows.replaceChildren(...list.map((door) => {
        const locked = door.state === 1;
        const access = Object.keys(door.groups || {}).join(', ') || (door.passcode ? 'Passcode' : door.items?.length ? 'Items' : door.characters?.length ? 'Characters' : 'Nobody');

        const remove = el('button', { type: 'button', class: 'icon-btn danger', title: 'Delete', 'aria-label': `Delete ${door.name || door.id}` }, svg(ICONS.trash, 16));
        remove.addEventListener('click', () => {
            if (!remove.classList.contains('sure')) {
                remove.classList.add('sure');
                remove.replaceChildren(el('span', { text: 'Sure?' }));
                return setTimeout(() => remove.isConnected && drawRows(rows), 3000);
            }
            post('deleteDoor', Number(door.id));
        });

        return el('div', { class: 'row' },
            el('span', { class: 'id', text: `#${door.id}` }),
            el('span', { class: `state ${locked ? 'locked' : 'open'}`, title: locked ? 'Locked' : 'Unlocked' }, svg(locked ? ICONS.lock : ICONS.unlock, 14)),
            el('div', { class: 'grow' },
                el('strong', { text: door.name || `Door ${door.id}` }),
                el('small', { text: [door.zone, door.doors ? 'Double' : null, door.auto ? 'Automatic' : null].filter(Boolean).join(' · ') }),
            ),
            el('span', { class: 'chip', text: access }),
            el('div', { class: 'row-actions' },
                el('button', { type: 'button', class: 'icon-btn', title: 'Edit', 'aria-label': `Edit ${door.name || door.id}`, onclick: () => openForm(door) }, svg(ICONS.edit, 16)),
                el('button', { type: 'button', class: 'icon-btn', title: 'Teleport to door', 'aria-label': `Teleport to ${door.name || door.id}`, onclick: () => { post('teleportToDoor', Number(door.id)); hide(false); } }, svg(ICONS.goto, 16)),
                remove,
            ),
        );
    }));
}

// ---- Form ----

function openForm(door) {
    draft = toDraft(door);
    view = 'form';
    drawForm();
}

function bind(input, key, target = draft, kind = 'value') {
    if (kind === 'checked') {
        input.checked = Boolean(target[key]);
        input.addEventListener('change', () => { target[key] = input.checked; });
    } else {
        input.value = target[key] ?? '';
        input.addEventListener('input', () => { target[key] = input.value; });
    }
    return input;
}

function field(label, input, hint) {
    return el('label', { class: 'field-box' }, el('span', { class: 'label', text: label }), input, hint ? el('small', { class: 'hint', text: hint }) : null);
}

function toggle(label, key, hint, disabled) {
    const input = bind(el('input', { type: 'checkbox', disabled }), key, draft, 'checked');
    return el('label', { class: `toggle${disabled ? ' disabled' : ''}`, title: hint || '' }, input, el('i'), el('span', { text: label }));
}

function soundSelect(key) {
    const select = el('select', { class: 'field' }, el('option', { value: '', text: 'Default' }), sounds.map((name) => el('option', { value: name, text: name })));
    return bind(select, key);
}

// One editable list (groups, characters, items, lockpick difficulty)
function listSection(title, hint, entries, makeRow, makeEntry) {
    const body = el('div', { class: 'list' });

    const redraw = () => {
        body.replaceChildren(...entries.map((entry, index) => el('div', { class: 'list-row' },
            ...makeRow(entry, index),
            el('button', { type: 'button', class: 'icon-btn danger', 'aria-label': 'Remove', onclick: () => { entries.splice(index, 1); redraw(); } }, svg(ICONS.trash, 15)),
        )));
        if (!entries.length) body.append(el('p', { class: 'empty small', text: 'None' }));
    };
    redraw();

    return el('section', { class: 'card' },
        el('div', { class: 'card-head' },
            el('div', {}, el('strong', { text: title }), el('small', { text: hint })),
            el('button', { type: 'button', class: 'btn small', onclick: () => { entries.push(makeEntry()); redraw(); } }, svg(ICONS.plus, 14), el('span', { text: 'Add' })),
        ),
        body,
    );
}

function drawForm() {
    drawHead();
    const isNew = draft.id === undefined;

    const general = el('section', { class: 'card' },
        el('div', { class: 'card-head' }, el('div', {}, el('strong', { text: 'Door' }), el('small', { text: 'Name, how close to use it and the sounds' }))),
        el('div', { class: 'grid' },
            field('Name', bind(el('input', { class: 'field', type: 'text', maxlength: '60', placeholder: 'mrpd cell 1' }), 'name')),
            field('Passcode', bind(el('input', { class: 'field', type: 'text', maxlength: '30', placeholder: 'None' }), 'passcode'), 'Asked when someone without access uses it'),
            field('Autolock (seconds)', bind(el('input', { class: 'field', type: 'number', min: '0', step: '1', placeholder: 'Off' }), 'autolock')),
            field('Interact distance (m)', bind(el('input', { class: 'field', type: 'number', min: '0.5', max: '15', step: '0.5' }), 'maxDistance')),
            field('Door rate', bind(el('input', { class: 'field', type: 'number', min: '0', step: '0.1', placeholder: 'Default' }), 'doorRate'), 'How fast an automatic door moves'),
            field('Lock sound', soundSelect('lockSound')),
            field('Unlock sound', soundSelect('unlockSound')),
        ),
        el('div', { class: 'toggles' },
            toggle('Locked', 'state'),
            toggle('Double door', 'double', 'Two leaves; pick both in the world', !isNew),
            toggle('Automatic', 'auto', 'Opens by itself (gates, garage doors)'),
            toggle('Lockpick', 'lockpick', 'Can be lockpicked'),
            toggle('Hide icon', 'hideUi', 'No lock icon near the door'),
            toggle('Hold open', 'holdOpen', 'Stays open while unlocked'),
        ),
    );

    const groups = listSection('Groups', 'Jobs or gangs, from a grade up', draft.groups,
        (entry) => [bind(el('input', { class: 'field', type: 'text', placeholder: 'police', 'aria-label': 'Group' }), 'name', entry),
            bind(el('input', { class: 'field narrow', type: 'number', min: '0', step: '1', placeholder: 'Grade', 'aria-label': 'Grade' }), 'grade', entry)],
        () => ({ name: '', grade: 0 }));

    const characters = listSection('Characters', 'Citizen IDs that always open it', draft.characters,
        (entry, index) => {
            const input = el('input', { class: 'field', type: 'text', placeholder: 'Citizen ID', 'aria-label': 'Citizen ID', value: entry });
            input.addEventListener('input', () => { draft.characters[index] = input.value; });
            return [input];
        },
        () => '');

    const items = listSection('Items', 'Carrying one opens it', draft.items,
        (entry) => [bind(el('input', { class: 'field', type: 'text', placeholder: 'Item name', 'aria-label': 'Item' }), 'name', entry),
            bind(el('input', { class: 'field', type: 'text', placeholder: 'Metadata type (optional)', 'aria-label': 'Metadata' }), 'metadata', entry),
            el('label', { class: 'toggle compact' }, bind(el('input', { type: 'checkbox' }), 'remove', entry, 'checked'), el('i'), el('span', { text: 'Remove on use' }))],
        () => ({ name: '', metadata: '', remove: false }));

    const difficulty = listSection('Lockpick difficulty', 'One skill check per row', draft.difficulty,
        (entry) => {
            const kind = el('select', { class: 'field narrow', 'aria-label': 'Difficulty' },
                [...DIFFICULTIES, 'custom'].map((value) => el('option', { value, text: value[0].toUpperCase() + value.slice(1) })));
            const custom = el('div', { class: `custom${entry.kind === 'custom' ? '' : ' hidden'}` },
                bind(el('input', { class: 'field narrow', type: 'number', min: '1', placeholder: 'Area size', 'aria-label': 'Area size' }), 'areaSize', entry),
                bind(el('input', { class: 'field narrow', type: 'number', min: '0.1', step: '0.1', placeholder: 'Speed', 'aria-label': 'Speed multiplier' }), 'speedMultiplier', entry));
            kind.value = entry.kind;
            kind.addEventListener('change', () => {
                entry.kind = kind.value;
                custom.classList.toggle('hidden', entry.kind !== 'custom');
            });
            return [kind, custom];
        },
        () => ({ kind: 'easy' }));

    const save = el('button', { type: 'button', class: 'btn accent big' }, el('span', { text: isNew ? 'Save and pick the door' : 'Save changes' }));
    save.addEventListener('click', () => {
        if (!text(draft.name)) return toast('Give the door a name');
        if (draft.lockpick && !draft.difficulty.length) draft.difficulty.push({ kind: 'easy' });

        post('createDoor', fromDraft());
        hide(false);
    });

    $('body').replaceChildren(
        el('div', { class: 'form' },
            general,
            el('div', { class: 'two' }, groups, characters),
            el('div', { class: 'two' }, items, difficulty),
        ),
        el('div', { class: 'foot' }, el('button', { type: 'button', class: 'btn', text: 'Cancel', onclick: drawList }), save),
    );
}

// ---- Open and close ----

// createDoor and teleportToDoor drop the focus themselves; only Close and Escape tell the game
function hide(tellGame = true) {
    $('panel').classList.add('hidden');
    if (tellGame) post('exit');
}

function show(id) {
    $('panel').classList.remove('hidden');

    const door = id !== null && id !== undefined ? doors.get(Number(id)) : null;
    if (door) openForm(door);
    else drawList();
}

$('close').addEventListener('click', () => hide());
$('back').addEventListener('click', drawList);

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || $('panel').classList.contains('hidden')) return;
    if (view === 'form') drawList();
    else hide();
});

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message.action !== 'string') return;

    switch (message.action) {
    case 'setTheme': applyTheme(message.data); break;
    case 'updateDoorData': setDoors(message.data); break;
    case 'setSoundFiles': sounds = Array.isArray(message.data) ? message.data.map(String) : []; break;
    case 'setVisible': show(message.data); break;
    case 'playSound': {
        const sound = message.data || {};
        if (typeof sound.sound !== 'string') break;
        const audio = new Audio(`../build/sounds/${encodeURIComponent(sound.sound)}.ogg`);
        audio.volume = Math.max(0, Math.min(1, Number(sound.volume) || 0));
        audio.play().catch(() => null);
        break;
    }
    default: break;
    }
});
