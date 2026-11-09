// The arrested player's screen and the security camera overlay (this resource's ui_page). Game data goes in with
// textContent only.

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_police';
const $ = (id) => document.getElementById(id);

function post(event, data = {}) {
    return fetch(`https://${RESOURCE}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => null);
}

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        document.documentElement.style.setProperty(`--${key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`, value);
    }
}

function showArrest(message) {
    const labels = message.labels || {};

    $('arrest-title').textContent = labels.title || '';
    $('arrest-months').textContent = labels.months || '';
    $('arrest-fine').textContent = labels.fine || '';
    $('arrest-charges-label').textContent = labels.charges || '';
    $('arrest-officer').textContent = labels.officer || '';
    $('arrest-ok').textContent = labels.ok || 'OK';
    $('arrest-charges').replaceChildren(...(message.charges || []).map((charge) => {
        const item = document.createElement('li');
        item.textContent = charge;
        return item;
    }));

    $('arrest').classList.remove('hidden');
    $('arrest-ok').focus();
}

function closeArrest() {
    $('arrest').classList.add('hidden');
    post('arrestClose');
}

function radarCell(side, reading, label) {
    $(`radar-${side}-label`).textContent = label || '';
    $(`radar-${side}-speed`).textContent = reading ? String(reading.speed) : '--';
    $(`radar-${side}-plate`).textContent = reading ? reading.plate : '';
}

function showRadar(message) {
    const labels = message.labels || {};

    radarCell('front', message.front, labels.front);
    radarCell('rear', message.rear, labels.rear);
    $('radar-own-label').textContent = labels.own || '';
    $('radar-own-speed').textContent = String(message.own);
    $('radar-lock').textContent = labels.locked || '';
    $('radar').classList.remove('hidden');
}

$('arrest-ok').addEventListener('click', closeArrest);
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !$('arrest').classList.contains('hidden')) closeArrest();
});

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message.action !== 'string') return;

    if (message.theme) applyTheme(message.theme);

    if (message.action === 'arrested') {
        showArrest(message);
    } else if (message.action === 'camera') {
        $('cam-label').textContent = `${message.label} (${message.index}/${message.total})`;
        $('cam-time').textContent = message.time;
        $('cam-offline').textContent = message.labels.offline;
        $('cam-offline').classList.toggle('hidden', message.online !== false);
        $('cam-help').textContent = message.labels.help;
        $('camera').classList.remove('hidden');
    } else if (message.action === 'cameraOff') {
        $('camera').classList.add('hidden');
    } else if (message.action === 'bodycam') {
        $('cam-label').textContent = `BODYCAM · ${message.label}`;
        $('cam-time').textContent = '';
        $('cam-offline').classList.add('hidden');
        $('cam-help').textContent = message.help;
        $('camera').classList.remove('hidden');
    } else if (message.action === 'radar') {
        showRadar(message);
    } else if (message.action === 'radarLock') {
        $('radar-lock').classList.toggle('hidden', !message.locked);
    } else if (message.action === 'radarOff') {
        $('radar').classList.add('hidden');
        $('radar-lock').classList.add('hidden');
    } else if (message.action === 'headBag') {
        $('head-bag').classList.toggle('hidden', !message.on);
    }
});
