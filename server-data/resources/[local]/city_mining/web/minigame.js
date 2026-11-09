// The two minigames. Strikes: a marker sweeps the bar and each key press (sent by Lua as `press`) is a strike, a hit
// inside the zone, perfect inside its centre. Pan: hold the key (Lua sends `hold`) to move the marker right and keep it
// inside the drifting band. Each reports once; the server checks the time and decides what the work gives.

const $ = (id) => document.getElementById(id);
const resource = location.hostname.replace(/^cfx-nui-/, '') || 'city_mining';

let strikes = null;
let pan = null;

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        document.documentElement.style.setProperty(`--${key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`, value);
    }
}

function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => null);
}

function hideAll() {
    strikes = null;
    pan = null;
    $('strikes').classList.add('hidden');
    $('pan').classList.add('hidden');
}

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

/* ---------- strikes ---------- */

function placeZone() {
    const game = strikes;
    game.zoneStart = 0.08 + Math.random() * (0.84 - game.zone);
    const zone = $('strikes-zone');
    zone.style.left = `${game.zoneStart * 100}%`;
    zone.style.width = `${game.zone * 100}%`;
    $('strikes-perfect').style.width = `${(game.perfect / game.zone) * 100}%`;
}

function drawPips() {
    const game = strikes;
    const pips = $('strikes-pips');
    pips.replaceChildren();

    for (let i = 0; i < game.total; i++) {
        const pip = document.createElement('i');
        if (game.results[i]) pip.className = game.results[i];
        pips.append(pip);
    }
}

function startStrikes(data) {
    hideAll();

    strikes = {
        total: data.strikes,
        sweep: Math.max(0.4, data.sweep) * 1000,
        zone: data.zone,
        perfect: data.perfect,
        minMs: data.minSeconds * 1000,
        results: [],
        perfectCount: 0,
        started: performance.now(),
        done: false,
    };

    $('strikes-label').textContent = data.label || '';
    $('strikes-hint').textContent = data.hint || '';
    placeZone();
    drawPips();
    $('strikes').classList.remove('hidden');

    requestAnimationFrame(frameStrikes);
}

function markerPosition(game, now) {
    // Triangle wave: 0 -> 1 -> 0 over two sweeps
    const t = ((now - game.started) / game.sweep) % 2;
    return t < 1 ? t : 2 - t;
}

function frameStrikes(now) {
    const game = strikes;
    if (!game || game.done) return;

    $('strikes-marker').style.left = `${markerPosition(game, now) * 100}%`;

    if (game.results.length >= game.total && now - game.started >= game.minMs) {
        game.done = true;
        post('strikesDone', { perfect: game.perfectCount });
        hideAll();
        return;
    }

    requestAnimationFrame(frameStrikes);
}

function flash(kind) {
    const track = $('strikes-track');
    track.classList.remove('flash-hit', 'flash-perfect', 'flash-miss');
    void track.offsetWidth;
    track.classList.add(`flash-${kind}`);
}

function press() {
    const game = strikes;
    if (!game || game.done || game.results.length >= game.total) return;

    const at = markerPosition(game, performance.now());
    const centre = game.zoneStart + game.zone / 2;
    let result = 'miss';

    if (Math.abs(at - centre) <= game.perfect / 2) result = 'perfect';
    else if (at >= game.zoneStart && at <= game.zoneStart + game.zone) result = 'hit';

    if (result === 'perfect') game.perfectCount++;
    game.results.push(result);
    flash(result);
    drawPips();
    placeZone();
}

/* ---------- pan ---------- */

function startPan(data) {
    hideAll();

    pan = {
        ms: Math.max(4, data.seconds) * 1000,
        band: data.band,
        drift: data.drift,
        bandPos: 0.5 - data.band / 2,
        bandVel: 0,
        marker: 0.5,
        markerVel: 0,
        holding: false,
        inside: 0,
        elapsed: 0,
        last: performance.now(),
        done: false,
    };

    $('pan-label').textContent = data.label || '';
    $('pan-hint').textContent = data.hint || '';
    $('pan-band').style.width = `${data.band * 100}%`;
    $('pan').classList.remove('hidden');

    requestAnimationFrame(framePan);
}

function framePan(now) {
    const game = pan;
    if (!game || game.done) return;

    const dt = Math.min(0.05, (now - game.last) / 1000);
    game.last = now;
    game.elapsed += dt * 1000;

    // The band wanders; the marker rises while held and falls back otherwise
    game.bandVel += (Math.random() - 0.5) * game.drift * dt * 6;
    game.bandVel = clamp(game.bandVel, -game.drift, game.drift);
    game.bandPos = clamp(game.bandPos + game.bandVel * dt, 0, 1 - game.band);
    if (game.bandPos === 0 || game.bandPos === 1 - game.band) game.bandVel = -game.bandVel;

    game.markerVel += (game.holding ? 1.6 : -1.6) * dt;
    game.markerVel = clamp(game.markerVel, -0.9, 0.9);
    game.marker = clamp(game.marker + game.markerVel * dt, 0, 1);
    if (game.marker === 0 || game.marker === 1) game.markerVel = 0;

    const inside = game.marker >= game.bandPos && game.marker <= game.bandPos + game.band;
    if (inside) game.inside += dt * 1000;

    $('pan-band').style.left = `${game.bandPos * 100}%`;
    $('pan-band').classList.toggle('inside', inside);
    $('pan-marker').style.left = `${game.marker * 100}%`;
    $('pan-kept').style.width = `${(game.inside / Math.max(1, game.elapsed)) * 100}%`;
    $('pan-time').textContent = `${Math.max(0, Math.ceil((game.ms - game.elapsed) / 1000))}s`;

    if (game.elapsed >= game.ms) {
        game.done = true;
        post('panDone', { kept: game.inside / game.elapsed });
        hideAll();
        return;
    }

    requestAnimationFrame(framePan);
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'theme': applyTheme(message.data); break;
        case 'strikes': startStrikes(message.data); break;
        case 'press': press(); break;
        case 'pan': startPan(message.data); break;
        case 'hold': if (pan) pan.holding = message.value === true; break;
        case 'hide': hideAll(); break;
        default: break;
    }
});
