'use strict';

// Renders what the client sends and forwards clicks. Every change is decided by the server.

const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_inventory';

const HOTBAR_VISIBLE_MS = 1500;
const DRAG_THRESHOLD_PX = 5;

const state = {
    slots: 0,
    hotbar: 0,
    maxWeight: 0,
    weight: 0,
    openKey: 'TAB',
    equipped: null,
    labels: {},
    categories: new Map(),
    filter: 'all',
    search: '',
    items: new Map(),
};

const el = {
    inventory: document.getElementById('inventory'),
    title: document.getElementById('title'),
    search: document.getElementById('search'),
    qty: document.getElementById('qty'),
    weightText: document.getElementById('weight-text'),
    weightFill: document.getElementById('weight-fill'),
    slotsText: document.getElementById('slots-text'),
    tabs: document.getElementById('tabs'),
    hotbarTitle: document.getElementById('hotbar-title'),
    hotbarHint: document.getElementById('hotbar-hint'),
    hotbarGrid: document.getElementById('hotbar-grid'),
    inventoryTitle: document.getElementById('inventory-title'),
    inventoryHint: document.getElementById('inventory-hint'),
    grid: document.getElementById('grid'),
    close: document.getElementById('close'),
    popup: document.getElementById('hotbar-popup'),
    menu: document.getElementById('menu'),
    menuUse: document.getElementById('menu-use'),
    tooltip: document.getElementById('tooltip'),
};

let drag = null;
let menuSlot = null;
let popupTimer = null;

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => null);
}

function formatWeight(grams) {
    return grams >= 1000 ? `${(grams / 1000).toFixed(2)} kg` : `${grams} g`;
}

// '#f5c542' -> 'rgba(245, 197, 66, alpha)'
function tint(hex, alpha) {
    const value = parseInt(hex.replace('#', ''), 16);
    return `rgba(${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}, ${alpha})`;
}

// city_ui's theme.lua: { accentText = '#15181d' } -> --accent-text: #15181d
function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

