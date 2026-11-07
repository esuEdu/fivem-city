// The Market page: Browse (categories, search, newest first, more as you scroll), Favorites and My Ads.
// It runs inside city_phone; data comes from our resource's callbacks.
import {
    state, call, t, h, button, icon, navBar, closeSheet, applyContext, loadTexts, setLanguage,
    CATEGORIES, money, ago, daysLeft, photo, lazyImage,
} from './lib.js';
import { openAd, openForm, setRefresh } from './ad.js';

const TABS = [
    ['browse', 'search'],
    ['favorites', 'heart'],
    ['mine', 'person'],
];

const search = document.createElement('input');
let searchTimer = null;
search.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
        state.search = search.value.trim();
        loadBrowse();
    }, 350);
});

function empty(iconName, text) {
    return h('div', 'k-empty', null, icon(iconName), h('span', '', text));
}

function card(ad, back) {
    return button('card', null, () => openAd(ad, back),
        ad.hasPhoto ? lazyImage('card__photo', () => photo(ad.id)) : h('div', 'card__photo card__photo--none', null, icon('photo')),
        h('div', 'card__body', null,
            h('span', 'card__price', money(ad.price)),
            h('span', 'card__title', ad.title),
            h('span', 'card__meta', ad.mine && state.tab === 'mine'
                ? daysLeft(ad.expiresAt)
                : `${t(`category.${ad.category}`)} · ${ago(ad.createdAt)}`),
        ),
    );
}

function browse() {
    const chips = [null, ...CATEGORIES].map((category) => button(`chip${state.category === category ? ' chip--on' : ''}`,
        t(category ? `category.${category}` : 'category.all'), () => {
            state.category = category;
            loadBrowse();
        }));

    const list = h('div', 'cards', null, state.ads.map((ad) => card(ad, t('tabs.browse'))));

    return [
        navBar(null, null, button('k-link', null, () => openForm(), icon('plus'))),
        h('h1', 'k-large-title', t('title')),
        h('label', 'k-search', null, icon('search'), search),
        h('div', 'chips', null, chips),
        state.ads.length ? list : empty('search', t(state.search ? 'browse.noResults' : 'browse.empty')),
    ];
}

function favorites() {
    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('tabs.favorites')),
        state.favorites.length
            ? h('div', 'cards', null, state.favorites.map((ad) => card(ad, t('tabs.favorites'))))
            : empty('heart', t('favorites.empty')),
    ];
}

function mine() {
    const active = state.mine.filter((ad) => ad.expiresAt > Date.now() / 1000).length;

    return [
        navBar(null, null, button('k-link', null, () => openForm(), icon('plus'))),
        h('h1', 'k-large-title', t('tabs.mine')),
        h('p', 'k-group__label', t('mine.count', active, state.max)),
        state.mine.length
            ? h('div', 'cards', null, state.mine.map((ad) => card(ad, t('tabs.mine'))))
            : empty('compose', t('mine.empty')),
    ];
}

const VIEWS = { browse, favorites, mine };

function renderTabbar() {
    document.getElementById('tabbar').replaceChildren(...TABS.map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        state.tab = id;
        closeSheet();
        refresh();
    }, icon(iconName), h('span', '', t(`tabs.${id}`)))));
}

// A redraw keeps the scroll position and the search field's focus (results arrive while typing)
function render() {
    search.placeholder = t('browse.search');
    const content = document.getElementById('content');
    const top = content.scrollTop;
    const typing = document.activeElement === search;

    content.replaceChildren(...VIEWS[state.tab]().flat().filter(Boolean));
    content.scrollTop = top;
    if (typing) search.focus();
    renderTabbar();
}

async function loadBrowse(more = false) {
    const before = more && state.ads.length ? state.ads[state.ads.length - 1].id : undefined;
    const result = await call('list', { category: state.category, search: state.search || undefined, before });
    if (!result.ok) return;

    const data = result.result;
    const ads = Array.isArray(data.ads) ? data.ads : [];
    state.ads = more ? [...state.ads, ...ads] : ads;
    state.noMore = ads.length === 0;
    state.staff = data.staff === true;
    state.fee = data.fee || 0;
    state.days = data.days || state.days;
    render();
}

async function refresh() {
    if (state.tab === 'browse') return loadBrowse();

    if (state.tab === 'favorites') {
        const result = await call('favorites');
        state.favorites = result.ok && Array.isArray(result.result) ? result.result : [];
    }

    if (state.tab === 'mine') {
        const result = await call('mine');
        if (result.ok) {
            state.mine = Array.isArray(result.result.ads) ? result.result.ads : [];
            state.max = result.result.max || 0;
            state.fee = result.result.fee || state.fee;
            state.days = result.result.days || state.days;
        }
    }

    render();
}

// More ads when the list is scrolled to the end
document.getElementById('content').addEventListener('scroll', (event) => {
    const page = event.target;
    if (state.tab !== 'browse' || state.noMore || state.loading) return;
    if (page.scrollTop + page.clientHeight < page.scrollHeight - 120) return;

    state.loading = true;
    loadBrowse(true).finally(() => { state.loading = false; });
});

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        setLanguage(message.language);
        render();
    }
});

async function start() {
    await loadTexts();
    setRefresh(refresh);
    render();
    await refresh();
}

start();
