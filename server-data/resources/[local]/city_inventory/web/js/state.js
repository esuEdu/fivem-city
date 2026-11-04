// What the page shows. Every change comes from the client script; clicks only ask for changes.

function inventory() {
    return { slots: 0, maxWeight: 0, weight: 0, items: new Map() };
}

export const state = {
    hotbar: 0,
    openKey: 'TAB',
    equipped: null,
    labels: {},
    // Metadata fields other scripts asked to show (ox_inventory's displayMetadata), key -> label
    metadataLabels: {},
    categories: new Map(),
    // 'a|b' item name pairs (lowercase, sorted) that make something together (Config.Recipes)
    recipes: new Set(),
    componentLabels: {},
    filter: 'all',
    search: '',
    // The player's inventory and the stash open next to it, keyed like the slots' data-inv
    player: inventory(),
    other: { ...inventory(), open: false, label: '', kind: 'stash' },
};

// Drag in progress, the slot the right-click menu is for and the slot whose card is open ({ inv, slot })
export const ui = {
    drag: null,
    menuSlot: null,
    selected: null,
};

const byId = (id) => document.getElementById(id);

export const el = {
    inventory: byId('inventory'),
    other: byId('other'),
    title: byId('title'),
    otherTitle: byId('other-title'),
    otherCapacity: byId('other-capacity'),
    search: byId('search'),
    qty: byId('qty'),
    tabs: byId('tabs'),
    grid: byId('grid'),
    otherGrid: byId('other-grid'),
    close: byId('close'),
    popup: byId('hotbar-popup'),
    menu: byId('menu'),
    card: {
        root: byId('card'),
        close: byId('card-close'),
        image: byId('card-image'),
        title: byId('card-title'),
        chips: byId('card-chips'),
        rows: byId('card-rows'),
        actions: byId('card-actions'),
    },
    dialog: {
        root: byId('dialog'),
        title: byId('dialog-title'),
        image: byId('dialog-image'),
        label: byId('dialog-label'),
        input: byId('dialog-input'),
        minus: byId('dialog-minus'),
        plus: byId('dialog-plus'),
        max: byId('dialog-max'),
        total: byId('dialog-total'),
        cancel: byId('dialog-cancel'),
        confirm: byId('dialog-confirm'),
    },
    capacity: {
        player: { weight: byId('weight-text'), fill: byId('weight-fill'), slots: byId('slots-text') },
        other: { weight: byId('other-weight-text'), fill: byId('other-weight-fill'), slots: byId('other-slots-text') },
    },
};

export function isShop() {
    return state.other.open && state.other.kind === 'shop';
}

export function itemAt(inv, slot) {
    return state[inv]?.items.get(slot);
}
