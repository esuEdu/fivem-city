const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_mechanic';

const $ = (id) => document.getElementById(id);

const ICONS = {
    gauge: 'M12 4a9 9 0 0 0-9 9 9 9 0 0 0 2.6 6.4l1.4-1.4A7 7 0 1 1 19 13a7 7 0 0 1-2 5l1.4 1.4A9 9 0 0 0 12 4zm4.2 4.4-5 4.3a1.5 1.5 0 1 0 2.1 2.1z',
    car: 'M5 11l1.6-4.2A2 2 0 0 1 8.5 5.5h7a2 2 0 0 1 1.9 1.3L19 11a2 2 0 0 1 2 2v4h-2v1.5a1 1 0 0 1-2 0V17H7v1.5a1 1 0 0 1-2 0V17H3v-4a2 2 0 0 1 2-2zm2.2 0h9.6l-1.2-3.5H8.4zM7 15a1.3 1.3 0 1 0 0-2.6A1.3 1.3 0 0 0 7 15zm10 0a1.3 1.3 0 1 0 0-2.6 1.3 1.3 0 0 0 0 2.6z',
    paint: 'M4 4h13v4H4zm13 2h2v5h-8v3h-2v-5h8zM9 15h2v6H9z',
    wheel: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm0 3a6 6 0 0 1 5.6 4H14a2 2 0 0 0-4 0H6.4A6 6 0 0 1 12 6zm-6 6.5h4.2l-2.1 3.7A6 6 0 0 1 6 12.5zm6 5.5a6 6 0 0 1-2-.3l2-3.6 2 3.6a6 6 0 0 1-2 .3zm3.9-1.8-2.1-3.7H18a6 6 0 0 1-2.1 3.7z',
    bulb: 'M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2zM9 19h6v1.5a1.5 1.5 0 0 1-1.5 1.5h-3A1.5 1.5 0 0 1 9 20.5z',
    star: 'M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z',
};

let labels = {};
let data = null;
let view = { level: 'cats', cat: 0, item: 0 };
let focus = 0;
let rows = [];
let cart = new Map();
let repair = false;
let busy = false;

function post(name, body = {}) {
    return fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(body) })
        .then((response) => response.json())
        .catch(() => null);
}

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

function t(key, ...values) {
    let out = labels[key] ?? key;
    for (const value of values) out = out.replace('%s', value);
    return out;
}

function money(value) {
    return `$${Number(value || 0).toLocaleString('en-US')}`;
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function icon(name) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', ICONS[name] || ICONS.star);
    path.setAttribute('fill', 'currentColor');
    svg.append(path);
    return svg;
}

function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
}

function category() {
    return data.categories[view.cat];
}

function item() {
    return category().items[view.item];
}

// What the car has for an item right now: the pending change, else what was fitted
function effective(entry) {
    return cart.has(entry.key) ? cart.get(entry.key).value : entry.current;
}

function optionLabel(entry, value) {
    if (entry.kind === 'toggle') return value ? t('ui_on') : t('ui_off');
    const found = entry.options.find((option) => same(option.value, value));
    return found ? found.label : '—';
}

function priceOf(entry, value) {
    if (entry.kind === 'toggle') return value ? entry.price : 0;
    const found = entry.options.find((option) => same(option.value, value));
    return found ? found.price : 0;
}

function findItem(key) {
    for (const cat of data.categories) {
        const found = cat.items.find((entry) => entry.key === key);
        if (found) return found;
    }
}

function rimItem() {
    return findItem('modFrontWheels') || findItem('modBackWheels');
}

// ---- Changing the car ----

async function choose(entry, value) {
    if (busy) return;

    const response = await post('preview', { key: entry.key, value });
    if (!response) return;

    if (same(value, entry.current)) {
        cart.delete(entry.key);
    } else {
        cart.set(entry.key, { entry, value });
    }

    if (entry.key === 'wheels' && Array.isArray(response.rims)) {
        const rims = rimItem();
        if (rims) {
            const price = rims.options.find((option) => option.value !== -1)?.price ?? 0;
            rims.options = response.rims.map((option) => ({ ...option, price }));
            if (cart.has('wheels')) {
                cart.set(rims.key, { entry: rims, value: -1 });
            } else {
                cart.delete(rims.key);
            }
        }
    }

    render();
}

async function undo(key) {
    // a rim belongs to its rim type: undoing the rim while the type changed undoes both
    const rims = rimItem();
    if (rims && key === rims.key && cart.has('wheels')) key = 'wheels';

    const response = await post('revert', { key });
    if (!response) return;

    cart.delete(key);

    if (key === 'wheels' && rims) {
        cart.delete(rims.key);
        if (Array.isArray(response.rims)) rims.options = response.rims.map((option) => ({ ...option, price: rims.options[1]?.price ?? 0 }));
    }

    render();
}

