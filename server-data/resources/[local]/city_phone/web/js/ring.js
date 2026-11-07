// Ringtones, made with Web Audio (our own melodies, no audio files). Each ringing phone nearby plays its tone at the
// volume Lua works out from the distance; your own phone in silent mode only buzzes.
const NOTES = { C5: 523.3, D5: 587.3, E5: 659.3, G5: 784.0, A5: 880.0, C6: 1046.5, E6: 1318.5, G4: 392.0, B4: 493.9 };

// [note, start (s), length (s)] then the loop length
export const TONES = {
    classic: { wave: 'square', notes: [['E6', 0, 0.08], ['C6', 0.1, 0.08], ['E6', 0.2, 0.08], ['C6', 0.3, 0.08], ['E6', 0.6, 0.08], ['C6', 0.7, 0.08], ['E6', 0.8, 0.08], ['C6', 0.9, 0.08]], loop: 2.2 },
    marimba: { wave: 'sine', notes: [['C5', 0, 0.18], ['E5', 0.15, 0.18], ['G5', 0.3, 0.18], ['C6', 0.45, 0.3], ['G5', 0.8, 0.18], ['E5', 0.95, 0.18], ['G5', 1.1, 0.35]], loop: 1.9 },
    chime: { wave: 'triangle', notes: [['G5', 0, 0.5], ['E5', 0.5, 0.5], ['C5', 1.0, 0.5], ['G4', 1.5, 0.9]], loop: 3.0 },
    pulse: { wave: 'sawtooth', notes: [['A5', 0, 0.12], ['A5', 0.2, 0.12], ['A5', 0.4, 0.12], ['D5', 0.7, 0.3]], loop: 1.6 },
};

const BUZZ = { wave: 'sawtooth', freq: 140, pulses: [[0, 0.35], [0.5, 0.35]], loop: 1.8, volume: 0.12 };

let context = null;
// id -> { tone, gain, timer, vibrate }
const players = new Map();

function audio() {
    context ||= new AudioContext();
    return context;
}

function note(ctx, out, wave, freq, start, length) {
    const osc = ctx.createOscillator();
    const env = ctx.createGain();

    osc.type = wave;
    osc.frequency.value = freq;
    env.gain.setValueAtTime(0, start);
    env.gain.linearRampToValueAtTime(0.25, start + 0.01);
    env.gain.exponentialRampToValueAtTime(0.001, start + length);

    osc.connect(env).connect(out);
    osc.start(start);
    osc.stop(start + length + 0.05);
}

function playOnce(entry) {
    const ctx = audio();
    const now = ctx.currentTime + 0.02;

    if (entry.vibrate) {
        for (const [start, length] of BUZZ.pulses) note(ctx, entry.buzzGain, BUZZ.wave, BUZZ.freq, now + start, length);
    }

    const tone = TONES[entry.tone];
    if (tone && entry.gain.gain.value > 0.001) {
        for (const [name, start, length] of tone.notes) note(ctx, entry.gain, tone.wave, NOTES[name], now + start, length);
    }
}

function start(ring) {
    const ctx = audio();
    const gain = ctx.createGain();
    const buzzGain = ctx.createGain();

    gain.gain.value = ring.volume;
    buzzGain.gain.value = BUZZ.volume;
    gain.connect(ctx.destination);
    buzzGain.connect(ctx.destination);

    const entry = { tone: ring.tone, gain, buzzGain, vibrate: ring.vibrate === true };
    const loop = Math.max(TONES[ring.tone]?.loop || 2, BUZZ.loop);

    playOnce(entry);
    entry.timer = setInterval(() => playOnce(entry), loop * 1000);
    players.set(ring.id, entry);
}

function stop(id) {
    const entry = players.get(id);
    if (!entry) return;

    clearInterval(entry.timer);
    entry.gain.disconnect();
    entry.buzzGain.disconnect();
    players.delete(id);
}

// The list of phones ringing in earshot right now, every quarter second while any rings
export function setRings(rings) {
    const seen = new Set();

    for (const ring of rings || []) {
        seen.add(ring.id);

        const entry = players.get(ring.id);
        if (entry && entry.tone === ring.tone) entry.gain.gain.value = ring.volume;
        else {
            stop(ring.id);
            start(ring);
        }
    }

    for (const id of [...players.keys()]) if (!seen.has(id)) stop(id);
}

// Settings: a few seconds of a tone
export function preview(tone) {
    const entry = { tone, gain: audio().createGain(), buzzGain: audio().createGain(), vibrate: false };
    entry.gain.gain.value = 0.8;
    entry.gain.connect(audio().destination);
    playOnce(entry);
    setTimeout(() => entry.gain.disconnect(), 3500);
}
