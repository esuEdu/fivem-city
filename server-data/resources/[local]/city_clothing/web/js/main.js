import { RESOURCE, post, applyTheme, el, money, confirmModal, stepper, range, swatches } from './util.js';
import { asList, tattooCards, tattooOptions, tattooBagLines, putBack } from './tattoos.js';
import { stageControls } from './stage.js';

const shop = document.getElementById('shop');
const stage = document.getElementById('stage');
const tabs = document.getElementById('tabs');
const kicker = document.getElementById('kicker');
const title = document.getElementById('title');
const priceTag = document.getElementById('price');
const search = document.getElementById('search');
const grid = document.getElementById('grid');
const options = document.getElementById('options');
const bagList = document.getElementById('bag-list');
const bagCount = document.getElementById('bag-count');
const bagTotal = document.getElementById('bag-total');
const payCash = document.getElementById('pay-cash');
const payBank = document.getElementById('pay-bank');

const LOOKS_TAB = 'looks';
const STORE_NAMES = { clothing: 'Clothing store', barber: 'Barber', tattoo: 'Tattoo parlor' };

let s = null;

// Key order differs between Lua's JSON and the page's objects, so compare field by field
const same = (a, b) => (a.opacity === 0 && b.opacity === 0)
    || Object.keys({ ...a, ...b }).every((key) => a[key] === b[key]);
// Picture keys: c<component>, p<prop>, o<overlay>, t<tab id> for tattoos (pictures keyed by tattoo name)
const keyOf = (c) => (c.kind === 'tattoo' ? `t${c.id}` : `${c.kind === 'prop' ? 'p' : c.kind === 'overlay' ? 'o' : 'c'}${c.slot}`);
const imageName = (c, drawable) => `${s.sex}_${keyOf(c)}_${drawable}`;

// A hand-made .png dropped into images/ wins over the photo tool's picture (kept in the tab's pack)
function pictureOf(category, style) {
    const name = imageName(category, style);
    if (s.custom[name]) return `https://cfx-nui-${RESOURCE}/images/${name}.png`;
    return s.packs[`${s.sex}_${keyOf(category)}`]?.[String(style)] || null;
}

// One file per sex and tab with every picture of it, fetched the first time the tab opens
async function loadPack(category) {
    const key = `${s.sex}_${keyOf(category)}`;
    if (s.packs[key]) return;

    try {
        const response = await fetch(`https://cfx-nui-${RESOURCE}/images/pack_${key}.json`);
        s.packs[key] = response.ok ? await response.json() : {};
    } catch {
        s.packs[key] = {};
    }
}

// The style number a card stands for: -1 / none for props and overlays
function styleOf(category, value) {
    if (category.kind === 'hair') return value.style;
    if (category.kind === 'overlay') return value.opacity > 0 ? value.style : -1;
    return value.drawable;
}

function hasNone(category) {
    return category.kind === 'prop' || category.kind === 'overlay';
}

// ---------- preview ----------

function setValue(category, value) {
    s.values[category.id] = value;
    post('preview', { id: category.id, value });
    renderBag();
}

async function pick(category, style) {
    const current = s.values[category.id];
    let value;

    if (category.kind === 'component') {
        value = { drawable: style, texture: 0 };
    } else if (category.kind === 'prop') {
        value = style < 0 ? { drawable: -1, texture: -1 } : { drawable: style, texture: 0 };
    } else if (category.kind === 'hair') {
        value = { ...current, style, texture: 0 };
    } else {
        const opacity = style < 0 ? 0 : (current.opacity > 0 ? current.opacity : 1);
        value = { ...current, style: Math.max(style, 0), opacity };
    }

    setValue(category, value);
    grid.querySelectorAll('.card').forEach((card) => card.classList.toggle('is-active', Number(card.dataset.style) === style));
    await renderOptions(category);
}

