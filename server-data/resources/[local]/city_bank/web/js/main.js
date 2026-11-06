import { post, applyTheme, createElement, formatMoney, formatTime } from './util.js';

const HOLD_MS = 1400;
const RING = 2 * Math.PI * 54;

const state = { labels: {}, currency: '$', data: null };

const $ = (id) => document.getElementById(id);

function label(key, ...values) {
    let text = state.labels[key] ?? key;
    for (const value of values) text = text.replace('%s', value);
    return text;
}

function applyLabels() {
    for (const node of document.querySelectorAll('[data-label]')) {
        node.textContent = label(node.dataset.label);
    }
}

// reason 'shop-water' -> 'Shop purchase'; unknown reasons fall back to 'Other'
function reasonLabel(reason) {
    const key = `reason_${String(reason).split('-')[0]}`;
    return state.labels[key] ?? label('reason_other');
}

function renderActivity(history) {
    const list = $('activity');
    list.replaceChildren();

    $('activity-empty').classList.toggle('hidden', history.length > 0);

    for (const entry of history) {
        const item = createElement('li', 'activity__item');
        const info = createElement('div', 'activity__info');

        info.append(
            createElement('span', 'activity__reason', reasonLabel(entry.reason)),
            createElement('span', 'activity__time', formatTime(entry.time)),
        );

        const amount = createElement('div', 'activity__amounts');
        const delta = createElement('span', `activity__delta ${entry.delta < 0 ? 'is-out' : 'is-in'}`,
            formatMoney(entry.delta, state.currency, true));

        amount.append(delta, createElement('span', 'activity__after mono', formatMoney(entry.balance_after, state.currency)));
        item.append(info, amount);
        list.append(item);
    }
}

function renderBank(data) {
    $('greeting').textContent = label('greeting', data.firstname || '');
    $('stat-balance').textContent = formatMoney(data.balance, state.currency);
    $('stat-cash').textContent = formatMoney(data.cash, state.currency);
    $('stat-income').textContent = formatMoney(data.income, state.currency);
    $('stat-expenses').textContent = formatMoney(data.expenses, state.currency);
    $('account-number').textContent = data.number || '';

    const status = $('account-status');
    status.textContent = label(data.frozen ? 'status_frozen' : 'status_active');
    status.classList.toggle('pill--danger', Boolean(data.frozen));

    renderActivity(Array.isArray(data.history) ? data.history : []);
}

function show(view) {
    $('identity').classList.toggle('hidden', view !== 'identity');
    $('bank').classList.toggle('hidden', view !== 'bank');
}

/* Fingerprint scanner: hold the button until the ring fills */

let holdStart = 0;
let holdFrame = 0;
let scanned = false;

function setProgress(fraction) {
    $('scanner-progress').style.strokeDashoffset = String(RING * (1 - fraction));
}

function resetScanner() {
    scanned = false;
    cancelAnimationFrame(holdFrame);
    setProgress(0);
    $('scanner').classList.remove('is-scanning', 'is-done', 'is-failed');
    $('scanner-status').textContent = label('identity_hold');
    $('identity-continue').disabled = true;
}

async function finishScan() {
    $('scanner-status').textContent = label('identity_scanning');

    const result = await post('registerFingerprint');

    $('scanner').classList.remove('is-scanning');

    if (!result || !result.ok) {
        $('scanner').classList.add('is-failed');
        $('scanner-status').textContent = label('identity_failed');
        setProgress(0);
        return;
    }

    scanned = true;
    state.data = result;
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
    if (!state.data) return;

    renderBank(state.data);
    show('bank');
});

/* Closing */

function requestClose() {
    post('close');
}

$('identity-close').addEventListener('click', requestClose);
$('bank-close').addEventListener('click', requestClose);

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') requestClose();
});

/* Messages from Lua */

window.addEventListener('message', ({ data: message }) => {
    switch (message.action) {
        case 'setup':
            applyTheme(message.theme);
            state.labels = message.labels || {};
            state.currency = message.currency || '$';
            applyLabels();
            break;

        case 'open':
            state.data = message.data;
            $('branch').textContent = message.branch || '';

            if (message.data.fingerprint) {
                renderBank(message.data);
                show('bank');
            } else {
                resetScanner();
                show('identity');
            }
            break;

        case 'close':
            show(null);
            state.data = null;
            break;
    }
});

$('scanner-progress').style.strokeDasharray = String(RING);
setProgress(0);
post('ready');
