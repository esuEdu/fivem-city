// The library (your saved songs and playlists), a playlist's page, and a song's menu (save, add to a playlist,
// remove)
import {
    state, call, t, h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, cover, reasonText, sameTrack,
} from './lib.js';
import { playList, current, player } from './player.js';

let refresh = async () => {};

export function setRefresh(fn) {
    refresh = fn;
}

export function savedId(track) {
    return state.tracks.find((saved) => sameTrack(saved, track))?.id;
}

export async function save(track) {
    const result = await call('addTrack', { kind: track.kind, ref: track.ref, title: track.title, artist: track.artist });
    if (!result.ok) {
        toast(reasonText(result.reason));
        return null;
    }

    toast(t('track.saved'));
    await refresh();
    return result.result;
}

// One row: tap plays the list from it; ⋯ opens the song's menu
export function trackRow(track, list, index, extra = {}) {
    const playingNow = sameTrack(current(), track) && player.playing;

    return button(`k-item track${playingNow ? ' track--playing' : ''}`, null, () => playList(list, index),
        cover(track),
        h('span', 'k-item__main', null,
            h('span', 'k-item__title', track.title),
            h('span', 'k-item__subtitle', track.artist || (track.kind === 'url' ? t('track.link') : 'YouTube')),
        ),
        iconButton('track__more', 'info', (event) => {
            event.stopPropagation();
            trackMenu(track, extra);
        }),
    );
}

function pickPlaylist(trackId) {
    openSheet(
        navBar(backButton(t('back'), closeSheet), t('playlist.addTo'), null),
        state.playlists.length
            ? h('div', 'k-list', null, state.playlists.map((playlist) => button('k-item', null, async () => {
                const result = await call('addToPlaylist', { playlist: playlist.id, track: trackId });
                if (!result.ok) return toast(reasonText(result.reason));
                toast(t('playlist.added', playlist.name));
                closeSheet();
                await refresh();
            }, h('span', 'playlist__icon', null, icon('star')), h('span', 'k-item__main', null, h('span', 'k-item__title', playlist.name)))))
            : h('div', 'k-empty', null, icon('star'), h('span', '', t('playlist.none'))),
    );
}

// extra.playlist: the playlist the row is shown in (adds "remove from this playlist")
export function trackMenu(track, extra = {}) {
    const id = savedId(track);

    openSheet(
        navBar(backButton(t('back'), closeSheet), null, null),
        h('div', 'menu__head', null, cover(track, 'cover cover--big'), h('div', 'menu__title', track.title), h('div', 'menu__artist', track.artist || '')),
        h('div', 'k-group', null,
            id ? null : button('k-row k-row--accent', t('track.save'), async () => { await save(track); closeSheet(); }),
            button('k-row k-row--accent', t('track.addToPlaylist'), async () => {
                const trackId = id || await save(track);
                if (trackId) pickPlaylist(trackId);
            }),
            extra.playlist ? button('k-row k-row--danger', t('track.removeFromPlaylist'), async () => {
                if (!(await call('removeFromPlaylist', { playlist: extra.playlist.id, track: id })).ok) return toast(reasonText());
                closeSheet();
                await refresh();
                openPlaylist(extra.playlist);
            }) : null,
            id && !extra.playlist ? button('k-row k-row--danger', t('track.remove'), async () => {
                if (!(await call('removeTrack', { id })).ok) return toast(reasonText());
                toast(t('track.removed'));
                closeSheet();
                await refresh();
            }) : null,
        ),
    );
}

export async function openPlaylist(playlist) {
    const result = await call('playlist', { id: playlist.id });
    const tracks = result.ok && Array.isArray(result.result) ? result.result : [];

    const rename = async () => {
        const name = input('k-field', t('playlist.name'), 40);
        name.value = playlist.name;
        openSheet(
            navBar(button('k-link', t('cancel'), () => openPlaylist(playlist)), t('playlist.rename'), button('k-link', t('done'), async () => {
                if (!(await call('renamePlaylist', { id: playlist.id, name: name.value })).ok) return toast(reasonText());
                playlist.name = name.value.trim();
                await refresh();
                openPlaylist(playlist);
            })),
            h('div', 'k-group', null, name),
        );
    };

    openSheet(
        navBar(backButton(t('tabs.library'), closeSheet), null, button('k-link', t('playlist.rename'), rename)),
        h('div', 'playlist__head', null,
            h('span', 'playlist__art', null, icon('star')),
            h('h1', 'playlist__name', playlist.name),
            h('span', 'playlist__count', t('playlist.count', tracks.length)),
            tracks.length ? h('div', 'playlist__buttons', null,
                button('pill pill--play', t('play'), () => playList(tracks, 0)),
                button('pill', t('shuffle'), () => {
                    player.shuffle = true;
                    playList(tracks, Math.floor(Math.random() * tracks.length));
                }),
            ) : null,
        ),
        tracks.length
            ? h('div', 'k-list', null, tracks.map((track, index) => trackRow(track, tracks, index, { playlist })))
            : h('div', 'k-empty', null, icon('plus'), h('span', '', t('playlist.empty'))),
        h('div', 'k-group', null, button('k-row k-row--danger', t('playlist.delete'), async () => {
            if (!(await call('deletePlaylist', { id: playlist.id })).ok) return toast(reasonText());
            closeSheet();
            await refresh();
        })),
    );
}

function newPlaylist() {
    const name = input('k-field', t('playlist.name'), 40);

    openSheet(
        navBar(button('k-link', t('cancel'), closeSheet), t('playlist.new'), button('k-link', t('done'), async () => {
            const result = await call('createPlaylist', { name: name.value });
            if (!result.ok) return toast(reasonText(result.reason));
            closeSheet();
            await refresh();
        })),
        h('div', 'k-group', null, name),
    );
}

export function library() {
    return [
        navBar(null, null, button('k-link', null, newPlaylist, icon('plus'))),
        h('h1', 'k-large-title', t('tabs.library')),
        h('p', 'k-group__label', t('library.playlists')),
        state.playlists.length
            ? h('div', 'k-list', null, state.playlists.map((playlist) => button('k-item', null, () => openPlaylist(playlist),
                h('span', 'playlist__icon', null, icon('star')),
                h('span', 'k-item__main', null, h('span', 'k-item__title', playlist.name), h('span', 'k-item__subtitle', t('playlist.count', playlist.count))),
            )))
            : h('p', 'hint', t('library.noPlaylists')),
        h('p', 'k-group__label', t('library.songs', state.tracks.length)),
        state.tracks.length
            ? h('div', 'k-list', null, state.tracks.map((track, index) => trackRow(track, state.tracks, index)))
            : h('div', 'k-empty', null, icon('heart'), h('span', '', t('library.empty'))),
    ];
}
