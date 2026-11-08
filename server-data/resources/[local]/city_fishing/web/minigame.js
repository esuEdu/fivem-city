// The catch minigame (research section 5): hold the action key to raise the bar, keep the fish inside it until the
// meter fills. The Lua side sends `hold` as the key changes; this page runs a fixed 60 Hz simulation and reports the
// result once. The server checks the time it took and decides the fish, size and stars itself.

const $ = (id) => document.getElementById(id);
const resource = location.hostname.replace(/^cfx-nui-/, '') || 'city_fishing';

const TICK = 1000 / 60;
const FISH_SIZE = 30;
const CHEST_SIZE = 26;

let game = null;
let holding = false;

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

function show(id) {
    for (const other of ['power', 'bite', 'game']) $(other).classList.toggle('hidden', other !== id);
}

function hideAll() {
    game = null;
    holding = false;
    for (const id of ['power', 'bite', 'game']) $(id).classList.add('hidden');
}

const rand = (min, max) => min + Math.random() * (max - min);
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

function start(data, config) {
    const height = config.height;
    const bar = data.bar;

    game = {
        data,
        config,
        height,
        bar,
        barPos: 0,
        barVel: 0,
        // The fish starts inside the bar, so the first frame isn't an escape
        fishPos: Math.max(0, bar / 2 - FISH_SIZE / 2),
        fishVel: 0,
        fishTarget: Math.max(0, bar / 2 - FISH_SIZE / 2),
        fishExtra: 0,
        progress: config.start,
        outside: 0,
        perfect: true,
        escapes: 0,
        wasInside: true,
        chest: data.chest ? { at: data.chestDelay, shown: false, pos: 0, progress: 0, taken: false } : null,
        elapsed: 0,
        last: performance.now(),
        acc: 0,
        done: false,
    };

    $('game-label').textContent = data.label || '';
    $('crown').classList.toggle('hidden', !data.crown);
    $('chest').classList.add('hidden');
    $('lives').classList.toggle('hidden', !data.challenge);
    $('bar').style.height = `calc(${bar}px * var(--scale))`;
    drawLives();
    show('game');

    requestAnimationFrame(frame);
}

function drawLives() {
    if (!game || !game.data.challenge) return;
    $('lives').textContent = '●'.repeat(Math.max(0, 3 - game.escapes)) + '○'.repeat(Math.min(3, game.escapes));
}

function moveFish(g) {
    const d = g.data.difficulty;
    const behavior = g.data.behavior;
    const smooth = behavior === 'smooth';
    const top = g.height - FISH_SIZE;

    if (Math.random() < (d * (smooth ? 20 : 1)) / 4000) {
        const pct = Math.min(99, d + rand(10, 45)) / 100;
        g.fishTarget = clamp(g.fishPos + rand(-g.fishPos, top - g.fishPos) * pct, 0, top);
    }

    if (behavior === 'floater') g.fishExtra = Math.min(g.fishExtra + 0.01, 1.5);
    if (behavior === 'sinker') g.fishExtra = Math.max(g.fishExtra - 0.01, -1.5);

    if (Math.abs(g.fishPos - g.fishTarget) > 3) {
        const accel = (g.fishTarget - g.fishPos) / (rand(10, 30) + (100 - Math.min(100, d)));
        g.fishVel += (accel - g.fishVel) / 5;
    } else if (!smooth && Math.random() < d / 2000) {
        g.fishTarget = clamp(g.fishPos + (Math.random() < 0.5 ? -1 : 1) * rand(50, 100), 0, top);
    }

    if (behavior === 'dart' && Math.random() < d / 1000) {
        g.fishTarget = clamp(g.fishPos + (Math.random() < 0.5 ? -1 : 1) * rand(50, 100 + d * 2), 0, top);
    }

    g.fishPos = clamp(g.fishPos + g.fishVel + g.fishExtra, 0, top);
}

function moveBar(g) {
    const top = g.height - g.bar;

    g.barVel += holding ? 0.25 : -0.25;

    // Barbed hook: the bar is pulled toward the fish while it's on top of it
    if (g.data.barbed > 0 && inside(g)) {
        const fishCenter = g.fishPos + FISH_SIZE / 2;
        const barCenter = g.barPos + g.bar / 2;
        g.barVel += (fishCenter - barCenter) * 0.002 * g.data.barbed;
    }

    g.barPos += g.barVel;

    if (g.barPos <= 0) {
        g.barPos = 0;
        const bounce = g.data.lead >= 2 ? 0 : g.data.lead === 1 ? 1 / 3 : 2 / 3;
        g.barVel = -g.barVel * bounce;
        if (Math.abs(g.barVel) < 0.5) g.barVel = 0;
    } else if (g.barPos >= top) {
        g.barPos = top;
        g.barVel = 0;
    }
}

