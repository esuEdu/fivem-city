// The player: a queue played through YouTube's iframe player (hidden) or an <audio> for direct links, with
// shuffle, repeat (off / all / one), seeking and volume. Others are told through onChange; the island through
// the nowPlaying callback.
import { call } from './lib.js';

const listeners = new Set();

export const player = {
    queue: [],
    order: [],
    position: -1,
    playing: false,
    shuffle: false,
    repeat: 'off',
    time: 0,
    duration: 0,
    volume: 70,
    failed: false,
};

let youtube = null;
let youtubeReady = null;
const audio = new Audio();
let source = null;

export function onChange(fn) {
    listeners.add(fn);
}

function emit() {
    for (const fn of listeners) fn();
}

export function current() {
    return player.queue[player.order[player.position]] || null;
}

function tellIsland() {
    const track = current();
    call('nowPlaying', track && player.playing ? { title: track.title, artist: track.artist } : {});
}

// YouTube's iframe API, loaded the first time a YouTube song plays
function loadYoutube() {
    if (youtubeReady) return youtubeReady;

    youtubeReady = new Promise((resolve) => {
        const holder = document.createElement('div');
        holder.id = 'yt-player';
        document.body.append(holder);

        window.onYouTubeIframeAPIReady = () => {
            youtube = new window.YT.Player('yt-player', {
                width: 200,
                height: 200,
                playerVars: { autoplay: 1, controls: 0, disablekb: 1, playsinline: 1 },
                events: {
                    onReady: () => resolve(youtube),
                    onStateChange: (event) => {
                        if (source !== 'youtube') return;
                        if (event.data === window.YT.PlayerState.ENDED) ended();
                        if (event.data === window.YT.PlayerState.PLAYING) setPlaying(true);
                        if (event.data === window.YT.PlayerState.PAUSED) setPlaying(false);
                    },
                    // Videos that can't be played outside YouTube (embedding off, region, removed)
                    onError: () => {
                        if (source !== 'youtube') return;
                        player.failed = true;
                        setPlaying(false);
                        emit();
                        setTimeout(() => { if (player.failed) next(); }, 1500);
                    },
                },
            });
        };

        const script = document.createElement('script');
        script.src = 'https://www.youtube.com/iframe_api';
        document.head.append(script);
    });

    return youtubeReady;
}

function setPlaying(playing) {
    if (player.playing === playing) return;
    player.playing = playing;
    tellIsland();
    emit();
}

function stopAll() {
    audio.pause();
    if (youtube?.stopVideo) youtube.stopVideo();
}

async function start() {
    const track = current();
    if (!track) return;

    stopAll();
    player.failed = false;
    player.time = 0;
    player.duration = 0;
    source = track.kind;
    emit();

    if (track.kind === 'youtube') {
        const yt = await loadYoutube();
        if (current() !== track) return;
        yt.setVolume(player.volume);
        yt.loadVideoById(track.ref);
    } else {
        audio.src = track.ref;
        audio.volume = player.volume / 100;
        audio.play().catch(() => {
            player.failed = true;
            emit();
        });
    }

    player.playing = true;
    tellIsland();
}

function makeOrder(startAt) {
    const indexes = player.queue.map((_, index) => index);

    if (player.shuffle) {
        indexes.splice(indexes.indexOf(startAt), 1);
        for (let i = indexes.length - 1; i > 0; i -= 1) {
            const j = Math.floor(Math.random() * (i + 1));
            [indexes[i], indexes[j]] = [indexes[j], indexes[i]];
        }
        indexes.unshift(startAt);
        player.order = indexes;
        player.position = 0;
    } else {
        player.order = indexes;
        player.position = startAt;
    }
}

// Plays a list of tracks starting at one of them
export function playList(tracks, index = 0) {
    if (!tracks.length) return;
    player.queue = tracks.slice();
    makeOrder(Math.max(0, Math.min(index, tracks.length - 1)));
    start();
}

export function toggle() {
    const track = current();
    if (!track) return;

    if (player.playing) {
        if (source === 'youtube') youtube?.pauseVideo(); else audio.pause();
        setPlaying(false);
    } else {
        if (source === 'youtube') youtube?.playVideo(); else audio.play().catch(() => {});
        setPlaying(true);
    }
}

export function next() {
    if (!player.queue.length) return;

    if (player.position + 1 < player.order.length) {
        player.position += 1;
    } else if (player.repeat === 'all') {
        if (player.shuffle) makeOrder(player.order[0]);
        player.position = 0;
    } else {
        stopAll();
        setPlaying(false);
        return;
    }

    start();
}

export function previous() {
    if (!player.queue.length) return;

    // Past the first seconds, "previous" goes back to the start of the song
    if (player.time > 3 || player.position === 0) return seek(0);

    player.position -= 1;
    start();
}

function ended() {
    if (player.repeat === 'one') {
        seek(0);
        if (source === 'youtube') youtube?.playVideo(); else audio.play().catch(() => {});
        return;
    }
    next();
}

export function seek(seconds) {
    if (source === 'youtube') youtube?.seekTo(seconds, true); else audio.currentTime = seconds;
    player.time = seconds;
    emit();
}

export function setVolume(volume) {
    player.volume = Math.max(0, Math.min(100, volume));
    audio.volume = player.volume / 100;
    youtube?.setVolume?.(player.volume);
}

export function toggleShuffle() {
    player.shuffle = !player.shuffle;
    const playingIndex = player.order[player.position];
    if (playingIndex !== undefined) makeOrder(playingIndex);
    emit();
}

export function cycleRepeat() {
    player.repeat = player.repeat === 'off' ? 'all' : player.repeat === 'all' ? 'one' : 'off';
    emit();
}

audio.addEventListener('ended', () => { if (source === 'url') ended(); });
audio.addEventListener('error', () => {
    if (source !== 'url' || !audio.src) return;
    player.failed = true;
    setPlaying(false);
    emit();
});

// The progress bar moves twice a second while something plays
setInterval(() => {
    if (!player.playing) return;

    if (source === 'youtube' && youtube?.getCurrentTime) {
        player.time = youtube.getCurrentTime() || 0;
        player.duration = youtube.getDuration() || 0;
    } else if (source === 'url') {
        player.time = audio.currentTime || 0;
        player.duration = Number.isFinite(audio.duration) ? audio.duration : 0;
    }

    emit();
}, 500);
