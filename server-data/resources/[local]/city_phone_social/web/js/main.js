// The InstaPic page: Home (stories and the feed of you and who you follow), Explore (everyone's posts, find people),
// New (post or story) and Profile. It runs inside city_phone; data comes from our resource's callbacks.
import {
    state, call, t, h, button, icon, navBar, closeSheet, applyContext, loadTexts, setLanguage, avatar,
} from './lib.js';
import { postCard, setRefresh as setPostRefresh } from './post.js';
import { profileView, welcome, openProfile, grid, setRefresh as setProfileRefresh } from './profile.js';
import { storiesBar } from './stories.js';
import { openCompose, setRefresh as setComposeRefresh } from './compose.js';

const TABS = [
    ['home', 'star'],
    ['explore', 'search'],
    ['new', 'plus'],
    ['profile', 'person'],
];

const search = document.createElement('input');
let searchTimer = null;
let people = [];
let noMore = false;
let loadingMore = false;

search.addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(async () => {
        const query = search.value.trim();
        const result = query ? await call('search', { query }) : { ok: true, result: [] };
        people = result.ok && Array.isArray(result.result) ? result.result : [];
        render();
    }, 300);
});

function empty(iconName, text) {
    return h('div', 'k-empty', null, icon(iconName), h('span', '', text));
}

function home() {
    return [
        navBar(null, h('span', 'logo', 'InstaPic'), button('k-link', null, () => openCompose('post'), icon('plus'))),
        storiesBar(),
        state.feed.length ? state.feed.map(postCard) : empty('person', t('feed.empty')),
    ];
}

function explore() {
    const results = search.value.trim()
        ? h('div', 'k-list', null, people.length ? people.map((person) => button('k-item', null, () => openProfile(person.username),
            avatar(person.username, person.name, 'small'),
            h('span', 'k-item__main', null, h('span', 'k-item__title', person.username), h('span', 'k-item__subtitle', person.name)),
        )) : [empty('search', t('explore.nobody'))])
        : grid(state.explore);

    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('tabs.explore')),
        h('label', 'k-search', null, icon('search'), search),
        results,
    ];
}

let profileNodes = [];

function profile() {
    return [navBar(null, `@${state.me.username}`, null), profileNodes];
}

const VIEWS = { home, explore, profile };

function renderTabbar() {
    const bar = document.getElementById('tabbar');
    bar.hidden = !state.me;
    bar.replaceChildren(...TABS.map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        if (id === 'new') return openCompose('post');
        state.tab = id;
        closeSheet();
        refresh();
    }, icon(iconName))));
}

// A redraw keeps the scroll position and the search field's focus
function render() {
    search.placeholder = t('explore.search');
    const content = document.getElementById('content');
    const top = content.scrollTop;
    const typing = document.activeElement === search;

    content.replaceChildren(...(state.me ? VIEWS[state.tab]() : welcome(refresh)).flat(Infinity).filter(Boolean));
    content.scrollTop = top;
    if (typing) search.focus();
    renderTabbar();
}

async function loadMore() {
    const list = state.tab === 'home' ? state.feed : state.explore;
    if (!list.length || noMore || loadingMore) return;

    loadingMore = true;
    const result = await call('posts', { scope: state.tab === 'home' ? 'feed' : 'explore', before: list[list.length - 1].id });
    loadingMore = false;

    const more = result.ok && Array.isArray(result.result) ? result.result : [];
    noMore = more.length === 0;
    list.push(...more);
    render();
}

async function refresh() {
    const me = await call('me');
    if (!me.ok) return;

    state.me = me.result.account || null;
    state.staff = me.result.staff === true;
    noMore = false;

    if (state.me && state.tab === 'home') {
        const [feed, stories] = await Promise.all([call('posts', { scope: 'feed' }), call('stories')]);
        state.feed = feed.ok && Array.isArray(feed.result) ? feed.result : [];
        state.stories = stories.ok && Array.isArray(stories.result) ? stories.result : [];
    }

    if (state.me && state.tab === 'explore') {
        const result = await call('posts', { scope: 'explore' });
        state.explore = result.ok && Array.isArray(result.result) ? result.result : [];
    }

    if (state.me && state.tab === 'profile') profileNodes = await profileView(state.me.username);

    render();
}

document.getElementById('content').addEventListener('scroll', (event) => {
    const page = event.target;
    if (state.tab === 'profile' || page.scrollTop + page.clientHeight < page.scrollHeight - 200) return;
    loadMore();
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
    setPostRefresh(refresh);
    setProfileRefresh(refresh);
    setComposeRefresh(refresh);
    await refresh();
}

start();
