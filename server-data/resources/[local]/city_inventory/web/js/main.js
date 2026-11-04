// Renders what the client sends and forwards clicks. Every change is decided by the server.

import { state, el, ui } from './state.js';
import { applyEntries, buildOtherGrid, buildPlayerGrids, renderAllSlots, renderCapacity, setItems } from './slots.js';
import { hideMenus, showPopup } from './menu.js';
import { cancelDrag } from './drag.js';
import { closeDialog, isDialogOpen } from './dialog.js';
import { hideCard, refreshCard } from './card.js';
import { clearTrade, setTrade } from './trade.js';
import { applyTheme, createElement, post } from './util.js';

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

function isOpen() {
    return !el.inventory.classList.contains('hidden');
}

// The right side shows the trade when there is one, otherwise the stash, shop or ground
function showOther() {
    el.trade.root.classList.toggle('hidden', !(state.trade.open && isOpen()));
    el.other.classList.toggle('hidden', !(state.other.open && !state.trade.open && isOpen()));
}

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

document.addEventListener('keydown', (event) => {
    if (!isOpen()) return;

    // Escape closes the amount window first, not the inventory
    if (isDialogOpen()) {
        if (event.key === 'Escape') closeDialog();
        return;
    }

    if (event.key === 'Escape' && ui.selected) {
        event.preventDefault();
        return hideCard();
    }

    // While typing in search or Qty, only Escape closes
    const typing = event.target instanceof HTMLInputElement;

    if (event.key === 'Escape' || (!typing && event.key.toUpperCase() === state.openKey.toUpperCase())) {
        event.preventDefault();
        post('close');
    }
});

const handlers = {
    setup(data) {
        applyTheme(data.theme);
        state.hotbar = data.hotbar;
        state.player.slots = data.slots;
        state.player.maxWeight = data.maxWeight;
        state.player.weight = data.weight;
        state.openKey = data.openKey;
        state.equipped = data.equipped || null;
        state.metadataLabels = data.metadataLabels || {};
        state.labels = data.labels;
        state.categories = new Map((data.categories || []).map((category) => [category.name, category]));
        state.recipes = new Set((data.recipes || []).map(([a, b]) => [a.toLowerCase(), b.toLowerCase()].sort().join('|')));
        state.componentLabels = data.componentLabels || {};
        setItems('player', data.items);

        el.title.textContent = data.labels.title;
        hideCard();
        el.search.placeholder = data.labels.search;
        el.qty.placeholder = data.labels.qty;
        buildTabs();
        buildPlayerGrids();
        renderCapacity('player');
    },

    update(data) {
        state.player.weight = data.weight;
        applyEntries('player', data.changes);
        renderCapacity('player');
        refreshCard('player');
    },

    setOther(data) {
        Object.assign(state.other, {
            open: true, kind: data.kind, label: data.label, slots: data.slots, maxWeight: data.maxWeight, weight: data.weight,
        });
        setItems('other', data.items);
        if (ui.selected?.inv === 'other') hideCard();

        el.otherTitle.textContent = data.label;
        el.otherCapacity.classList.toggle('hidden', data.kind === 'shop');
        buildOtherGrid();
        renderCapacity('other');
        showOther();
    },

    updateOther(data) {
        if (data.weight !== undefined) state.other.weight = data.weight;
        applyEntries('other', data.changes);
        renderCapacity('other');
        refreshCard('other');
    },

    setTrade(data) {
        // A trade replaces whatever was open next to the inventory
        if (state.other.open) handlers.clearOther();

        setTrade(data);
        refreshCard('offer');
        refreshCard('their');
        showOther();
    },

    clearTrade() {
        cancelDrag();
        closeDialog();
        if (ui.selected?.inv === 'offer' || ui.selected?.inv === 'their') hideCard();
        clearTrade();
        showOther();
    },

    clearOther() {
        if (state.other.open) cancelDrag();
        closeDialog();
        if (ui.selected?.inv === 'other') hideCard();
        state.other.open = false;
        state.other.items.clear();
        el.otherGrid.replaceChildren();
        showOther();
    },

    open() {
        el.popup.classList.add('hidden');
        el.inventory.classList.remove('hidden');
        el.close.classList.remove('hidden');
        showOther();
    },

    close() {
        cancelDrag();
        closeDialog();
        hideCard();
        hideMenus();
        el.search.blur();
        el.qty.blur();
        el.inventory.classList.add('hidden');
        el.close.classList.add('hidden');
        showOther();
    },

    hotbar(data) {
        showPopup(data.slot);
    },

    equipped(data) {
        state.equipped = data.serial || null;
        renderAllSlots();
    },

    displayMetadata(data) {
        state.metadataLabels = data.labels || {};
    },
};

window.addEventListener('message', ({ data }) => {
    if (Object.hasOwn(handlers, data.action)) handlers[data.action](data);
});

post('ready');
