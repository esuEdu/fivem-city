// The Photos page: the library and favorites as a grid (each image is fetched only when it scrolls into view and then
// kept), and a full screen viewer to favorite, delete or use a photo as the wallpaper.
import {
    h, button, icon, toast, navBar, backButton, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_photos';
const IMAGE = /^data:image\/(webp|jpeg|png);base64,[A-Za-z0-9+/=]+$/;
const dictionaries = {};
let language = 'en';

const state = { tab: 'library', photos: [], max: 300, cache: new Map(), viewing: null };

async function call(name, data = {}) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, { method: 'POST', body: JSON.stringify(data) });
        return await response.json();
    } catch {
        return { ok: false };
    }
}

function t(key, ...values) {
    const text = dictionaries[language]?.[key] ?? dictionaries.en?.[key] ?? key;
    let index = 0;
    return text.replace(/%s/g, () => String(values[index++] ?? ''));
}

async function image(id) {
    if (state.cache.has(id)) return state.cache.get(id);

    const result = await call('photo', { id });
    const data = result.ok && IMAGE.test(result.result) ? result.result : null;
    if (data) state.cache.set(id, data);

    return data;
}

// Images load when their tile scrolls into view
const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        observer.unobserve(entry.target);

        const img = entry.target.querySelector('img');
        image(Number(entry.target.dataset.id)).then((data) => {
            if (!data) return;
            img.src = data;
            img.onload = () => img.classList.add('loaded');
        });
    }
}, { rootMargin: '200px' });

function date(at) {
    return new Date(at * 1000).toLocaleString(language === 'pt-br' ? 'pt-BR' : 'en-US', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
}

function tile(photo) {
    const node = button('tile', null, () => openViewer(photo), h('img'), photo.favorite ? h('span', 'tile__heart', null, icon('heartFilled')) : null);
    node.dataset.id = photo.id;
    observer.observe(node);
    return node;
}

function render() {
    const list = state.tab === 'favorites' ? state.photos.filter((photo) => photo.favorite) : state.photos;

    document.getElementById('content').replaceChildren(
        navBar(null, null, null),
        h('h1', 'k-large-title', t(state.tab === 'favorites' ? 'favorites' : 'library')),
        state.tab === 'library' ? h('div', 'count', t('count', state.photos.length, state.max)) : null,
        list.length ? h('div', 'grid', null, list.map(tile)) : h('div', 'k-empty', null, icon(state.tab === 'favorites' ? 'heart' : 'photo'), h('span', '', t(state.tab === 'favorites' ? 'noFavorites' : 'empty'))),
    );

    document.getElementById('tabbar').replaceChildren(...[['library', 'photo'], ['favorites', 'heart']].map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        state.tab = id;
        render();
    }, icon(iconName), h('span', '', t(id)))));
}

function closeViewer() {
    state.viewing = null;
    document.getElementById('viewer').classList.remove('viewer--open');
}

async function openViewer(photo) {
    state.viewing = photo;

    const img = h('img');
    const data = await image(photo.id);
    if (data) img.src = data;

    const action = (iconName, label, onClick, extra = '') => button(`viewer__action ${extra}`, null, onClick, icon(iconName), h('span', '', label));

    const viewer = document.getElementById('viewer');
    viewer.replaceChildren(
        h('div', 'viewer__bar', null, navBar(backButton(t('back'), closeViewer), h('span', 'viewer__date', date(photo.created_at)), null)),
        h('div', 'viewer__image', null, img),
        h('div', 'viewer__actions', null,
            action(photo.favorite ? 'heartFilled' : 'heart', t('favorite'), async () => {
                if (!(await call('favorite', { id: photo.id, favorite: !photo.favorite })).ok) return;
                photo.favorite = !photo.favorite;
                render();
                openViewer(photo);
            }),
            action('wallpaper', t('wallpaper'), async () => {
                toast(t((await call('wallpaper', { id: photo.id })).ok ? 'wallpaperSet' : 'failed'));
            }),
            action('trash', t('delete'), async () => {
                if (!(await call('delete', { id: photo.id })).ok) return toast(t('failed'));
                state.photos = state.photos.filter((item) => item.id !== photo.id);
                state.cache.delete(photo.id);
                closeViewer();
                render();
            }, 'viewer__action--danger'),
        ),
    );
    viewer.classList.add('viewer--open');
}

async function refresh() {
    const result = await call('list');
    if (!result.ok) return;

    state.photos = result.result.photos || [];
    state.max = result.result.max || state.max;
    render();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        language = message.language === 'pt-br' ? 'pt-br' : 'en';
        render();
    }

    if (message.type === 'city_phone:message' && message.data?.action === 'refresh') refresh();
});

async function start() {
    for (const lang of ['en', 'pt-br']) {
        dictionaries[lang] = await fetch(`locales/${lang}.json`).then((r) => r.json()).catch(() => ({}));
    }
    render();
    await refresh();
}

start();
