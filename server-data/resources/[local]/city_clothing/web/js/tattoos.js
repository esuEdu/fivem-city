// Tattoo tabs: a zone holds any number of tattoos ({ name, opacity }), each card adds or takes one off.
// A new tattoo costs the tab's price; removing one or changing its intensity is free (the server prices it again).
import { el, range } from './util.js';

export const asList = (value) => (Array.isArray(value) ? value : []);

const byName = (list) => new Map(asList(list).map((t) => [t.name, t]));

export function labelOf(category, name) {
    return category.items.find((item) => item.name === name)?.label || name;
}

/**
 * Cards for a tattoo zone, filtered by name
 * @param {object} ctx { s, picture(category, name), toggle(category, name) }
 */
export function tattooCards(category, filter, ctx) {
    const { s } = ctx;
    const now = byName(s.values[category.id]);
    const was = byName(s.original[category.id]);
    const text = filter.toLowerCase();

    return category.items
        .filter((item) => !text || item.label.toLowerCase().includes(text))
        .map((item) => {
            const node = el('button', 'card');
            node.type = 'button';
            node.dataset.name = item.name;

            const pic = el('div', 'card__pic');
            const url = ctx.picture(category, item.name);
            if (url) {
                const img = document.createElement('img');
                img.loading = 'lazy';
                img.alt = '';
                img.src = url;
                img.onerror = () => { img.remove(); pic.append(el('span', 'card__none', 'No picture')); };
                pic.append(img);
            } else {
                pic.append(el('span', 'card__none', 'No picture'));
            }

            node.append(pic, el('span', 'card__label card__label--name', item.label));
            node.classList.toggle('is-active', now.has(item.name));
            if (was.has(item.name)) node.append(el('span', 'card__owned', 'Yours'));

            node.addEventListener('click', () => ctx.toggle(category, item.name));
            return node;
        });
}

/**
 * The tattoos on this zone, each with its intensity and a remove button
 */
export function tattooOptions(category, ctx) {
    const { s } = ctx;
    const list = asList(s.values[category.id]);
    if (!list.length) return [];

    const nodes = [el('span', 'swatch-group__label', `On this zone (${list.length})`)];

    list.forEach((tattoo) => {
        const row = el('div', 'tattoo-row');
        const remove = el('button', 'bag-row__undo', '×');
        remove.type = 'button';
        remove.title = 'Take off';
        remove.addEventListener('click', () => ctx.toggle(category, tattoo.name));

        const slider = range({
            label: labelOf(category, tattoo.name),
            value: tattoo.opacity,
            min: 10,
            step: 10,
            onInput: (opacity) => ctx.setOpacity(category, tattoo.name, opacity),
        });

        row.append(slider, remove);
        nodes.push(row);
    });

    return nodes;
}

/**
 * Bag lines for a zone: new tattoos (priced), removed ones and intensity changes (free)
 */
export function tattooBagLines(category, s) {
    const now = byName(s.values[category.id]);
    const was = byName(s.original[category.id]);
    const lines = [];

    now.forEach((tattoo, name) => {
        if (!was.has(name)) {
            lines.push({ category, name, label: labelOf(category, name), note: 'New', price: category.price });
        } else if (was.get(name).opacity !== tattoo.opacity) {
            lines.push({ category, name, label: labelOf(category, name), note: 'Intensity', price: 0 });
        }
    });

    was.forEach((_, name) => {
        if (!now.has(name)) lines.push({ category, name, label: labelOf(category, name), note: 'Removed', price: 0 });
    });

    return lines;
}

/**
 * A zone's list with one tattoo put back as it was when the shop opened (or taken off if it is new)
 */
export function putBack(category, name, s) {
    const was = byName(s.original[category.id]);
    const list = asList(s.values[category.id]).filter((t) => t.name !== name);
    if (was.has(name)) list.push({ ...was.get(name) });
    return list;
}
