import { state, el, ui, itemAt } from './state.js';
import { createElement, post } from './util.js';
import { openDialog } from './dialog.js';

// Most of one item bought at once when the shop has no stock limit
const MAX_BUY = 100;

const HOTBAR_VISIBLE_MS = 1500;

let popupTimer = null;

export function hideMenus() {
    el.menu.classList.add('hidden');
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

// What can be done with the item in a slot: { label, action, name? }. Used by the right-click menu and the item card.
export function actionsFor(inv, slot) {
    const item = itemAt(inv, slot);
    if (!item) return [];

    // Only the player's own items and shop items have actions; stash, ground and trade items have to be moved first
    if (inv !== 'player') {
        return inv === 'other' && item.price !== undefined && item.stock !== 0 ? [{ label: state.labels.buy, action: 'buy' }] : [];
    }

    const actions = [{ label: item.weapon ? state.labels.equip : state.labels.use, action: 'use' }];

    if (item.count > 1) actions.push({ label: state.labels.split, action: 'split' });
    if (item.weapon && item.metadata?.ammo > 0) actions.push({ label: state.labels.unload, action: 'unload' });

    for (const name of item.metadata?.components || []) {
        const label = state.componentLabels[name] || name;
        actions.push({ label: state.labels.remove.replace('%s', label), action: 'detach', name });
    }

    return actions;
}

export function runAction({ inv, slot }, action, name) {
    if (action === 'buy') return askBuy(slot, null);
    if (action === 'split') return askSplit(slot);
    if (inv === 'player') post(action, { slot, name });
}

export function showMenu(inv, slot, x, y) {
    const actions = actionsFor(inv, slot);
    if (!actions.length) return hideMenus();

    el.menu.replaceChildren(...actions.map(({ label, action, name }) => {
        const entry = createElement('li', 'menu__item', label);
        entry.dataset.action = action;
        if (name) entry.dataset.name = name;
        return entry;
    }));

    ui.menuSlot = { inv, slot };
    el.menu.style.left = `${x}px`;
    el.menu.style.top = `${y}px`;
    el.menu.classList.remove('hidden');
}

el.menu.addEventListener('click', (event) => {
    const { action, name } = event.target.dataset;
    const target = ui.menuSlot;
    hideMenus();
    if (action && target) runAction(target, action, name);
});

document.addEventListener('click', (event) => {
    if (!el.menu.contains(event.target)) el.menu.classList.add('hidden');
});
