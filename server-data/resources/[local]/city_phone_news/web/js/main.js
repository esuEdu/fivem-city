// The Weazel News page: categories and the newest articles (more as you scroll); journalists on duty get a
// button to write. It runs inside city_phone; data comes from our resource's callbacks.
import {
    state, call, t, h, button, icon, navBar, applyContext, loadTexts, setLanguage, CATEGORIES, ago,
} from './lib.js';
import { openArticle, openEditor, setRefresh } from './article.js';

let loading = false;

function card(article, lead) {
    return button(`story${lead ? ' story--lead' : ''}`, null, () => openArticle(article.id),
        h('div', 'story__tags', null,
            article.breaking ? h('span', 'tag tag--breaking', t('breaking')) : null,
            h('span', 'tag', t(`category.${article.category}`)),
        ),
        h('span', 'story__title', article.title),
        lead ? h('span', 'story__preview', article.preview) : null,
        h('span', 'story__meta', `${article.author} · ${ago(article.createdAt)} · ♥ ${article.likes} · 💬 ${article.comments}`),
    );
}

function render() {
    const content = document.getElementById('content');
    const top = content.scrollTop;

    const chips = [null, ...CATEGORIES].map((category) => button(`chip${state.category === category ? ' chip--on' : ''}`,
        t(category ? `category.${category}` : 'category.all'), () => {
            state.category = category;
            load();
        }));

    content.replaceChildren(
        navBar(null, null, state.rights.write ? button('k-link', null, () => openEditor(), icon('compose')) : null),
        h('div', 'masthead', null, h('span', 'masthead__name', 'WEAZEL'), h('span', 'masthead__news', 'NEWS')),
        h('div', 'chips', null, chips),
        state.articles.length
            ? h('div', 'stories', null, state.articles.map((article, index) => card(article, index === 0)))
            : h('div', 'k-empty', null, icon('info'), h('span', '', t('list.empty'))),
    );

    content.scrollTop = top;
}

async function load(more = false) {
    const before = more && state.articles.length ? state.articles[state.articles.length - 1].id : undefined;
    const result = await call('list', { category: state.category, before });
    if (!result.ok) return;

    const rows = Array.isArray(result.result.articles) ? result.result.articles : [];
    state.articles = more ? [...state.articles, ...rows] : rows;
    state.noMore = rows.length === 0;
    state.rights = result.result.rights || state.rights;
    render();
}

document.getElementById('content').addEventListener('scroll', (event) => {
    const page = event.target;
    if (state.noMore || loading || page.scrollTop + page.clientHeight < page.scrollHeight - 160) return;

    loading = true;
    load(true).finally(() => { loading = false; });
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
    setRefresh(() => load());
    await load();
}

start();