function toggleTattoo(category, name) {
    const list = asList(s.values[category.id]);
    const next = list.some((t) => t.name === name)
        ? list.filter((t) => t.name !== name)
        : [...list, { name, opacity: 1 }];

    setValue(category, next);
    renderGrid(category);
    renderOptions(category);
}

function setTattooOpacity(category, name, opacity) {
    setValue(category, asList(s.values[category.id]).map((t) => (t.name === name ? { ...t, opacity } : t)));
}

const tattooContext = () => ({ s, picture: pictureOf, toggle: toggleTattoo, setOpacity: setTattooOpacity });

// ---------- browse panel ----------

function card(category, style) {
    const node = el('button', 'card');
    node.type = 'button';
    node.dataset.style = String(style);

    const pic = el('div', 'card__pic');
    if (style < 0) {
        pic.append(el('span', 'card__none', 'None'));
    } else if (pictureOf(category, style)) {
        const img = document.createElement('img');
        img.loading = 'lazy';
        img.alt = '';
        img.src = pictureOf(category, style);
        img.onerror = () => { img.remove(); pic.append(el('span', 'card__number', String(style + 1))); };
        pic.append(img);
    } else {
        pic.append(el('span', 'card__number', String(style + 1)));
    }

    node.append(pic, el('span', 'card__label', style < 0 ? 'None' : `#${style + 1}`));

    const current = styleOf(category, s.values[category.id]);
    const original = styleOf(category, s.original[category.id]);
    node.classList.toggle('is-active', style === current);
    if (style === original) node.append(el('span', 'card__owned', 'Wearing'));

    node.addEventListener('click', () => pick(category, style));
    return node;
}

function renderGrid(category) {
    grid.replaceChildren();
    const filter = search.value.trim();

    if (category.kind === 'tattoo') {
        const cards = tattooCards(category, filter, tattooContext());
        if (cards.length) grid.append(...cards);
        else grid.append(el('p', 'muted empty', filter ? 'No tattoo with that name.' : 'No tattoos here for you.'));
        return;
    }

    const list = [];

    if (hasNone(category) && !filter) list.push(-1);
    for (let i = 0; i < category.count; i += 1) {
        if (!filter || String(i + 1).startsWith(filter)) list.push(i);
    }

    if (!list.length) {
        grid.append(el('p', 'muted empty', 'Nothing with that number.'));
        return;
    }

    list.forEach((style) => grid.append(card(category, style)));
    requestAnimationFrame(() => grid.querySelector('.is-active')?.scrollIntoView({ block: 'nearest' }));
}

async function renderOptions(category) {
    options.replaceChildren();
    const value = s.values[category.id];

    if (category.kind === 'tattoo') {
        options.append(...tattooOptions(category, tattooContext()));
        options.classList.toggle('hidden', !options.childElementCount);
        return;
    }

    if (category.kind === 'component' || category.kind === 'prop' || category.kind === 'hair') {
        const drawable = category.kind === 'hair' ? value.style : value.drawable;
        if (drawable >= 0) {
            const textures = await post('textures', { id: category.id, drawable });
            if (textures > 1) {
                options.append(stepper({
                    label: 'Color',
                    value: value.texture,
                    min: 0,
                    max: textures - 1,
                    onChange: (texture) => setValue(category, { ...s.values[category.id], texture }),
                }));
            }
        }
    }

    if (category.kind === 'hair') {
        options.append(
            swatches({ label: 'Hair color', colors: s.palettes.hair, value: value.color, onChange: (color) => setValue(category, { ...s.values[category.id], color }) }),
            swatches({ label: 'Highlight', colors: s.palettes.hair, value: value.highlight, onChange: (highlight) => setValue(category, { ...s.values[category.id], highlight }) }),
        );
    }

    if (category.kind === 'overlay' && value.opacity > 0) {
        options.append(range({
            label: 'Intensity',
            value: value.opacity,
            onInput: (opacity) => setValue(category, { ...s.values[category.id], opacity: Math.max(0.01, opacity) }),
        }));

        if (category.colors) {
            options.append(swatches({
                label: 'Color',
                colors: s.palettes[category.colors] || [],
                value: value.color,
                onChange: (color) => setValue(category, { ...s.values[category.id], color, secondColor: color }),
            }));
        }
    }

    options.classList.toggle('hidden', !options.childElementCount);
}