async function undoAll() {
    if (busy || (cart.size === 0 && !repair)) return;

    const response = await post('revert', { all: true });
    if (!response) return;

    const rims = rimItem();
    if (rims && cart.has('wheels') && Array.isArray(response.rims)) {
        rims.options = response.rims.map((option) => ({ ...option, price: rims.options[1]?.price ?? 0 }));
    }

    cart.clear();
    repair = false;
    render();
}

// More than the shop account holds (never when tuning is free)
function short(sum) {
    return !data.free && sum > data.balance;
}

async function confirm() {
    if (busy || short(total()) || (cart.size === 0 && !repair)) return;

    busy = true;
    render();

    const body = { cart: {}, repair };
    for (const [key, entry] of cart) body.cart[key] = entry.value;

    const response = await post('buy', body);
    busy = false;

    if (response) {
        for (const [, entry] of cart) entry.entry.current = entry.value;
        if (repair) data.repair = 0;
        data.balance = response.balance;
        cart.clear();
        repair = false;
    }

    render();
}

function total() {
    let sum = repair ? data.repair : 0;
    for (const [, entry] of cart) sum += priceOf(entry.entry, entry.value);
    return sum;
}

// ---- Navigation ----

function open(level, index) {
    if (level === 'items') {
        view = { level, cat: index, item: 0 };
        post('focus', { category: category().id });
    } else if (level === 'options') {
        view = { ...view, level, item: index };
        $('search').value = '';
    }

    focus = 0;
    render();

    if (level === 'options') {
        const selected = rows.findIndex((row) => row.classList.contains('is-selected'));
        if (selected >= 0) setFocus(selected);
    }
}

function back() {
    if (view.level === 'options') {
        focus = view.item;
        view = { ...view, level: 'items' };
    } else if (view.level === 'items') {
        focus = view.cat;
        view = { level: 'cats', cat: 0, item: 0 };
    } else {
        return close();
    }

    render();
}

function close() {
    post('close');
}

function setFocus(index) {
    if (rows.length === 0) return;

    focus = Math.max(0, Math.min(rows.length - 1, index));
    rows.forEach((row, i) => row.classList.toggle('is-focused', i === focus));
    rows[focus].scrollIntoView({ block: 'nearest' });
}

// ---- Rendering ----

function row(onClick) {
    const node = el('button', 'row');
    node.addEventListener('click', onClick);
    rows.push(node);
    return node;
}

function renderCats(list) {
    $('crumb').textContent = t('ui_kicker');

    data.categories.forEach((cat, index) => {
        const node = row(() => open('items', index));
        const badge = cat.items.filter((entry) => cart.has(entry.key)).length;
        const iconBox = el('span', 'row__icon');
        iconBox.append(icon(cat.icon));
        node.append(iconBox, el('span', 'row__label', cat.label));
        if (badge) node.append(el('span', 'tag', String(badge)));
        node.append(el('span', 'row__chevron', '›'));
        list.append(node);
    });
}

function renderItems(list) {
    $('crumb').textContent = category().label;

    category().items.forEach((entry, index) => {
        const value = effective(entry);

        if (entry.kind === 'toggle') {
            const node = row(() => choose(entry, !value));
            const label = el('span', 'row__label', entry.label);
            node.append(label);
            if (!value && entry.price) node.append(el('span', 'row__price', money(entry.price)));
            if (cart.has(entry.key)) node.append(el('span', 'tag tag--dot'));
            node.append(el('span', `switch${value ? ' is-on' : ''}`));
            list.append(node);
            return;
        }

        const node = row(() => open('options', index));
        const label = el('span', 'row__label', entry.label);
        label.append(el('span', 'row__sub', optionLabel(entry, value)));
        node.append(label);
        if (cart.has(entry.key)) node.append(el('span', 'tag tag--dot'));
        node.append(el('span', 'row__chevron', '›'));
        list.append(node);
    });
}

function renderOptions(list) {
    const entry = item();
    const query = $('search').value.trim().toLowerCase();
    const value = effective(entry);
    let group = null;

    $('crumb').textContent = entry.label;

    for (const option of entry.options) {
        if (query && !option.label.toLowerCase().includes(query)) continue;

        if (option.group && option.group !== group) {
            group = option.group;
            list.append(el('li', 'group', group));
        }

        const node = row(() => choose(entry, option.value));
        if (same(option.value, value)) node.classList.add('is-selected');

        if (Array.isArray(option.value) && option.value.length === 3 && typeof option.value[0] === 'number') {
            const swatch = el('span', 'swatch');
            swatch.style.background = `rgb(${option.value.join(',')})`;
            node.append(swatch);
        }

        node.append(el('span', 'row__label', option.label));

        if (same(option.value, entry.current)) {
            node.append(el('span', 'tag', t('ui_current')));
        } else {
            node.append(el('span', 'row__price', option.price ? money(option.price) : t('ui_free')));
        }

        list.append(node);
    }
}