function createElement(tag, className, text) {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function slotElements(slot) {
    return document.querySelectorAll(`.slot[data-slot="${slot}"]`);
}

function matchesFilter(item) {
    if (state.filter !== 'all' && item.category !== state.filter) return false;
    return !state.search || item.label.toLowerCase().includes(state.search);
}

function renderSlot(slotEl) {
    const slot = Number(slotEl.dataset.slot);
    const item = state.items.get(slot);
    const isHotbar = slot <= state.hotbar;
    const inPanel = el.inventory.contains(slotEl);

    slotEl.replaceChildren();
    slotEl.classList.toggle('slot--filled', Boolean(item));
    slotEl.classList.toggle('slot--equipped', Boolean(item?.metadata?.serial) && item.metadata.serial === state.equipped);
    slotEl.classList.toggle('slot--dimmed', Boolean(item) && inPanel && !matchesFilter(item));

    const category = item && state.categories.get(item.category);
    for (const [name, value] of [
        ['--category', category?.color],
        ['--category-tint', category && tint(category.color, 0.22)],
        ['--category-strong', category && tint(category.color, 0.5)],
        ['--category-glow', category && tint(category.color, 0.7)],
    ]) {
        if (value) slotEl.style.setProperty(name, value);
        else slotEl.style.removeProperty(name);
    }

    if (!item) {
        if (isHotbar) slotEl.append(createElement('span', 'slot__watermark', String(slot)));
        return;
    }

    if (isHotbar) slotEl.append(createElement('span', 'slot__key', String(slot)));
    if (item.count > 1) slotEl.append(createElement('span', 'slot__count', `${item.count}x`));

    const ammo = item.metadata?.ammo;
    if (typeof ammo === 'number') slotEl.append(createElement('span', 'slot__ammo', String(ammo)));

    const image = createElement('img', 'slot__image');
    image.src = `images/${item.image}`;
    image.alt = '';
    image.onerror = () => image.remove();

    slotEl.append(image, createElement('span', 'slot__label', item.label));

    if (typeof ammo === 'number' && item.clip) {
        const bar = createElement('div', 'slot__bar');
        const fill = createElement('div', 'slot__bar-fill');
        fill.style.width = `${Math.min(100, (ammo / item.clip) * 100)}%`;
        bar.append(fill);
        slotEl.append(bar);
    }
}

function renderAllSlots() {
    for (const slotEl of document.querySelectorAll('.slot')) renderSlot(slotEl);
}

function createSlot(slot, container) {
    const slotEl = createElement('div', 'slot');
    slotEl.dataset.slot = slot;
    container.append(slotEl);
    renderSlot(slotEl);
}

function buildGrids() {
    el.hotbarGrid.replaceChildren();
    el.grid.replaceChildren();
    el.popup.replaceChildren();

    for (let slot = 1; slot <= state.hotbar; slot++) {
        createSlot(slot, el.hotbarGrid);
        createSlot(slot, el.popup);
    }

    for (let slot = state.hotbar + 1; slot <= state.slots; slot++) createSlot(slot, el.grid);
}

function buildTabs() {
    el.tabs.replaceChildren();

    const tabs = [['all', state.labels.all], ...[...state.categories].map(([name, category]) => [name, category.label])];

    for (const [name, label] of tabs) {
        const tab = createElement('button', 'tab', label);
        tab.type = 'button';
        tab.dataset.filter = name;
        tab.classList.toggle('tab--active', name === state.filter);
        el.tabs.append(tab);
    }
}

function renderCapacity() {
    const ratio = state.maxWeight > 0 ? Math.min(1, state.weight / state.maxWeight) : 0;
    const slotsText = `${state.items.size} / ${state.slots} ${state.labels.slots}`;

    el.weightText.textContent = `${formatWeight(state.weight)} / ${formatWeight(state.maxWeight)}`;
    el.weightFill.style.width = `${ratio * 100}%`;
    el.weightFill.classList.toggle('capacity__fill--full', ratio >= 1);
    el.slotsText.textContent = slotsText;
    el.inventoryHint.textContent = slotsText;
}

function applyEntries(entries) {
    for (const { slot, item } of entries) {
        if (item) {
            state.items.set(slot, item);
        } else {
            state.items.delete(slot);
        }

        for (const slotEl of slotElements(slot)) renderSlot(slotEl);
    }
}

function hideMenus() {
    el.menu.classList.add('hidden');
    el.tooltip.classList.add('hidden');
    menuSlot = null;
}

function cancelDrag() {
    if (drag?.ghost) drag.ghost.remove();
    drag = null;
}

function showPopup(activeSlot) {
    for (const slotEl of el.popup.children) {
        slotEl.classList.toggle('slot--active', Number(slotEl.dataset.slot) === activeSlot);
    }

    el.popup.classList.remove('hidden');
    clearTimeout(popupTimer);
    popupTimer = setTimeout(() => el.popup.classList.add('hidden'), HOTBAR_VISIBLE_MS);
}

function showTooltip(slot, x, y) {
    const item = state.items.get(slot);
    if (!item || drag) return el.tooltip.classList.add('hidden');

    const lines = [createElement('div', 'tooltip__title', item.label)];

    const category = state.categories.get(item.category);
    if (category) {
        const categoryLine = createElement('div', 'tooltip__category', category.label);
        categoryLine.style.color = category.color;
        lines.push(categoryLine);
    }

    if (item.description) lines.push(createElement('div', 'tooltip__line', item.description));
    lines.push(createElement('div', 'tooltip__line', formatWeight(item.weight)));
    if (typeof item.metadata?.ammo === 'number') lines.push(createElement('div', 'tooltip__line', `${state.labels.ammo}: ${item.metadata.ammo}`));
    if (item.metadata?.serial) lines.push(createElement('div', 'tooltip__line', `#${item.metadata.serial}`));

    el.tooltip.replaceChildren(...lines);
    el.tooltip.style.left = `${x + 14}px`;
    el.tooltip.style.top = `${y + 14}px`;
    el.tooltip.classList.remove('hidden');
}

function slotFromEvent(event) {
    const slotEl = event.target.closest?.('.slot');
    return slotEl && el.inventory.contains(slotEl) ? Number(slotEl.dataset.slot) : null;
}

// Shift moves half the stack, ctrl moves one, otherwise the Qty field or the whole stack
function dragCount(event, item) {
    if (event.shiftKey) return Math.max(1, Math.floor(item.count / 2));
    if (event.ctrlKey) return 1;

    const qty = Number.parseInt(el.qty.value, 10);
    return qty > 0 ? Math.min(qty, item.count) : item.count;
}

el.inventory.addEventListener('pointerdown', (event) => {
    if (event.button !== 0) return;

    const slot = slotFromEvent(event);
    const item = slot && state.items.get(slot);
    if (!item) return;

    hideMenus();
    drag = { slot, item, x: event.clientX, y: event.clientY, ghost: null };
});

document.addEventListener('pointermove', (event) => {
    if (!drag) {
        const slot = slotFromEvent(event);
        return slot ? showTooltip(slot, event.clientX, event.clientY) : el.tooltip.classList.add('hidden');
    }

    if (!drag.ghost) {
        if (Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < DRAG_THRESHOLD_PX) return;

        drag.ghost = createElement('div', 'slot ghost');
        drag.ghost.dataset.slot = drag.slot;
        document.body.append(drag.ghost);
        renderSlot(drag.ghost);
        el.tooltip.classList.add('hidden');
    }

    drag.ghost.style.transform = `translate(${event.clientX}px, ${event.clientY}px)`;
});

document.addEventListener('pointerup', (event) => {
    if (!drag) return;

    const { slot, item, ghost } = drag;
    cancelDrag();
    if (!ghost) return;

    const target = document.elementFromPoint(event.clientX, event.clientY)?.closest('.slot');
    const toSlot = target && el.inventory.contains(target) ? Number(target.dataset.slot) : null;
    if (!toSlot || toSlot === slot) return;

    post('move', { from: slot, to: toSlot, count: dragCount(event, item) });
});

el.inventory.addEventListener('dblclick', (event) => {
    const slot = slotFromEvent(event);
    if (slot && state.items.has(slot)) post('use', { slot });
});

el.inventory.addEventListener('contextmenu', (event) => {
    event.preventDefault();

    const slot = slotFromEvent(event);
    const item = slot && state.items.get(slot);
    if (!item) return hideMenus();

    menuSlot = slot;
    el.menuUse.textContent = item.weapon ? state.labels.equip : state.labels.use;
    el.tooltip.classList.add('hidden');
    el.menu.style.left = `${event.clientX}px`;
    el.menu.style.top = `${event.clientY}px`;
    el.menu.classList.remove('hidden');
});

el.menu.addEventListener('click', (event) => {
    const action = event.target.dataset.action;
    if (action && menuSlot) post(action, { slot: menuSlot });
    hideMenus();
});

el.tabs.addEventListener('click', (event) => {
    const filter = event.target.dataset?.filter;
    if (!filter) return;

    state.filter = filter;
    for (const tab of el.tabs.children) tab.classList.toggle('tab--active', tab.dataset.filter === filter);
    renderAllSlots();
});

el.search.addEventListener('input', () => {
    state.search = el.search.value.trim().toLowerCase();
    renderAllSlots();
});

el.close.addEventListener('click', () => post('close'));

document.addEventListener('click', (event) => {
    if (!el.menu.contains(event.target)) el.menu.classList.add('hidden');
});

document.addEventListener('keydown', (event) => {
    if (el.inventory.classList.contains('hidden')) return;

    // While typing in search or Qty, only Escape closes
    const typing = event.target instanceof HTMLInputElement;

    if (event.key === 'Escape' || (!typing && event.key.toUpperCase() === state.openKey.toUpperCase())) {
        event.preventDefault();
        post('close');
    }
});

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'setup':
            applyTheme(data.theme);
            state.slots = data.slots;
            state.hotbar = data.hotbar;
            state.maxWeight = data.maxWeight;
            state.weight = data.weight;
            state.openKey = data.openKey;
            state.equipped = data.equipped || null;
            state.labels = data.labels;
            state.categories = new Map((data.categories || []).map((category) => [category.name, category]));
            state.items.clear();
            for (const { slot, item } of data.items) if (item) state.items.set(slot, item);

            el.title.textContent = data.labels.title;
            el.hotbarTitle.textContent = data.labels.hotbar;
            el.hotbarHint.textContent = data.labels.hotbarHint;
            el.inventoryTitle.textContent = data.labels.title;
            el.search.placeholder = data.labels.search;
            el.qty.placeholder = data.labels.qty;
            buildTabs();
            buildGrids();
            renderCapacity();
            break;

        case 'update':
            state.weight = data.weight;
            applyEntries(data.changes);
            renderCapacity();
            break;

        case 'open':
            el.popup.classList.add('hidden');
            el.inventory.classList.remove('hidden');
            el.close.classList.remove('hidden');
            break;

        case 'close':
            cancelDrag();
            hideMenus();
            el.search.blur();
            el.qty.blur();
            el.inventory.classList.add('hidden');
            el.close.classList.add('hidden');
            break;

        case 'hotbar':
            showPopup(data.slot);
            break;

        case 'equipped':
            state.equipped = data.serial || null;
            renderAllSlots();
            break;
    }
});

post('ready');
