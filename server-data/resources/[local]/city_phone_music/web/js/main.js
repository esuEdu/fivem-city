// The Music page: Search (by title, or paste a YouTube / audio link) and Library, a mini player above the tabs and
// the full player. It runs inside city_phone; data comes from our resource's callbacks.
import {
    state, call, t, h, button, iconButton, icon, toast, openSheet, closeSheet, navBar, applyContext, loadTexts, setLanguage,
    cover, clock, reasonText,
} from './lib.js';
import { player, onChange, current, toggle, next, previous, seek, setVolume, toggleShuffle, cycleRepeat, playList } from './player.js';
import { library, trackRow, save, savedId, setRefresh } from './library.js';

const TABS = [
    ['search', 'search'],
    ['library', 'star'],
];

const search = document.createElement('input');
let searching = false;
let fullOpen = false;

function isLink(text) {
    return /^https?:\/\//i.test(text.trim());
}

async function runSearch() {
    const query = search.value.trim();
    state.query = query;
    if (!query) {
        state.results = [];
        return render();
    }

    searching = true;
    render();

    const result = isLink(query) ? await call('lookup', { link: query }) : await call('search', { query });
    searching = false;

    if (!result.ok) {
        state.results = [];
        toast(reasonText(result.reason));
        return render();
    }

    state.results = Array.isArray(result.result) ? result.result : [result.result];
    render();
}

search.addEventListener('keydown', (event) => { if (event.key === 'Enter') runSearch(); });

function searchView() {
    search.placeholder = t(state.canSearch ? 'search.placeholder' : 'search.placeholderLink');

    let body;
    if (searching) body = h('div', 'k-empty', null, h('span', '', t('search.searching')));
    else if (state.results.length) {
        body = h('div', 'k-list', null, state.results.map((track, index) => {
            const row = trackRow(track, state.results, index);
            if (!savedId(track)) {
                row.append(iconButton('track__save', 'plus', async (event) => {
                    event.stopPropagation();
                    await save(track);
                    render();
                }));
            }
            return row;
        }));
    } else {
        body = h('div', 'k-empty', null, icon('search'), h('span', '', t(state.canSearch ? 'search.hint' : 'search.hintLink')));
    }

    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('tabs.search')),
        h('label', 'k-search', null, icon('search'), search),
        body,
    ];
}

const VIEWS = { search: searchView, library };

function miniPlayer() {
    const track = current();
    const bar = document.getElementById('mini');
    bar.hidden = !track;
    if (!track) return;

    const progress = player.duration ? (player.time / player.duration) * 100 : 0;

    bar.replaceChildren(
        h('div', 'mini__progress', null, Object.assign(h('span'), { style: `width:${progress}%` })),
        button('mini__info', null, openFull,
            cover(track),
            h('span', 'mini__text', null,
                h('span', 'mini__title', player.failed ? t('player.unavailable') : track.title),
                h('span', 'mini__artist', track.artist || ''),
            ),
        ),
        iconButton('mini__toggle', player.playing ? 'pause' : 'play', toggle),
        iconButton('mini__next', 'next', next),
    );
}

function fullPlayer() {
    const track = current();
    if (!track) {
        fullOpen = false;
        return closeSheet();
    }

    const range = document.createElement('input');
    range.type = 'range';
    range.className = 'full__seek';
    range.min = 0;
    range.max = Math.max(1, Math.floor(player.duration));
    range.value = Math.floor(player.time);
    range.addEventListener('change', () => seek(Number(range.value)));

    const volume = document.createElement('input');
    volume.type = 'range';
    volume.className = 'full__volume';
    volume.min = 0;
    volume.max = 100;
    volume.value = player.volume;
    volume.addEventListener('input', () => setVolume(Number(volume.value)));

    openSheet(
        navBar(button('k-link', null, () => { fullOpen = false; closeSheet(); }, icon('back')), t('player.title'), null),
        cover(track, 'cover cover--full'),
        h('div', 'full__head', null,
            h('span', 'full__text', null,
                h('span', 'full__title', track.title),
                h('span', 'full__artist', player.failed ? t('player.unavailable') : (track.artist || '')),
            ),
            savedId(track) ? null : iconButton('full__save', 'plus', async () => { await save(track); fullPlayer(); }),
        ),
        range,
        h('div', 'full__times', null, h('span', '', clock(player.time)), h('span', '', clock(player.duration))),
        h('div', 'full__controls', null,
            iconButton(`full__mode${player.shuffle ? ' full__mode--on' : ''}`, 'shuffle', toggleShuffle, t('shuffle')),
            iconButton('full__skip', 'previous', previous),
            iconButton('full__play', player.playing ? 'pause' : 'play', toggle),
            iconButton('full__skip', 'next', next),
            iconButton(`full__mode${player.repeat !== 'off' ? ' full__mode--on' : ''}`, player.repeat === 'one' ? 'repeatOne' : 'repeat', cycleRepeat, t('repeat')),
        ),
        h('div', 'full__volume-row', null, icon('volumeLow'), volume, icon('volume')),
    );
}

function openFull() {
    fullOpen = true;
    fullPlayer();
}

// The full player only redraws its moving parts while open, so the sliders can be dragged
function updateFull() {
    const seekBar = document.querySelector('.full__seek');
    if (!fullOpen || !seekBar) return;

    const track = current();
    const title = document.querySelector('.full__title');
    if (!track || title?.textContent !== track.title) return fullPlayer();

    if (document.activeElement !== seekBar) {
        seekBar.max = Math.max(1, Math.floor(player.duration));
        seekBar.value = Math.floor(player.time);
    }

    const times = document.querySelectorAll('.full__times span');
    times[0].textContent = clock(player.time);
    times[1].textContent = clock(player.duration);

    document.querySelector('.full__play').replaceChildren(icon(player.playing ? 'pause' : 'play'));
    document.querySelectorAll('.full__mode')[0].classList.toggle('full__mode--on', player.shuffle);
    const repeat = document.querySelectorAll('.full__mode')[1];
    repeat.classList.toggle('full__mode--on', player.repeat !== 'off');
    repeat.replaceChildren(icon(player.repeat === 'one' ? 'repeatOne' : 'repeat'));
}

function renderTabbar() {
    document.getElementById('tabbar').replaceChildren(...TABS.map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        state.tab = id;
        fullOpen = false;
        closeSheet();
        render();
    }, icon(iconName), h('span', '', t(`tabs.${id}`)))));
}

function render() {
    const content = document.getElementById('content');
    const top = content.scrollTop;
    const typing = document.activeElement === search;

    content.replaceChildren(...VIEWS[state.tab]().flat(Infinity).filter(Boolean));
    content.scrollTop = top;
    if (typing) search.focus();
    renderTabbar();
    miniPlayer();
}

async function refresh() {
    const result = await call('library');
    if (result.ok) {
        state.tracks = Array.isArray(result.result.tracks) ? result.result.tracks : [];
        state.playlists = Array.isArray(result.result.playlists) ? result.result.playlists : [];
    }
    render();
}

let lastKey = '';

// Songs changing or play/pause redraw the lists (which song is playing); the clock only moves the bars
onChange(() => {
    const track = current();
    const key = `${track?.kind}:${track?.ref}:${player.playing}:${player.failed}`;

    if (key !== lastKey) {
        lastKey = key;
        render();
    } else {
        miniPlayer();
    }

    updateFull();
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
    const canSearch = await call('canSearch');
    state.canSearch = canSearch.ok && canSearch.result === true;
    await refresh();
}

start();
