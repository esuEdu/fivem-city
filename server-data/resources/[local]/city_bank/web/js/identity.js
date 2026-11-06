import { post, label } from './util.js';

// First-visit fingerprint: hold the scanner until the ring fills, then the server registers it
const HOLD_MS = 1400;
const RING = 2 * Math.PI * 54;

const $ = (id) => document.getElementById(id);

let holdStart = 0;
let holdFrame = 0;
let scanned = false;
let result = null;

function setProgress(fraction) {
    $('scanner-progress').style.strokeDashoffset = String(RING * (1 - fraction));
}

export function resetIdentity() {
    scanned = false;
    result = null;
    cancelAnimationFrame(holdFrame);
    setProgress(0);
    $('scanner').classList.remove('is-scanning', 'is-done', 'is-failed');
    $('scanner-status').textContent = label('identity_hold');
    $('identity-continue').disabled = true;
}

async function finishScan() {
    $('scanner-status').textContent = label('identity_scanning');

    const reply = await post('registerFingerprint');

    $('scanner').classList.remove('is-scanning');

    if (!reply || !reply.ok) {
        $('scanner').classList.add('is-failed');
        $('scanner-status').textContent = label('identity_failed');
        setProgress(0);
        return;
    }

    scanned = true;
    result = reply;
    $('scanner').classList.add('is-done');
    $('scanner-status').textContent = label('identity_done');
    $('identity-continue').disabled = false;
}

function holdTick(now) {
    const fraction = Math.min((now - holdStart) / HOLD_MS, 1);
    setProgress(fraction);

    if (fraction >= 1) {
        finishScan();
        return;
    }

    holdFrame = requestAnimationFrame(holdTick);
}

export function setupIdentity({ onDone, onClose }) {
    $('scanner-progress').style.strokeDasharray = String(RING);
    setProgress(0);

    $('scanner').addEventListener('pointerdown', () => {
        if (scanned) return;

        $('scanner').classList.remove('is-failed');
        $('scanner').classList.add('is-scanning');
        $('scanner-status').textContent = label('identity_scanning');
        holdStart = performance.now();
        holdFrame = requestAnimationFrame(holdTick);
    });

    for (const type of ['pointerup', 'pointerleave']) {
        $('scanner').addEventListener(type, () => {
            if (scanned || !$('scanner').classList.contains('is-scanning')) return;

            cancelAnimationFrame(holdFrame);
            $('scanner').classList.remove('is-scanning');
            $('scanner-status').textContent = label('identity_hold');
            setProgress(0);
        });
    }

    $('identity-continue').addEventListener('click', () => {
        if (result) onDone(result);
    });

    $('identity-close').addEventListener('click', onClose);
}
