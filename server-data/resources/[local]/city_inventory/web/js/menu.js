import { state, el, ui, itemAt } from './state.js';
import { createElement, formatWeight, post } from './util.js';

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

// Only for the player's own items: stash items have to be taken out first
export function showMenu(slot, x, y) {
    const item = itemAt('player', slot);
    if (!item) return hideMenus();

    const entries = [menuItem(item.weapon ? state.labels.equip : state.labels.use, 'use')];

    if (item.weapon && item.metadata?.ammo > 0) entries.push(menuItem(state.labels.unload, 'unload'));

    for (const name of item.metadata?.components || []) {
        const label = state.componentLabels[name] || name;
        entries.push(menuItem(state.labels.remove.replace('%s', label), 'detach', name));
    }

    ui.menuSlot = slot;
    el.menu.replaceChildren(...entries);
    el.tooltip.classList.add('hidden');
    el.menu.style.left = `${x}px`;
    el.menu.style.top = `${y}px`;
    el.menu.classList.remove('hidden');
}

el.menu.addEventListener('click', (event) => {
    const { action, name } = event.target.dataset;
    if (action && ui.menuSlot) post(action, { slot: ui.menuSlot, name });
    hideMenus();
});

document.addEventListener('click', (event) => {
    if (!el.menu.contains(event.target)) el.menu.classList.add('hidden');
});