function inside(g) {
    const center = g.fishPos + FISH_SIZE / 2;
    return center >= g.barPos && center <= g.barPos + g.bar;
}

function step(g) {
    g.elapsed += TICK;

    moveFish(g);
    moveBar(g);

    const isInside = inside(g);
    const trap = g.data.trap >= 2 ? 0.5 : g.data.trap === 1 ? 0.67 : 1;

    if (isInside) {
        g.progress += g.config.gain / 60;
    } else {
        g.progress -= (g.config.loss / 60) * trap;
        g.outside += TICK / 1000;
        g.perfect = false;
    }

    if (g.wasInside && !isInside) {
        g.escapes += 1;
        drawLives();
    }
    g.wasInside = isInside;

    const chest = g.chest;
    if (chest && !chest.taken) {
        if (!chest.shown && g.elapsed >= chest.at) {
            chest.shown = true;
            chest.pos = rand(0, g.height - CHEST_SIZE);
        }

        if (chest.shown) {
            const center = chest.pos + CHEST_SIZE / 2;
            const over = center >= g.barPos && center <= g.barPos + g.bar;
            chest.progress = clamp(chest.progress + (over ? 0.0135 : -0.01), 0, 1);
            if (chest.progress >= 1) chest.taken = true;
        }
    }

    if (g.data.challenge && g.escapes >= 3) return finish(false);
    if (g.progress >= 1) return finish(true);
    if (g.progress <= 0) return finish(false);
}

function draw(g) {
    $('bar').style.bottom = `calc(${g.barPos}px * var(--scale))`;
    $('bar').classList.toggle('off', !inside(g));
    $('fish').style.bottom = `calc(${g.fishPos}px * var(--scale))`;

    const fill = $('progress');
    fill.style.height = `${clamp(g.progress, 0, 1) * 100}%`;
    fill.classList.toggle('low', g.progress < 0.25);
    fill.classList.toggle('mid', g.progress >= 0.25 && g.progress < 0.6);

    const chest = g.chest;
    const showChest = chest && chest.shown && !chest.taken;
    $('chest').classList.toggle('hidden', !showChest);
    if (showChest) {
        $('chest').style.bottom = `calc(${chest.pos}px * var(--scale))`;
        $('chest-fill').style.width = `${chest.progress * 100}%`;
    }
}

function frame(now) {
    const g = game;
    if (!g || g.done) return;

    g.acc += Math.min(250, now - g.last);
    g.last = now;

    while (g.acc >= TICK && !g.done) {
        g.acc -= TICK;
        step(g);
    }

    if (!g.done) {
        draw(g);
        requestAnimationFrame(frame);
    }
}

function finish(caught) {
    const g = game;
    g.done = true;

    post('minigameDone', {
        caught,
        perfect: caught && g.perfect,
        chest: !!(g.chest && g.chest.taken),
        outside: Math.round(g.outside * 100) / 100,
        escapes: g.escapes,
    });

    hideAll();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    switch (message.action) {
        case 'theme':
            applyTheme(message.data);
            break;
        case 'power':
            if (game) return;
            show('power');
            $('power-fill').style.width = `${clamp(Number(message.value) || 0, 0, 1) * 100}%`;
            break;
        case 'bite':
            if (game) return;
            show('bite');
            break;
        case 'minigame':
            start(message.data, message.config);
            break;
        case 'hold':
            holding = message.value === true;
            break;
        case 'hide':
            if (!game) hideAll();
            break;
    }
});

// Preview outside the game: ?preview opens a test catch driven by the space bar
if (location.search.includes('preview')) {
    applyTheme({ accent: '#f5c542', accentText: '#15181d', accentGlow: 'rgba(245,197,66,.45)', accentSoft: 'rgba(245,197,66,.1)', danger: '#e5484d', success: '#3ecf72', text: '#eef0f3', muted: '#7d8590', panel: 'rgba(12,13,18,.6)', section: 'rgba(255,255,255,.035)', border: 'rgba(255,255,255,.06)', radius: '10px', radiusLarge: '22px' });
    document.body.style.background = '#2b3a4a';
    window.addEventListener('keydown', (e) => { if (e.code === 'Space') holding = true; });
    window.addEventListener('keyup', (e) => { if (e.code === 'Space') holding = false; });
    start({ difficulty: 60, behavior: 'dart', bar: 150, chest: true, chestDelay: 1500, crown: false, label: 'Yellowtail', trap: 0, lead: 0, barbed: 0, challenge: false },
        { height: 568, start: 0.3, gain: 0.12, loss: 0.17 });
}
