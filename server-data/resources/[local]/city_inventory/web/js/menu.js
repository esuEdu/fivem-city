import { state, el, ui, itemAt } from './state.js';
import { createElement, formatPrice, formatWeight, post } from './util.js';
import { openDialog } from './dialog.js';

// Most of one item bought at once when the shop has no stock limit
const MAX_BUY = 100;

const HOTBAR_VISIBLE_MS = 1500;

let popupTimer = null;

export function hideMenus() {
    el.menu.classList.add('hidden');
    el.tooltip.classList.add('hidden');
    ui.menuSlot = null;
}

export function showPopup(activeSlot) {
    for (const slotEl of el.popup.children) {
        slotEl.classList.toggle('slot--active', Number(slotEl.dataset.slot) === activeSlot);
    }

    el.popup.classList.remove('hidden');
    clearTimeout(popupTimer);
    popupTimer = setTimeout(() => el.popup.classList.add('hidden'), HOTBAR_VISIBLE_MS);
}

export function showTooltip(inv, slot, x, y) {
    const item = itemAt(inv, slot);
    if (!item || ui.drag) return el.tooltip.classList.add('hidden');

    const lines = [createElement('div', 'tooltip__title', item.metadata?.label || item.label)];

    const category = state.categories.get(item.category);
    if (category) {
        const categoryLine = createElement('div', 'tooltip__category', category.label);
        categoryLine.style.color = category.color;
        lines.push(categoryLine);
    }

    if (item.price !== undefined) lines.push(createElement('div', 'tooltip__line', formatPrice(item, state.labels)));

    const description = item.metadata?.description || item.description;
    if (description) lines.push(createElement('div', 'tooltip__line', description));
    lines.push(createElement('div', 'tooltip__line', formatWeight(item.weight)));
    if (typeof item.metadata?.ammo === 'number') lines.push(createElement('div', 'tooltip__line', `${state.labels.ammo}: ${item.metadata.ammo}`));
    if (item.metadata?.serial) lines.push(createElement('div', 'tooltip__line', `#${item.metadata.serial}`));

    const attachments = (item.metadata?.components || []).map((name) => state.componentLabels[name] || name);
    if (attachments.length) lines.push(createElement('div', 'tooltip__line', `${state.labels.attachments}: ${attachments.join(', ')}`));

    for (const [key, label] of Object.entries(state.metadataLabels)) {
        const value = item.metadata?.[key];
        if (value !== undefined && typeof value !== 'object') lines.push(createElement('div', 'tooltip__line', `${label}: ${value}`));
    }

    el.tooltip.replaceChildren(...lines);
    el.tooltip.style.left = `${x + 14}px`;
    el.tooltip.style.top = `${y + 14}px`;
    el.tooltip.classList.remove('hidden');
}

function menuItem(label, action, name) {
    const entry = createElement('li', 'menu__item', label);
    entry.dataset.action = action;
    if (name) entry.dataset.name = name;
    return entry;
}

// Buys from the shop slot into the player's inventory (toSlot, or wherever it fits), asking how many first
export function askBuy(shopSlot, toSlot) {
    const item = itemAt('other', shopSlot);
    if (!item || item.stock === 0) return;

    // Weapons don't stack, so they're bought one at a time
    const max = item.weapon ? 1 : Math.min(MAX_BUY, item.stock ?? MAX_BUY);
    const buy = (count) => post('transfer', { fromInv: 'other', from: shopSlot, toInv: 'player', to: toSlot, count });

    if (max === 1) return buy(1);

    openDialog({ title: state.labels.buy, confirmLabel: state.labels.buy, item, max, onConfirm: buy });
}

export function askSplit(slot) {
    const item = itemAt('player', slot);
    if (!item || item.count < 2) return;

    openDialog({
        title: state.labels.split,
        confirmLabel: state.labels.split,
        item,
        max: item.count - 1,
        onConfirm: (count) => post('split', { slot, count }),
    });
}

function placeMenu(entries, x, y) {
    el.menu.replaceChildren(...entries);
    el.tooltip.classList.add('hidden');
    el.menu.style.left = `${x}px`;
    el.menu.style.top = `${y}px`;
    el.menu.classList.remove('hidden');
}

export function showShopMenu(slot, x, y) {
    const item = itemAt('other', slot);
    if (!item || item.stock === 0) return hideMenus();

    ui.menuSlot = { inv: 'other', slot };
    placeMenu([menuItem(state.labels.buy, 'buy')], x, y);
}

// For the player's own items: stash items have to be taken out first
export function showMenu(slot, x, y) {
    const item = itemAt('player', slot);
    if (!item) return hideMenus();

    const entries = [menuItem(item.weapon ? state.labels.equip : state.labels.use, 'use')];

    if (item.count > 1) entries.push(menuItem(state.labels.split, 'split'));

    if (item.weapon && item.metadata?.ammo > 0) entries.push(menuItem(state.labels.unload, 'unload'));

    for (const name of item.metadata?.components || []) {
        const label = state.componentLabels[name] || name;
        entries.push(menuItem(state.labels.remove.replace('%s', label), 'detach', name));
    }

    ui.menuSlot = { inv: 'player', slot };
    placeMenu(entries, x, y);
}

el.menu.addEventListener('click', (event) => {
    const { action, name } = event.target.dataset;
    const target = ui.menuSlot;
    hideMenus();
    if (!action || !target) return;

    if (action === 'buy') return askBuy(target.slot, null);
    if (action === 'split') return askSplit(target.slot);

    post(action, { slot: target.slot, name });
});

document.addEventListener('click', (event) => {
    if (!el.menu.contains(event.target)) el.menu.classList.add('hidden');
});
