import { state, el, ui, itemAt, isShop } from './state.js';
import { renderSlot, slotOf } from './slots.js';
import { askBuy, hideMenus, showMenu, showShopMenu, showTooltip } from './menu.js';
import { isDialogOpen } from './dialog.js';
import { createElement, post } from './util.js';

const DRAG_THRESHOLD_PX = 5;

let combineTarget = null;

// The slot under the pointer, when it's in one of the open panels
function slotAt(target) {
    const slotEl = target?.closest?.('.slot');
    return slotEl && slotEl.closest('.panel') ? slotEl : null;
}

function pairKey(a, b) {
    [a, b] = [a.toLowerCase(), b.toLowerCase()];
    return a < b ? `${a}|${b}` : `${b}|${a}`;
}

// Mirrors the server's rules, only to pick between combine and move; the server decides
function combines(from, to) {
    if (!from || !to || from === to) return false;
    if (to.weapon && from.ammo && to.ammoname?.toLowerCase() === from.name.toLowerCase()) return true;
    if (to.weapon && from.component) return true;
    return state.recipes.has(pairKey(from.name, to.name));
}

function setCombineTarget(slotEl) {
    if (combineTarget === slotEl) return;
    combineTarget?.classList.remove('slot--combine');
    combineTarget = slotEl;
    combineTarget?.classList.add('slot--combine');
}

export function cancelDrag() {
    setCombineTarget(null);
    if (ui.drag?.ghost) ui.drag.ghost.remove();
    ui.drag = null;
}

// Shift moves half the stack, ctrl moves one, otherwise the Qty field or the whole stack
function dragCount(event, item) {
    if (event.shiftKey) return Math.max(1, Math.floor(item.count / 2));
    if (event.ctrlKey) return 1;

    const qty = Number.parseInt(el.qty.value, 10);
    return qty > 0 ? Math.min(qty, item.count) : item.count;
}

// Combining only works inside the player's own inventory
function combineSlot(slotEl) {
    if (!slotEl || ui.drag.inv !== 'player') return null;

    const { inv, slot } = slotOf(slotEl);
    if (inv !== 'player' || slot === ui.drag.slot) return null;

    return combines(ui.drag.item, itemAt(inv, slot)) ? slotEl : null;
}

function onPointerDown(event) {
    if (event.button !== 0 || isDialogOpen()) return;

    const slotEl = slotAt(event.target);
    if (!slotEl) return;

    const { inv, slot } = slotOf(slotEl);
    const item = itemAt(inv, slot);
    if (!item) return;

    hideMenus();
    ui.drag = { inv, slot, item, x: event.clientX, y: event.clientY, ghost: null };
}

el.inventory.addEventListener('pointerdown', onPointerDown);
el.other.addEventListener('pointerdown', onPointerDown);

document.addEventListener('pointermove', (event) => {
    const drag = ui.drag;

    if (!drag) {
        const slotEl = slotAt(event.target);
        if (!slotEl) return el.tooltip.classList.add('hidden');

        const { inv, slot } = slotOf(slotEl);
        return showTooltip(inv, slot, event.clientX, event.clientY);
    }

    if (!drag.ghost) {
        if (Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < DRAG_THRESHOLD_PX) return;

        drag.ghost = createElement('div', 'slot ghost');
        drag.ghost.dataset.inv = drag.inv;
        drag.ghost.dataset.slot = drag.slot;
        document.body.append(drag.ghost);
        renderSlot(drag.ghost);
        el.tooltip.classList.add('hidden');
    }

    drag.ghost.style.transform = `translate(${event.clientX}px, ${event.clientY}px)`;
    setCombineTarget(combineSlot(slotAt(document.elementFromPoint(event.clientX, event.clientY))));
});

document.addEventListener('pointerup', (event) => {
    const drag = ui.drag;
    if (!drag) return;

    const target = slotAt(document.elementFromPoint(event.clientX, event.clientY));
    const combine = drag.ghost && combineSlot(target);
    cancelDrag();
    if (!drag.ghost || !target) return;

    const { inv, slot } = slotOf(target);
    if (inv === drag.inv && slot === drag.slot) return;

    // Shops only sell: items come out of the shop panel. Ctrl buys one and the Qty field buys that many; otherwise ask
    if (isShop()) {
        if (drag.inv !== 'other' || inv !== 'player') return;

        const qty = Number.parseInt(el.qty.value, 10);
        if (!event.ctrlKey && !(qty > 0)) return askBuy(drag.slot, slot);

        return post('transfer', { fromInv: 'other', from: drag.slot, toInv: 'player', to: slot, count: event.ctrlKey ? 1 : qty });
    }

    const count = dragCount(event, drag.item);

    if (drag.inv === 'player' && inv === 'player') {
        post(combine ? 'combine' : 'move', { from: drag.slot, to: slot, count });
    } else {
        post('transfer', { fromInv: drag.inv, from: drag.slot, toInv: inv, to: slot, count });
    }
});

el.inventory.addEventListener('dblclick', (event) => {
    const slotEl = slotAt(event.target);
    if (!slotEl) return;

    const { slot } = slotOf(slotEl);
    if (itemAt('player', slot)) post('use', { slot });
});

el.inventory.addEventListener('contextmenu', (event) => {
    event.preventDefault();

    const slotEl = slotAt(event.target);
    if (!slotEl) return hideMenus();

    showMenu(slotOf(slotEl).slot, event.clientX, event.clientY);
});

el.other.addEventListener('contextmenu', (event) => {
    event.preventDefault();

    const slotEl = slotAt(event.target);
    if (!slotEl || !isShop()) return hideMenus();

    showShopMenu(slotOf(slotEl).slot, event.clientX, event.clientY);
});

// Double-clicking a shop item buys it too
el.other.addEventListener('dblclick', (event) => {
    const slotEl = slotAt(event.target);
    if (slotEl && isShop()) askBuy(slotOf(slotEl).slot, null);
});
