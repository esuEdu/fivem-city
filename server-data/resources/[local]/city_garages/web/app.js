const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_garages';

const $ = (id) => document.getElementById(id);

let labels = {};
let garage = null;
let vehicles = [];
let favorites = new Set();
let selected = null;
let tab = 'all';
let busy = false;

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(data) })
        .then((response) => response.json())
        .catch(() => null);
}

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

function format(text, value) {
    return (text || '').replace('%s', value);
}

function money(value) {
    return Number(value || 0).toLocaleString('en-US');
}

// What can be done with a car here: take it out (parked at a garage, or left out at an impound lot) or nothing
function isAvailable(vehicle) {
    return garage.depot ? vehicle.state === 'depot' : vehicle.state === 'garaged';
}

// Waiting at the impound lot while the player is at a garage: the button sets the GPS route there instead
function canRoute(vehicle) {
    return !garage.depot && Boolean(garage.lot) && vehicle.state === 'depot';
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function visibleVehicles() {
    const query = $('search').value.trim().toLowerCase();

    return vehicles
        .filter((vehicle) => tab === 'all' || favorites.has(vehicle.id))
        .filter((vehicle) => !query || vehicle.label.toLowerCase().includes(query) || String(vehicle.plate).toLowerCase().includes(query))
        .sort((a, b) =>
            (favorites.has(b.id) - favorites.has(a.id))
            || (isAvailable(b) - isAvailable(a))
            || a.label.localeCompare(b.label));
}

function toggleFavorite(vehicle) {
    const on = !favorites.has(vehicle.id);
    if (on) favorites.add(vehicle.id);
    else favorites.delete(vehicle.id);

    post('favorite', { id: vehicle.id, on });
    renderList();
}

function renderList() {
    const list = $('list');
    const shown = visibleVehicles();
    list.replaceChildren();

    for (const vehicle of shown) {
        const item = el('li', `car${selected && selected.id === vehicle.id ? ' is-selected' : ''}`);
        const star = el('button', `car__star${favorites.has(vehicle.id) ? ' is-on' : ''}`, '★');
        const text = el('div', 'car__text');
        const dotClass = isAvailable(vehicle) ? 'dot dot--ready' : vehicle.state === 'impounded' ? 'dot dot--danger' : 'dot';

        star.addEventListener('click', (event) => {
            event.stopPropagation();
            toggleFavorite(vehicle);
        });

        text.append(el('span', 'car__name', vehicle.label), el('span', 'car__plate', vehicle.plate));
        item.append(star, text, el('span', dotClass));
        item.addEventListener('click', () => select(vehicle));
        list.append(item);
    }

    $('empty').classList.toggle('hidden', shown.length > 0);
}

function setStat(name, value) {
    const bar = $(`${name}-bar`);
    bar.style.width = `${value}%`;
    bar.className = value <= 25 ? 'is-low' : value <= 60 ? 'is-mid' : '';
    $(name).textContent = `${value}%`;
}

function showPhoto(vehicle) {
    const photo = $('photo');
    const fallback = $('photo-fallback');

    // hidden until it loads, so the previous car's picture never shows under the new name
    photo.classList.add('hidden');
    fallback.classList.add('hidden');
    photo.onload = () => {
        if (selected !== vehicle) return;
        photo.classList.remove('hidden');
    };
    photo.onerror = () => {
        if (selected !== vehicle) return;
        fallback.classList.remove('hidden');
    };
    photo.alt = vehicle.label;

    if (photo.src === vehicle.image && photo.complete) {
        if (photo.naturalWidth) photo.classList.remove('hidden');
        else fallback.classList.remove('hidden');
        return;
    }

    photo.src = vehicle.image;
}

function select(vehicle) {
    selected = vehicle;

    $('placeholder').classList.add('hidden');
    $('detail').classList.remove('hidden');
    showPhoto(vehicle);

    $('name').textContent = vehicle.label;
    $('plate').textContent = vehicle.plate;

    const state = $('state');
    state.textContent = labels[`state_${vehicle.state}`] || vehicle.state;
    state.className = `chip${isAvailable(vehicle) ? ' chip--ready' : vehicle.state === 'impounded' ? ' chip--danger' : ''}`;

    setStat('engine', vehicle.engine);
    setStat('body', vehicle.body);
    setStat('fuel', vehicle.fuel);

    const available = isAvailable(vehicle);
    const routable = canRoute(vehicle);
    const hint = $('hint');
    const hintKey = available ? null : vehicle.state === 'garaged' ? 'hint_garaged' : `hint_${vehicle.state}`;
    hint.textContent = routable ? format(labels.hint_depot_at, garage.lot) : hintKey ? labels[hintKey] : '';
    hint.classList.toggle('hidden', !hintKey);

    const take = $('take');
    take.disabled = !available && !routable;
    if (routable) take.textContent = format(labels.ui_route, garage.lot);
    else take.textContent = available && vehicle.fee ? format(labels.ui_pay_take_out, money(vehicle.fee)) : labels.ui_take_out;

    renderList();
}

function open(data) {
    garage = data.garage;
    vehicles = data.vehicles || [];
    favorites = new Set(data.favorites || []);
    selected = null;
    busy = false;
    tab = 'all';

    $('kind').textContent = garage.depot ? labels.ui_depot : labels.ui_garage;
    $('title').textContent = garage.label;
    $('count').textContent = format(labels.ui_count, vehicles.length);
    $('search').value = '';
    $('placeholder').classList.remove('hidden');
    $('detail').classList.add('hidden');
    setTab('all');

    $('garage').classList.remove('hidden');

    const first = visibleVehicles().find(isAvailable);
    if (first) select(first);
}

function close() {
    $('garage').classList.add('hidden');
    garage = null;
}

function setTab(name) {
    tab = name;
    $('tab-all').classList.toggle('is-active', name === 'all');
    $('tab-fav').classList.toggle('is-active', name === 'fav');
    renderList();
}

function applyLabels() {
    $('search').placeholder = labels.ui_search;
    $('tab-all').textContent = labels.ui_all;
    $('tab-fav').textContent = labels.ui_favorites;
    $('empty').textContent = labels.ui_empty;
    $('placeholder').textContent = labels.ui_select;
    $('engine-label').textContent = labels.ui_engine;
    $('body-label').textContent = labels.ui_body;
    $('fuel-label').textContent = labels.ui_fuel;
    $('close').setAttribute('aria-label', labels.ui_close);
}

$('search').addEventListener('input', renderList);
$('tab-all').addEventListener('click', () => setTab('all'));
$('tab-fav').addEventListener('click', () => setTab('fav'));
$('close').addEventListener('click', () => post('close'));

$('take').addEventListener('click', async () => {
    if (selected && !busy && canRoute(selected)) return post('route');
    if (!selected || busy || !isAvailable(selected)) return;

    busy = true;
    $('take').disabled = true;
    const ok = await post('takeOut', { id: selected.id });
    busy = false;

    if (!ok && selected) $('take').disabled = !isAvailable(selected) && !canRoute(selected);
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && garage) post('close');
});

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') open(data);
    else if (data.action === 'close') close();
});

post('ready').then((setup) => {
    if (!setup) return;
    applyTheme(setup.theme);
    labels = setup.labels || {};
    applyLabels();
});
