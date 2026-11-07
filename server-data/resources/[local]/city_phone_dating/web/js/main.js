// The Matchy page: Discover (one card at a time: pass or like), Matches (chats) and Profile. It runs inside
// city_phone; data comes from our resource's callbacks.
import {
    state, call, t, h, button, icon, toast, navBar, closeSheet, applyContext, loadTexts, setLanguage, lazyImage, photo, nameAge,
} from './lib.js';
import { profileForm, welcome } from './profile.js';
import { openChat, loadChat, setRefresh as setChatRefresh } from './chat.js';

const TABS = [
    ['discover', 'heart'],
    ['matches', 'message'],
    ['profile', 'person'],
];

let photoIndex = 0;
let matchNotice = null;

function empty(iconName, text) {
    return h('div', 'k-empty', null, icon(iconName), h('span', '', text));
}

async function swipe(liked) {
    const card = state.deck[0];
    if (!card) return;

    const result = await call('swipe', { id: card.id, liked });
    if (!result.ok) return toast(t('error.invalid'));

    state.deck.shift();
    photoIndex = 0;

    if (result.result?.match) matchNotice = { name: result.result.name, profileId: result.result.id };
    if (state.deck.length === 0) await loadDeck();
    render();
}

function discover() {
    const card = state.deck[0];
    if (!card) return [navBar(null, h('span', 'logo', 'Matchy'), null), empty('heart', t('discover.empty'))];

    const slot = card.photos[photoIndex] ?? card.photos[0];
    const picture = lazyImage('card__image', () => photo(card.id, slot));

    const dots = card.photos.length > 1
        ? h('div', 'card__dots', null, card.photos.map((_, index) => h('span', `card__dot${index === photoIndex ? ' card__dot--on' : ''}`)))
        : null;

    const cardNode = h('div', 'card', null,
        picture,
        dots,
        h('div', 'card__info', null,
            h('div', 'card__name', nameAge(card.name, card.age)),
            card.bio ? h('p', 'card__bio', card.bio) : null,
        ),
    );

    // Tapping the right half shows the next photo, the left half the previous one
    cardNode.addEventListener('click', (event) => {
        if (card.photos.length < 2) return;
        const rect = cardNode.getBoundingClientRect();
        photoIndex = event.clientX - rect.left > rect.width / 2
            ? Math.min(card.photos.length - 1, photoIndex + 1)
            : Math.max(0, photoIndex - 1);
        render();
    });

    return [
        navBar(null, h('span', 'logo', 'Matchy'), null),
        cardNode,
        h('div', 'buttons', null,
            button('round round--pass', null, () => swipe(false), icon('close')),
            button('round round--like', null, () => swipe(true), icon('heartFilled')),
        ),
    ];
}

function matches() {
    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('tabs.matches')),
        state.matches.length ? h('div', 'k-list', null, state.matches.map((match) => button('k-item', null, () => openChat(match),
            lazyImage('match__photo', () => photo(match.profileId, 1)),
            h('span', 'k-item__main', null,
                h('span', 'k-item__title', nameAge(match.name, match.age)),
                h('span', 'k-item__subtitle', match.last || t('matches.new')),
            ),
        ))) : empty('message', t('matches.empty')),
    ];
}

function profile() {
    return [navBar(null, null, null), h('h1', 'k-large-title', t('tabs.profile')), profileForm(refresh)];
}

const VIEWS = { discover, matches, profile };

function renderTabbar() {
    const bar = document.getElementById('tabbar');
    bar.hidden = !state.me;
    bar.replaceChildren(...TABS.map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        state.tab = id;
        state.chat = null;
        closeSheet();
        refresh();
    }, icon(iconName), h('span', '', t(`tabs.${id}`)))));
}

function renderMatchNotice() {
    document.querySelector('.match')?.remove();
    if (!matchNotice) return;

    const notice = matchNotice;
    matchNotice = null;

    const node = h('div', 'match', null,
        h('div', 'match__title', t('match.title')),
        h('p', 'match__text', t('match.text', notice.name)),
        lazyImage('match__image', () => photo(notice.profileId, 1)),
        button('k-button match__button', t('match.chat'), async () => {
            node.remove();
            state.tab = 'matches';
            await refresh();
            const match = state.matches.find((item) => item.profileId === notice.profileId);
            if (match) openChat(match);
        }),
        button('k-link match__later', t('match.later'), () => node.remove()),
    );

    document.body.append(node);
}

function render() {
    const content = document.getElementById('content');
    content.replaceChildren(...(state.me ? VIEWS[state.tab]() : welcome(refresh)).flat(Infinity).filter(Boolean));
    renderTabbar();
    renderMatchNotice();
}

async function loadDeck() {
    const result = await call('deck');
    state.deck = result.ok && Array.isArray(result.result) ? result.result : [];
    photoIndex = 0;
}

async function refresh() {
    const me = await call('me');
    if (!me.ok) return;

    state.me = me.result.profile || null;

    if (state.me && state.tab === 'discover' && state.deck.length === 0) await loadDeck();

    if (state.me && state.tab === 'matches') {
        const result = await call('matches');
        state.matches = result.ok && Array.isArray(result.result) ? result.result : [];
    }

    render();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        setLanguage(message.language);
        render();
    }

    // A new message or match: reload the chat on screen, or the matches list
    if (message.type === 'city_phone:message' && message.data?.action === 'refresh') {
        if (state.chat && state.chat.match.id === message.data.match) loadChat();
        else if (state.tab === 'matches' && !state.chat) refresh();
    }
});

async function start() {
    await loadTexts();
    setChatRefresh(refresh);
    await refresh();
}

start();
