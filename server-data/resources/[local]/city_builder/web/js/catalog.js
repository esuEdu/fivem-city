// The prop catalogue: every GTA prop (props.txt) plus the streamed ones the server found, with search, categories,
// favorites and a 3D preview in the game while the mouse rests on a row.
import { t, post, el, joaat } from './util.js';

const SHOW = 200;
const FAVORITES_KEY = 'city_builder:favorites';

const state = {
    all: [],
    custom: null,
    category: 'all',
    favorites: new Set(),
    byHash: null,
    hoverTimer: null,
    previewing: null,
};

const CATEGORIES = [
    ['all', 'cat_all'],
    ['props', 'cat_props'],
    ['interior', 'cat_interior'],
    ['dlc', 'cat_dlc'],
    ['custom', 'cat_custom'],
    ['favorites', 'cat_favorites'],
];

function loadFavorites() {
    try {
        state.favorites = new Set(JSON.parse(localStorage.getItem(FAVORITES_KEY) || '[]'));
    } catch {
        state.favorites = new Set();
    }
}

function saveFavorites() {
    try {
        localStorage.setItem(FAVORITES_KEY, JSON.stringify([...state.favorites]));
    } catch {
        // per-viewer convenience only
    }
}

function categoryOf(name) {
    if (name.startsWith('prop_')) return 'props';
    if (name.startsWith('v_')) return 'interior';
    return 'dlc';
}

function source() {
    if (state.category === 'custom') return state.custom || [];
    if (state.category === 'favorites') return [...state.favorites].sort();
    if (state.category === 'all') return state.custom ? state.all.concat(state.custom) : state.all;
    return state.all.filter((name) => categoryOf(name) === state.category);
}

async function preview(name) {
    state.previewing = name;
    const info = document.getElementById('previewInfo');
    const result = await post('preview', { model: name });
    if (state.previewing !== name) return;

    if (result && result.ok && result.size) {
        const s = result.size;
        info.textContent = `${name} · ${t('preview_size', s.x.toFixed(2), s.y.toFixed(2), s.z.toFixed(2))}`;
    } else {
        info.textContent = `${name} · ${t('invalid_model')}`;
    }
}

function endPreview() {
    clearTimeout(state.hoverTimer);
    if (!state.previewing) return;

    state.previewing = null;
    document.getElementById('previewInfo').textContent = '';
    post('previewEnd');
}

async function pick(name) {
    endPreview();
    const result = await post('pick', { model: name });
    if (!result || !result.ok) document.getElementById('previewInfo').textContent = `${name} · ${t('invalid_model')}`;
}

function row(name) {
    const item = el('div', 'item');
    item.append(el('div', 'name', name));

    const star = el('button', `star${state.favorites.has(name) ? ' on' : ''}`, '★');
    star.addEventListener('click', (event) => {
        event.stopPropagation();
        if (state.favorites.has(name)) state.favorites.delete(name);
        else state.favorites.add(name);
        star.classList.toggle('on', state.favorites.has(name));
        saveFavorites();
        if (state.category === 'favorites') render();
    });
    item.append(star);

    item.addEventListener('mouseenter', () => {
        clearTimeout(state.hoverTimer);
        state.hoverTimer = setTimeout(() => preview(name), 180);
    });
    item.addEventListener('click', () => pick(name));

    return item;
}

export function render() {
    const list = document.getElementById('catalog');
    const note = document.getElementById('catalogNote');
    const query = document.getElementById('search').value.trim().toLowerCase();
    const words = query.split(/\s+/).filter(Boolean);

    const names = source();
    const matches = words.length ? names.filter((name) => words.every((word) => name.includes(word))) : names;

    list.replaceChildren();
    note.textContent = '';

    // A name typed in full that isn't in the lists can still be tried
    if (/^[a-z0-9_-]{2,64}$/.test(query) && !matches.includes(query) && (query.includes('_') || !matches.length)) {
        const item = el('div', 'item');
        item.append(el('div', 'name', t('use_name', query)));
        item.addEventListener('mouseenter', () => preview(query));
        item.addEventListener('click', () => pick(query));
        list.append(item);
    }

    if (state.category === 'custom' && state.custom === null) {
        list.append(el('div', 'empty', t('custom_loading')));
        return;
    }

    if (!matches.length) {
        const key = state.category === 'favorites' && !words.length ? 'favorites_empty' : state.category === 'custom' && !words.length ? 'custom_empty' : 'no_results';
        list.append(el('div', 'empty', t(key)));
        return;
    }

    for (const name of matches.slice(0, SHOW)) list.append(row(name));
    if (matches.length > SHOW) note.textContent = t('showing', SHOW, matches.length);
}

function renderChips() {
    const chips = document.getElementById('chips');
    chips.replaceChildren();

    for (const [id, key] of CATEGORIES) {
        const chip = el('button', id === state.category ? 'active' : '', t(key));
        chip.addEventListener('click', () => {
            state.category = id;
            renderChips();
            render();
        });
        chips.append(chip);
    }
}

export async function init() {
    loadFavorites();

    const response = await fetch('props.txt');
    const text = await response.text();
    state.all = text.split(/\r?\n/).filter(Boolean);

    const search = document.getElementById('search');
    let timer;
    search.addEventListener('input', () => {
        clearTimeout(timer);
        timer = setTimeout(render, 120);
    });
    search.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') {
            const first = document.querySelector('#catalog .item');
            if (first) first.click();
        }
    });

    document.getElementById('catalog').addEventListener('mouseleave', endPreview);
}

export function setup() {
    renderChips();
    render();
}

export function setCustom(names) {
    state.custom = names;
    state.byHash = null;
    if (state.category === 'custom' || state.category === 'all') render();
}

export function stopPreview() {
    endPreview();
}

// A model name from its hash, if it's one of the known props
export function nameOf(hash) {
    if (!state.byHash) {
        state.byHash = new Map();
        for (const name of state.all.concat(state.custom || [])) state.byHash.set(joaat(name), name);
    }

    return state.byHash.get(hash >>> 0);
}
