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
    categories: {},
    items: new Map(),
};

const el = {
    inventory: document.getElementById('inventory'),
    title: document.getElementById('title'),
    weightText: document.getElementById('weight-text'),
    weightFill: document.getElementById('weight-fill'),
    grid: document.getElementById('grid'),
    hotbar: document.getElementById('hotbar'),
    menu: document.getElementById('menu'),
    menuUse: document.getElementById('menu-use'),
    tooltip: document.getElementById('tooltip'),
};

let drag = null;
let menuSlot = null;
let hotbarTimer = null;

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => null);
}

function formatWeight(grams) {
    return grams >= 1000 ? `${(grams / 1000).toFixed(1)} kg` : `${grams} g`;
}

// '#f5c542' -> 'rgba(245, 197, 66, alpha)'
function tint(hex, alpha) {
    const value = parseInt(hex.replace('#', ''), 16);
    return `rgba(${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}, ${alpha})`;
}

function createElement(tag, className, text) {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function renderSlot(slotEl) {
    const slot = Number(slotEl.dataset.slot);
    const item = state.items.get(slot);

    slotEl.replaceChildren();
    slotEl.classList.toggle('slot--filled', Boolean(item));
    slotEl.classList.toggle('slot--equipped', Boolean(item?.metadata?.serial) && item.metadata.serial === state.equipped);

    const category = item && state.categories[item.category];
    if (category) {
        slotEl.style.setProperty('--category', category.color);
        slotEl.style.setProperty('--category-tint', tint(category.color, 0.25));
    } else {
        slotEl.style.removeProperty('--category');
        slotEl.style.removeProperty('--category-tint');
    }

    if (slot <= state.hotbar) {
        slotEl.append(createElement('span', 'slot__key', String(slot)));
    }

    if (!item) return;

    const image = createElement('img', 'slot__image');
    image.src = `images/${item.image}`;
    image.alt = '';
    image.onerror = () => image.remove();

    slotEl.append(image, createElement('span', 'slot__label', item.label));

    if (item.count > 1) {
        slotEl.append(createElement('span', 'slot__count', `${item.count}x`));
    }
}

function createSlot(slot, container) {
    const slotEl = createElement('div', 'slot');
    slotEl.dataset.slot = slot;
    slotEl.classList.toggle('slot--hotbar', slot <= state.hotbar);
    container.append(slotEl);
    renderSlot(slotEl);
}

function buildGrids() {
    el.grid.replaceChildren();
    el.hotbar.replaceChildren();

    for (let slot = 1; slot <= state.slots; slot++) createSlot(slot, el.grid);
    for (let slot = 1; slot <= state.hotbar; slot++) createSlot(slot, el.hotbar);
}

function renderAllSlots() {
    for (const slotEl of document.querySelectorAll('.slot')) renderSlot(slotEl);
}

function renderWeight() {
    const ratio = state.maxWeight > 0 ? Math.min(1, state.weight / state.maxWeight) : 0;

    el.weightText.textContent = `${formatWeight(state.weight)} / ${formatWeight(state.maxWeight)}`;
    el.weightFill.style.width = `${ratio * 100}%`;
    el.weightFill.classList.toggle('weight-bar__fill--full', ratio >= 1);
}

function applyEntries(entries) {
    for (const { slot, item } of entries) {
        if (item) {
            state.items.set(slot, item);
        } else {
            state.items.delete(slot);
        }

        for (const slotEl of document.querySelectorAll(`.slot[data-slot="${slot}"]`)) renderSlot(slotEl);
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

function showHotbar(activeSlot) {
    for (const slotEl of el.hotbar.children) {
        slotEl.classList.toggle('slot--active', Number(slotEl.dataset.slot) === activeSlot);
    }

    el.hotbar.classList.remove('hidden');
    clearTimeout(hotbarTimer);
    hotbarTimer = setTimeout(() => el.hotbar.classList.add('hidden'), HOTBAR_VISIBLE_MS);
}

function showTooltip(slot, x, y) {
    const item = state.items.get(slot);
    if (!item || drag) return el.tooltip.classList.add('hidden');

    const lines = [createElement('div', 'tooltip__title', item.label)];

    const category = state.categories[item.category];
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
    return slotEl && el.grid.contains(slotEl) ? Number(slotEl.dataset.slot) : null;
}

el.grid.addEventListener('pointerdown', (event) => {
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

        drag.ghost = createElement('div', 'slot slot--filled ghost');
        drag.ghost.dataset.slot = drag.slot;
        renderSlot(drag.ghost);
        document.body.append(drag.ghost);
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
    const toSlot = target && el.grid.contains(target) ? Number(target.dataset.slot) : null;
    if (!toSlot || toSlot === slot) return;

    // Shift moves half the stack, ctrl moves one, otherwise the whole stack
    let count = item.count;
    if (event.shiftKey) count = Math.max(1, Math.floor(item.count / 2));
    else if (event.ctrlKey) count = 1;

    post('move', { from: slot, to: toSlot, count });
});

el.grid.addEventListener('dblclick', (event) => {
    const slot = slotFromEvent(event);
    if (slot && state.items.has(slot)) post('use', { slot });
});

el.grid.addEventListener('contextmenu', (event) => {
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

document.addEventListener('click', (event) => {
    if (!el.menu.contains(event.target)) el.menu.classList.add('hidden');
});

document.addEventListener('keydown', (event) => {
    if (el.inventory.classList.contains('hidden')) return;

    if (event.key === 'Escape' || event.key.toUpperCase() === state.openKey.toUpperCase()) {
        event.preventDefault();
        post('close');
    }
});

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'setup':
            state.slots = data.slots;
            state.hotbar = data.hotbar;
            state.maxWeight = data.maxWeight;
            state.weight = data.weight;
            state.openKey = data.openKey;
            state.equipped = data.equipped || null;
            state.labels = data.labels;
            state.categories = data.categories || {};
            state.items.clear();
            for (const { slot, item } of data.items) if (item) state.items.set(slot, item);

            el.title.textContent = data.labels.title;
            buildGrids();
            renderWeight();
            break;

        case 'update':
            state.weight = data.weight;
            applyEntries(data.changes);
            renderWeight();
            break;

        case 'open':
            el.hotbar.classList.add('hidden');
            el.inventory.classList.remove('hidden');
            break;

        case 'close':
            cancelDrag();
            hideMenus();
            el.inventory.classList.add('hidden');
            break;

        case 'hotbar':
            showHotbar(data.slot);
            break;

        case 'equipped':
            state.equipped = data.serial || null;
            renderAllSlots();
            break;
    }
});

post('ready');