function renderLooks() {
    title.textContent = 'My looks';
    priceTag.textContent = 'Free';
    search.classList.add('hidden');
    options.classList.add('hidden');
    grid.replaceChildren();

    const form = el('div', 'look-form');
    const name = document.createElement('input');
    name.className = 'search';
    name.maxLength = 30;
    name.placeholder = 'Name this look';
    const save = el('button', 'btn btn--accent', 'Save');
    save.type = 'button';
    save.addEventListener('click', async () => {
        if (!name.value.trim()) return;
        const result = await post('saveOutfit', { name: name.value.trim() });
        if (result?.ok) {
            s.outfits = result.outfits;
            renderLooks();
        }
    });
    form.append(name, save);

    const note = el('p', 'muted look-note', bagLines().length
        ? 'Only what you have paid for is saved: pay for your bag first.'
        : `Saves what you are wearing. ${s.outfits.length} / ${s.maxOutfits} looks.`);

    const list = el('div', 'looks');
    s.outfits.forEach((outfit) => {
        const row = el('div', 'look-row');
        const wear = el('button', 'btn', 'Wear');
        const remove = el('button', 'btn btn--ghost btn--danger', 'Delete');
        wear.type = 'button';
        remove.type = 'button';

        wear.addEventListener('click', async () => {
            if (bagLines().length && !await confirmModal('Wear this look?', 'What is in your bag will be put back.', 'Wear')) return;
            const result = await post('wearOutfit', { id: outfit.id });
            if (result?.ok) resetTo(result.values);
        });

        remove.addEventListener('click', async () => {
            if (!await confirmModal('Delete look?', `"${outfit.name}" will be gone.`, 'Delete')) return;
            const result = await post('deleteOutfit', { id: outfit.id });
            if (result?.ok) {
                s.outfits = result.outfits;
                renderLooks();
            }
        });

        row.append(el('span', 'look-row__name', outfit.name), wear, remove);
        list.append(row);
    });

    if (!s.outfits.length) list.append(el('p', 'muted empty', 'No saved looks yet.'));

    grid.append(form, note, list);
}

function selectTab(id) {
    s.tab = id;
    tabs.querySelectorAll('.tab').forEach((tab) => tab.classList.toggle('is-active', tab.dataset.id === id));
    search.value = '';

    if (id === LOOKS_TAB) {
        post('shot', { name: 'body' });
        renderLooks();
        return;
    }

    const category = s.byId[id];
    search.classList.remove('hidden');
    search.placeholder = category.kind === 'tattoo' ? 'Search by name' : 'Search by number';
    search.inputMode = category.kind === 'tattoo' ? 'text' : 'numeric';
    search.maxLength = category.kind === 'tattoo' ? 30 : 4;
    title.textContent = category.label;
    priceTag.textContent = category.price > 0
        ? `${money(category.price)} per ${category.kind === 'tattoo' ? 'tattoo' : 'change'}`
        : 'Free';
    post('shot', { name: category.shot });
    renderGrid(category);
    renderOptions(category);

    // The grid shows numbers at once; pictures come in when the tab's pack is loaded
    const key = `${s.sex}_${keyOf(category)}`;
    if (!s.packs[key]) {
        loadPack(category).then(() => {
            if (s && s.tab === id) renderGrid(category);
        });
    }
}

function renderTabs() {
    tabs.replaceChildren();
    const list = s.categories.map((c) => ({ id: c.id, label: c.label }));
    if (s.store === 'clothing') list.push({ id: LOOKS_TAB, label: 'My looks' });

    list.forEach((item) => {
        const tab = el('button', 'tab', item.label);
        tab.type = 'button';
        tab.dataset.id = item.id;
        tab.addEventListener('click', () => selectTab(item.id));
        tabs.append(tab);
    });
}

