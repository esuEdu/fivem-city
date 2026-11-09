// The editor overlay: wires the panels to the game, the mouse on the world and the keyboard shortcuts.
import { t, post, el, applyTheme, setLabels } from './util.js';
import * as catalog from './catalog.js';
import * as inspector from './inspector.js';
import * as lists from './lists.js';

const TABS = ['catalog', 'placed', 'groups', 'hidden'];

const state = {
    open: false,
    looking: false,
    tab: 'catalog',
    hideRadius: 1,
    lastCursor: 0,
    max: 0,
    ready: catalog.init(),
};

// Keys while the page has focus: [kind, direction] sent as nudges
const NUDGES = {
    ArrowUp: ['forward', 1], ArrowDown: ['forward', -1], ArrowRight: ['side', 1], ArrowLeft: ['side', -1],
    PageUp: ['up', 1], PageDown: ['up', -1],
    KeyE: ['yaw', 1], KeyQ: ['yaw', -1], KeyX: ['pitch', 1], KeyZ: ['pitch', -1], KeyV: ['roll', 1], KeyC: ['roll', -1],
};

function showTab(tab) {
    state.tab = tab;
    for (const name of TABS) document.getElementById(`tab-${name}`).classList.toggle('hidden', name !== tab);
    for (const node of document.querySelectorAll('#tabs button')) node.classList.toggle('active', node.dataset.tab === tab);
    if (tab !== 'catalog') catalog.stopPreview();
    if (tab !== 'catalog') lists.refresh();
}

function renderStatic() {
    document.getElementById('title').textContent = t('title');
    document.getElementById('undo').textContent = t('undo');
    document.getElementById('redo').textContent = t('redo');
    document.getElementById('helpBtn').textContent = t('help');
    document.getElementById('exit').textContent = t('exit');
    document.getElementById('search').placeholder = t('search');
    document.getElementById('groupName').placeholder = t('group_name');
    document.getElementById('groupCreate').textContent = t('group_create');
    document.getElementById('looking').textContent = t('looking');

    const tabs = document.getElementById('tabs');
    tabs.replaceChildren();
    for (const name of TABS) {
        const node = el('button', '', t(`tab_${name}`));
        node.dataset.tab = name;
        node.addEventListener('click', () => showTab(name));
        tabs.append(node);
    }

    const help = document.getElementById('help');
    help.replaceChildren(el('b', '', t('keys_title')));
    for (const key of ['key_fly', 'key_select', 'key_move', 'key_rotate', 'key_fine', 'key_actions', 'key_history']) {
        help.append(el('div', '', t(key)));
    }
}

function setCount(count) {
    document.getElementById('count').textContent = t('props_count', count, state.max);
}

function setLooking(value) {
    state.looking = value;
    document.getElementById('crosshair').classList.toggle('hidden', !value);
    document.getElementById('looking').classList.toggle('hidden', !value);
    document.getElementById('side').style.opacity = value ? '0.5' : '';
}

function close() {
    state.open = false;
    catalog.stopPreview();
    document.getElementById('app').classList.add('hidden');
    document.getElementById('dialog').classList.add('hidden');
}

const handlers = {
    async open(data) {
        await state.ready;
        applyTheme(data.theme);
        setLabels(data.labels);
        state.max = data.max;
        state.hideRadius = data.hideRadius;
        state.open = true;

        renderStatic();
        setCount(data.count);
        catalog.setup();
        lists.setGroups(data.groups);
        inspector.setTarget(null);
        inspector.setPicked(null);
        showTab('catalog');
        document.getElementById('app').classList.remove('hidden');
    },
    close,
    looking: setLooking,
    custom: (names) => catalog.setCustom(names),
    target(target) {
        inspector.setTarget(target);
        if (state.open && state.tab !== 'catalog') lists.refresh();
    },
    picked: (picked) => inspector.setPicked(picked, state.hideRadius),
    groups: (groups) => {
        lists.setGroups(groups);
        if (state.tab !== 'catalog') lists.refresh();
    },
    history(counts) {
        document.getElementById('undo').disabled = !counts.undo;
        document.getElementById('redo').disabled = !counts.redo;
        if (state.tab !== 'catalog') lists.refresh();
    },
    count: setCount,
};

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};
    if (handlers[action]) handlers[action](data);
});

function screenPoint(event) {
    return { x: event.clientX / window.innerWidth, y: event.clientY / window.innerHeight };
}

function typing() {
    const node = document.activeElement;
    return node && (node.tagName === 'INPUT' || node.tagName === 'SELECT' || node.tagName === 'TEXTAREA');
}

function init() {
    const stage = document.getElementById('stage');

    stage.addEventListener('mousedown', (event) => {
        if (!state.open) return;
        if (document.activeElement) document.activeElement.blur();
        catalog.stopPreview();

        if (event.button === 2) post('look');
        else if (event.button === 0) post('click', screenPoint(event));
    });

    stage.addEventListener('mousemove', (event) => {
        const target = inspector.getTarget();
        if (!state.open || !target || !target.follow) return;

        const now = performance.now();
        if (now - state.lastCursor < 40) return;
        state.lastCursor = now;
        post('cursor', screenPoint(event));
    });

    window.addEventListener('contextmenu', (event) => event.preventDefault());

    document.getElementById('undo').addEventListener('click', () => post('history', { undo: true }));
    document.getElementById('redo').addEventListener('click', () => post('history', { undo: false }));
    document.getElementById('exit').addEventListener('click', () => post('exit'));
    document.getElementById('helpBtn').addEventListener('click', () => document.getElementById('help').classList.toggle('hidden'));

    window.addEventListener('keydown', (event) => {
        if (!state.open || state.looking) return;

        const dialogOpen = !document.getElementById('dialog').classList.contains('hidden');

        if (event.key === 'Escape') {
            event.preventDefault();
            if (dialogOpen) return document.getElementById('dialog').classList.add('hidden');
            if (typing()) return document.activeElement.blur();
            if (inspector.getTarget()) return post('cancel');
            if (!document.getElementById('picked').classList.contains('hidden')) return inspector.setPicked(null);
            return post('exit');
        }

        if (typing() || dialogOpen) return;

        if (event.ctrlKey && event.code === 'KeyZ') return post('history', { undo: true });
        if (event.ctrlKey && event.code === 'KeyY') return post('history', { undo: false });
        if (event.ctrlKey && event.code === 'KeyD') {
            event.preventDefault();
            return post('duplicate');
        }

        const target = inspector.getTarget();
        if (!target) return;

        const nudge = NUDGES[event.code];
        if (nudge) {
            event.preventDefault();
            return post('nudge', { kind: nudge[0], dir: nudge[1], fine: event.shiftKey });
        }

        if (event.key === 'Enter') return inspector.save();
        if (event.key === 'Delete') return inspector.remove();
        if (event.code === 'KeyG') return post('ground');
        if (event.code === 'KeyT') return post('follow');
    });

    lists.init();
}

init();