function renderOrder() {
    const list = $('cart');
    list.replaceChildren();

    for (const [key, entry] of cart) {
        const node = el('li', 'cart__item');
        const text = el('div', 'cart__text', entry.entry.label);
        text.append(el('small', '', optionLabel(entry.entry, entry.value)));
        const remove = el('button', 'cart__remove', '×');
        remove.addEventListener('click', () => undo(key));
        node.append(text, el('span', 'cart__price', money(priceOf(entry.entry, entry.value))), remove);
        list.append(node);
    }

    $('cart-empty').classList.toggle('hidden', cart.size > 0);

    const canRepair = data.repair > 0;
    $('repair').classList.toggle('is-disabled', !canRepair);
    $('repair-check').disabled = !canRepair || busy;
    $('repair-check').checked = repair;
    $('repair-label').textContent = canRepair ? t('ui_repair') : t('ui_repair_none');
    $('repair-price').textContent = canRepair ? money(data.repair) : '';

    const sum = total();
    $('balance').textContent = data.free ? t('ui_free') : money(data.balance);
    $('total').textContent = money(sum);
    $('total').parentElement.classList.toggle('is-short', short(sum));
    $('confirm').disabled = busy || short(sum) || (cart.size === 0 && !repair);
    $('reset').disabled = busy || (cart.size === 0 && !repair);
}

function render() {
    const list = $('list');
    list.replaceChildren();
    rows = [];

    $('back').classList.toggle('hidden', view.level === 'cats');
    $('search-row').classList.toggle('hidden', !(view.level === 'options' && item().options.length > 12));

    if (view.level === 'cats') renderCats(list);
    else if (view.level === 'items') renderItems(list);
    else renderOptions(list);

    setFocus(focus);
    renderOrder();
}

// ---- Camera: drag the background to turn, wheel to zoom ----

let drag = null;
let pending = { dx: 0, dy: 0 };
let timer = null;

function flushCamera() {
    timer = null;
    if (!pending.dx && !pending.dy) return;
    post('camera', pending);
    pending = { dx: 0, dy: 0 };
}

$('stage').addEventListener('mousedown', (event) => {
    if (event.target !== $('stage')) return;
    drag = { x: event.clientX, y: event.clientY };
    $('stage').classList.add('is-dragging');
});

window.addEventListener('mousemove', (event) => {
    if (!drag) return;
    pending.dx += event.clientX - drag.x;
    pending.dy += event.clientY - drag.y;
    drag = { x: event.clientX, y: event.clientY };
    if (!timer) timer = setTimeout(flushCamera, 40);
});

window.addEventListener('mouseup', () => {
    drag = null;
    $('stage').classList.remove('is-dragging');
});

$('stage').addEventListener('wheel', (event) => {
    if (event.target !== $('stage')) return;
    post('camera', { zoom: Math.sign(event.deltaY) });
});

// ---- Keys ----

window.addEventListener('keydown', (event) => {
    if (!data || $('stage').classList.contains('hidden')) return;

    const typing = document.activeElement === $('search');

    if (event.key === 'Escape') {
        event.preventDefault();
        back();
    } else if (event.key === 'ArrowDown') {
        event.preventDefault();
        setFocus(focus + 1);
    } else if (event.key === 'ArrowUp') {
        event.preventDefault();
        setFocus(focus - 1);
    } else if (event.key === 'Enter') {
        event.preventDefault();
        rows[focus]?.click();
    } else if (!typing && (event.key === 'Backspace' || event.key === 'ArrowLeft')) {
        event.preventDefault();
        if (view.level !== 'cats') back();
    }
});

// ---- Wiring ----

$('back').addEventListener('click', back);
$('close').addEventListener('click', close);
$('reset').addEventListener('click', undoAll);
$('confirm').addEventListener('click', confirm);
$('search').addEventListener('input', () => {
    focus = 0;
    render();
});
$('repair-check').addEventListener('change', (event) => {
    repair = event.target.checked && data.repair > 0;
    renderOrder();
});

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.action === 'open') {
        data = message;
        cart = new Map();
        repair = false;
        busy = false;
        view = { level: 'cats', cat: 0, item: 0 };
        focus = 0;

        $('title').textContent = message.label;
        $('model').textContent = message.model;
        $('plate').textContent = message.plate;
        $('confirm').textContent = t(message.free ? 'ui_confirm_free' : 'ui_confirm');
        $('stage').classList.remove('hidden');
        render();
    } else if (message.action === 'close') {
        $('stage').classList.add('hidden');
        data = null;
    }
});

post('ready').then((setup) => {
    if (!setup) return;

    labels = setup.labels || {};
    applyTheme(setup.theme);

    $('kicker').textContent = t('ui_kicker');
    $('order-title').textContent = t('ui_cart');
    $('account-label').textContent = t('ui_account');
    $('cart-empty').textContent = t('ui_cart_empty');
    $('total-label').textContent = t('ui_total');
    $('confirm').textContent = t('ui_confirm');
    $('reset').textContent = t('ui_reset');
    $('close').textContent = t('ui_close');
    $('hint').textContent = t('ui_hint');
    $('search').placeholder = t('ui_search');
});