// ---------- bag ----------

// One line per piece changed, or per tattoo added, removed or made lighter/darker
function bagLines() {
    const lines = [];

    s.categories.forEach((category) => {
        if (category.kind === 'tattoo') {
            lines.push(...tattooBagLines(category, s));
        } else if (!same(s.values[category.id], s.original[category.id])) {
            const style = styleOf(category, s.values[category.id]);
            lines.push({ category, label: category.label, note: style < 0 ? 'None' : `#${style + 1}`, price: category.price });
        }
    });

    return lines;
}

function renderBag() {
    const lines = bagLines();
    bagList.replaceChildren();

    lines.forEach((line) => {
        const { category } = line;
        const row = el('div', 'bag-row');
        const undo = el('button', 'bag-row__undo', '×');
        undo.type = 'button';
        undo.title = 'Put back';
        undo.addEventListener('click', () => {
            setValue(category, line.name ? putBack(category, line.name, s) : s.original[category.id]);
            if (s.tab === category.id) selectTab(category.id);
        });

        row.append(
            el('span', 'bag-row__name', line.label),
            el('span', 'muted bag-row__style', line.note),
            el('span', 'bag-row__price', line.price ? money(line.price) : 'Free'),
            undo,
        );
        bagList.append(row);
    });

    if (!lines.length) bagList.append(el('p', 'muted empty', 'Pick something to try it on.'));

    const total = lines.reduce((sum, line) => sum + line.price, 0);
    bagCount.textContent = lines.length ? `${lines.length} item${lines.length > 1 ? 's' : ''}` : '';
    bagTotal.textContent = money(total);
    payCash.disabled = !lines.length;
    payBank.disabled = !lines.length;
}

function resetTo(values) {
    s.values = values;
    s.original = structuredClone(values);
    renderBag();
    selectTab(s.tab);
}

async function pay(account) {
    payCash.disabled = true;
    payBank.disabled = true;
    const result = await post('buy', { account });
    if (result?.ok) {
        resetTo(result.values);
    } else {
        renderBag();
    }
}

payCash.addEventListener('click', () => pay('cash'));
payBank.addEventListener('click', () => pay('bank'));

// ---------- open / close ----------

async function leave() {
    if (bagLines().length && !await confirmModal('Leave the store?', 'You will put back what is in your bag.', 'Leave')) return;
    shop.classList.add('hidden');
    s = null;
    post('close');
}

document.getElementById('leave').addEventListener('click', leave);

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && s && document.getElementById('modal').classList.contains('hidden')) leave();
});

search.addEventListener('input', () => {
    if (s?.byId[s.tab]?.kind !== 'tattoo') search.value = search.value.replace(/\D/g, '');
    if (s?.byId[s.tab]) renderGrid(s.byId[s.tab]);
});

stageControls(stage);

function open(data) {
    applyTheme(data.theme);

    // Lua sends an empty tattoo list as {}, not []
    const values = {};
    data.categories.forEach((c) => { values[c.id] = c.kind === 'tattoo' ? asList(c.value) : c.value; });

    s = {
        store: data.store,
        sex: data.sex,
        categories: data.categories,
        byId: Object.fromEntries(data.categories.map((c) => [c.id, c])),
        palettes: data.palettes,
        outfits: data.outfits || [],
        maxOutfits: data.maxOutfits,
        packs: {},
        custom: data.custom || {},
        values,
        original: structuredClone(values),
        tab: data.categories[0].id,
    };

    kicker.textContent = STORE_NAMES[data.store] || 'Store';
    renderTabs();
    renderBag();
    selectTab(s.tab);
    shop.classList.remove('hidden');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') open(data);
    if (data.action === 'hide') {
        shop.classList.add('hidden');
        s = null;
    }
});
