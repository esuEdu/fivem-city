import { state, el, ui, itemAt } from './state.js';
import { createElement, formatPrice, formatWeight, tint } from './util.js';
import { actionsFor, runAction } from './menu.js';

// The big card between the panels for the item the player clicked

function slotElement({ inv, slot }) {
    return document.querySelector(`.panel .slot[data-inv="${inv}"][data-slot="${slot}"]`);
}

function row(label, value) {
    const line = createElement('div', 'card__row');
    line.append(createElement('span', 'card__row-label', label), createElement('span', 'card__row-value', value));
    return line;
}

function meter(ratio) {
    const bar = createElement('div', 'card__meter');
    const fill = createElement('div', 'card__meter-fill');
    fill.style.width = `${Math.max(0, Math.min(1, ratio)) * 100}%`;
    bar.append(fill);
    return bar;
}

function render() {
    const item = itemAt(ui.selected.inv, ui.selected.slot);
    if (!item) return hideCard();

    const category = state.categories.get(item.category);
    el.card.root.style.setProperty('--category-tint', category ? tint(category.color, 0.22) : 'transparent');
    el.card.root.style.setProperty('--category-strong', category ? tint(category.color, 0.5) : 'transparent');

    el.card.image.src = `images/${item.image}`;
    el.card.title.textContent = item.metadata?.label || item.label;

    const chips = [];

    if (category) {
        const chip = createElement('span', 'chip', category.label);
        chip.style.color = category.color;
        chips.push(chip);
    }

    chips.push(createElement('span', 'chip', formatWeight(item.weight)));
    if (item.price === undefined) chips.push(createElement('span', 'chip', `x${item.count}`));
    chips.push(createElement('span', 'chip chip--mono', item.name));
    el.card.chips.replaceChildren(...chips);

    const rows = [];
    const description = item.metadata?.description || item.description;
    if (description) rows.push(createElement('p', 'card__text', description));

    if (item.price !== undefined) {
        rows.push(row(state.labels.price, formatPrice(item, state.labels)));
        if (typeof item.stock === 'number') rows.push(row(state.labels.stock, String(item.stock)));
    }

    const ammo = item.metadata?.ammo;
    if (typeof ammo === 'number') {
        rows.push(row(state.labels.ammo, item.clip ? `${ammo} / ${item.clip}` : String(ammo)));
        if (item.clip) rows.push(meter(ammo / item.clip));
    }

    if (item.metadata?.serial) rows.push(row(state.labels.serial, item.metadata.serial));

    const attachments = (item.metadata?.components || []).map((name) => state.componentLabels[name] || name);
    if (attachments.length) rows.push(row(state.labels.attachments, attachments.join(', ')));

    // Fields other scripts asked to show (ox_inventory's displayMetadata), e.g. the name on an ID card
    for (const [key, label] of Object.entries(state.metadataLabels)) {
        const value = item.metadata?.[key];
        if (value !== undefined && typeof value !== 'object') rows.push(row(label, String(value)));
    }

    el.card.rows.replaceChildren(...rows);

    el.card.actions.replaceChildren(...actionsFor(ui.selected.inv, ui.selected.slot).map(({ label, action, name }, index) => {
        const button = createElement('button', index === 0 ? 'button button--accent' : 'button', label);
        button.type = 'button';
        button.addEventListener('click', () => runAction(ui.selected, action, name));
        return button;
    }));

    el.card.root.classList.remove('hidden');
}

export function showCard(inv, slot) {
    const previous = ui.selected;
    ui.selected = { inv, slot };

    for (const target of [previous, ui.selected]) {
        if (target) slotElement(target)?.classList.toggle('slot--selected', target === ui.selected);
    }

    render();
}

export function hideCard() {
    if (ui.selected) slotElement(ui.selected)?.classList.remove('slot--selected');
    ui.selected = null;
    el.card.root.classList.add('hidden');
}

// Keeps the card up to date when the selected slot changes (used, moved, ammo fired)
export function refreshCard(inv) {
    if (ui.selected?.inv === inv) render();
}

el.card.close.addEventListener('click', hideCard);
