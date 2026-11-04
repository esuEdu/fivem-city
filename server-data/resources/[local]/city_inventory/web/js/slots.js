import { state, el, ui, itemAt } from './state.js';
import { createElement, formatPrice, formatWeight, tint } from './util.js';

function matchesFilter(item) {
    if (state.filter !== 'all' && item.category !== state.filter) return false;
    return !state.search || item.label.toLowerCase().includes(state.search);
}

// A slot element's inventory ('player' or 'other') and slot number
export function slotOf(slotEl) {
    return { inv: slotEl.dataset.inv, slot: Number(slotEl.dataset.slot) };
}

export function renderSlot(slotEl) {
    const { inv, slot } = slotOf(slotEl);
    const item = itemAt(inv, slot);
    const isHotbar = inv === 'player' && slot <= state.hotbar;
    const inPanel = Boolean(slotEl.closest('.panel'));

    slotEl.replaceChildren();
    slotEl.classList.toggle('slot--filled', Boolean(item));
    slotEl.classList.toggle('slot--equipped', inv === 'player' && Boolean(item?.metadata?.serial) && item.metadata.serial === state.equipped);
    slotEl.classList.toggle('slot--dimmed', Boolean(item) && inPanel && !matchesFilter(item));
    slotEl.classList.toggle('slot--sold-out', item?.stock === 0);
    slotEl.classList.toggle('slot--selected', Boolean(item) && ui.selected?.inv === inv && ui.selected?.slot === slot && inPanel);

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

    // Top left: how many (or the stock left in a shop). Top right: ammo, shop price, hotbar key
    const count = item.price !== undefined ? item.stock : item.count;
    if (typeof count === 'number' && (count > 1 || item.price !== undefined)) slotEl.append(createElement('span', 'slot__count', String(count)));

    const corner = createElement('div', 'slot__corner');
    const ammo = item.metadata?.ammo;
    if (typeof ammo === 'number') corner.append(createElement('span', 'slot__ammo', String(ammo)));
    if (item.price !== undefined) corner.append(createElement('span', 'slot__price', formatPrice(item, state.labels)));
    if (isHotbar) corner.append(createElement('span', 'slot__key', String(slot)));
    if (corner.childElementCount) slotEl.append(corner);

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

export function renderAllSlots() {
    for (const slotEl of document.querySelectorAll('.slot')) renderSlot(slotEl);
}

function createSlot(inv, slot, container) {
    const slotEl = createElement('div', 'slot');
    slotEl.dataset.inv = inv;
    slotEl.dataset.slot = slot;
    container.append(slotEl);
    renderSlot(slotEl);
}

// One grid; its first slots are the hotbar (keys 1-5), also shown in the popup when a key is pressed
export function buildPlayerGrids() {
    el.grid.replaceChildren();
    el.popup.replaceChildren();

    for (let slot = 1; slot <= state.hotbar; slot++) createSlot('player', slot, el.popup);
    for (let slot = 1; slot <= state.player.slots; slot++) createSlot('player', slot, el.grid);
}

export function buildOtherGrid() {
    el.otherGrid.replaceChildren();

    for (let slot = 1; slot <= state.other.slots; slot++) createSlot('other', slot, el.otherGrid);
}

export function renderCapacity(inv) {
    if (inv === 'other' && state.other.kind === 'shop') return;

    const { weight, maxWeight, items, slots } = state[inv];
    const target = el.capacity[inv];
    const ratio = maxWeight > 0 ? Math.min(1, weight / maxWeight) : 0;
    const slotsText = `${items.size} / ${slots} ${state.labels.slots}`;

    target.weight.textContent = `${formatWeight(weight)} / ${formatWeight(maxWeight)}`;
    target.fill.style.width = `${ratio * 100}%`;
    target.fill.classList.toggle('capacity__fill--full', ratio >= 1);
    target.slots.textContent = slotsText;
}

// Replaces whole inventory contents from a list of { slot, item }
export function setItems(inv, entries) {
    state[inv].items.clear();
    for (const { slot, item } of entries) if (item) state[inv].items.set(slot, item);
}

export function applyEntries(inv, entries) {
    for (const { slot, item } of entries) {
        if (item) {
            state[inv].items.set(slot, item);
        } else {
            state[inv].items.delete(slot);
        }

        for (const slotEl of document.querySelectorAll(`.slot[data-inv="${inv}"][data-slot="${slot}"]`)) renderSlot(slotEl);
    }
}
