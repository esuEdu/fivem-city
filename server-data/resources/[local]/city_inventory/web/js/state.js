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
    // The player's inventory, the stash/shop/ground open next to it and both sides of a trade, keyed like the slots' data-inv
    player: inventory(),
    other: { ...inventory(), open: false, label: '', kind: 'stash' },
    offer: inventory(),
    their: inventory(),
    trade: { open: false, accepted: false, theirAccepted: false },
    // Rounds in the magazine of the gun in hand ({ serial, clip }), sent by the client while it's equipped
    liveClip: null,
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
    trade: {
        root: byId('trade'),
        title: byId('trade-title'),
        partner: byId('trade-partner'),
        cancel: byId('trade-cancel'),
        offerTitle: byId('offer-title'),
        offerStatus: byId('offer-status'),
        offerGrid: byId('offer-grid'),
        accept: byId('trade-accept'),
        theirTitle: byId('their-title'),
        theirStatus: byId('their-status'),
        theirGrid: byId('their-grid'),
    },
    search: byId('search'),
    qty: byId('qty'),
    tabs: byId('tabs'),
    hotbarGrid: byId('hotbar-grid'),
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

// A gun's rounds split into the magazine and the spare rounds it carries (16/128). A holstered gun's magazine is full
// when it's drawn, so only the gun in hand needs the live count.
export function gunAmmo(item) {
    const total = item.metadata?.ammo;
    if (typeof total !== 'number') return null;
    if (!item.clip) return { inClip: total, spare: 0 };

    const live = state.liveClip;
    const inClip = live && live.serial === item.metadata.serial ? Math.min(live.clip, total) : Math.min(total, item.clip);

    return { inClip, spare: total - inClip };
}

export function itemAt(inv, slot) {
    return state[inv]?.items.get(slot);
}
