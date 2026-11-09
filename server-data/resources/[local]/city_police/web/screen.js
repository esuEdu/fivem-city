// This resource's ui_page: the arrested player's screen, the camera overlay, the patrol radar, call popups, the
// round action menu and the patrol car menu. Game data goes in with textContent only.

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

const digits = (value) => String(Math.max(0, Math.min(999, value || 0))).padStart(3, '0');

function radarCell(side, reading, label) {
    $(`radar-${side}-label`).textContent = label || '';
    $(`radar-${side}-speed`).textContent = reading ? digits(reading.speed) : '---';
    $(`radar-${side}-plate`).textContent = reading ? reading.plate : '--------';
}

function showRadar(message) {
    const labels = message.labels || {};

    radarCell('front', message.front, labels.front);
    radarCell('rear', message.rear, labels.rear);
    $('radar-own-label').textContent = labels.own || '';
    $('radar-own-speed').textContent = digits(message.own);
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

// Icons for the round menu and the car menu (24x24 strokes)
const ICONS = {
    tablet: 'M6 3h12v18H6zM11 18h2',
    cuff: 'M8 9a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM16 9a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 13h0M8 9V6h8v3',
    link: 'M10 14a4 4 0 0 0 5.6 0l3-3a4 4 0 0 0-5.6-5.6l-1 1M14 10a4 4 0 0 0-5.6 0l-3 3a4 4 0 0 0 5.6 5.6l1-1',
    escort: 'M9 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM7 21l2-8-2-3 4-2 3 3 3 1M15 7a2 2 0 1 0 0-4 2 2 0 0 0 0 4z',
    car: 'M5 16h14v-4l-2-5H7l-2 5zM5 16v2M19 16v2M8 13h.01M16 13h.01',
    search: 'M11 4.5a6.5 6.5 0 1 1 0 13a6.5 6.5 0 1 1 0-13zM16 16l4.5 4.5',
    bill: 'M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6',
    eye: 'M2 12s3.5-6.5 10-6.5S22 12 22 12s-3.5 6.5-10 6.5S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
    anklet: 'M12 2v4M5 8a7 7 0 0 0 14 0M8 18a4 4 0 0 0 8 0M12 12v6',
    exit: 'M14 4h6v16h-6M4 12h11M11 8l4 4-4 4',
    tow: 'M3 17h2l1-5h12l1 5h2M6 12l2-4h8l2 4M7 20a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zM17 20a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z',
    seat: 'M7 4h5l1 9h5v4H8zM8 17v3M17 17v3',
    radar: 'M12 12l7-7M12 3a9 9 0 1 0 9 9M12 7a5 5 0 1 0 5 5',
    lock: 'M6 11h12v9H6zM8 11V7a4 4 0 0 1 8 0v4',
};

function svgIcon(name, size = 22) {
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('width', String(size));
    svg.setAttribute('height', String(size));
    const path = document.createElementNS(ns, 'path');
    path.setAttribute('d', ICONS[name] || ICONS.eye);
    svg.append(path);
    return svg;
}

function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined && text !== null) element.textContent = String(text);
    return element;
}

// Call popups: newest at the bottom; Lua removes them (time out, F10, F11, a full stack)
function showPopup(popup, labels) {
    const card = node('div', `popup${popup.urgent ? ' urgent' : ''}${popup.kind === 'code' ? ' code' : ''}`);
    card.dataset.key = popup.key;

    const head = node('div', 'popup-head');
    head.append(node('i', 'popup-dot'), node('span', 'popup-label', labels.header), node('span', 'popup-time', popup.time));

    const body = node('div', 'popup-body');
    const titleRow = node('div', 'popup-title');
    titleRow.append(node('span', 'popup-code', popup.code), node('strong', null, popup.title));
    body.append(titleRow);
    if (popup.text) body.append(node('p', 'popup-text', popup.text));
    if (popup.place) body.append(node('p', 'popup-place', popup.place));

    const keys = node('div', 'popup-keys');
    const gps = node('span', 'popup-key');
    gps.append(node('kbd', null, labels.gpsKey), document.createTextNode(` ${labels.gps}`));
    const dismiss = node('span', 'popup-key');
    dismiss.append(node('kbd', null, labels.dismissKey), document.createTextNode(` ${labels.dismiss}`));
    keys.append(gps, dismiss);

    const bar = node('div', 'popup-bar');
    bar.style.animationDuration = `${popup.seconds}s`;

    card.append(head, body, keys, bar);
    $('popups').append(card);
}

function removePopup(key) {
    const card = [...$('popups').children].find((child) => child.dataset.key === key);
    if (!card) return;

    card.classList.add('leaving');
    setTimeout(() => card.remove(), 250);
}

// The round menu: items around a center label; disabled ones show but can't be picked
function showRadial(menu, labels) {
    const ring = $('radial-ring');
    const items = menu.items || [];
    const radius = items.length > 6 ? 150 : 125;

    const center = node('button', 'radial-center');
    center.type = 'button';
    center.append(node('strong', null, menu.title), node('small', null, menu.subtitle || ''), node('em', null, labels.close));
    center.addEventListener('click', () => post('radialClose'));

    const buttons = items.map((item, index) => {
        const angle = (index / items.length) * Math.PI * 2 - Math.PI / 2;
        const button = node('button', `radial-item${item.disabled ? ' disabled' : ''}`);
        button.type = 'button';
        button.disabled = item.disabled === true;
        button.style.left = `calc(50% + ${Math.round(Math.cos(angle) * radius)}px)`;
        button.style.top = `calc(50% + ${Math.round(Math.sin(angle) * radius)}px)`;
        button.append(svgIcon(item.icon), node('span', null, item.label));
        if (item.hint) button.append(node('small', null, item.hint));
        button.addEventListener('click', () => post('radialPick', { id: item.id }));
        return button;
    });

    ring.replaceChildren(center, ...buttons);
    $('radial').classList.remove('hidden');
}

$('radial').addEventListener('click', (event) => {
    if (event.target === $('radial')) post('radialClose');
});
$('radial').addEventListener('contextmenu', (event) => {
    event.preventDefault();
    post('radialClose');
});

// The patrol car menu
function showCarMenu(message) {
    const labels = message.labels || {};
    $('car-title').textContent = labels.title || '';
    $('car-subtitle').textContent = labels.subtitle || '';
    $('car-codes-label').textContent = labels.codes || '';

    const radarButton = (text, icon, on, data) => {
        const button = node('button', `car-btn${on ? ' on' : ''}`);
        button.type = 'button';
        button.append(svgIcon(icon, 18), node('span', null, text));
        button.addEventListener('click', () => post('carMenuRadar', data));
        return button;
    };

    $('car-radar').replaceChildren(
        radarButton(labels.radar, 'radar', message.radar.on, { lock: false }),
        radarButton(labels.lock, 'lock', message.radar.locked, { lock: true }),
    );

    $('car-codes').replaceChildren(...(message.codes || []).map((entry) => {
        const button = node('button', `car-btn code${entry.urgent ? ' urgent' : ''}`);
        button.type = 'button';
        button.append(node('strong', null, entry.code), node('small', null, entry.label));
        button.addEventListener('click', () => post('carMenuCode', { index: entry.index }));
        return button;
    }));

    $('car-menu').classList.remove('hidden');
}

$('car-close').addEventListener('click', () => post('carMenuClose'));

document.addEventListener('keydown', (event) => {
    if (!$('radial').classList.contains('hidden') && event.key === 'Escape') post('radialClose');
    if (!$('car-menu').classList.contains('hidden') && (event.key === 'Escape' || event.key === 'F6')) post('carMenuClose');
});

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message.action !== 'string') return;

    if (message.action === 'popup') showPopup(message.popup, message.labels || {});
    else if (message.action === 'popupOff') removePopup(message.key);
    else if (message.action === 'radial') showRadial(message.menu, message.labels || {});
    else if (message.action === 'radialOff') $('radial').classList.add('hidden');
    else if (message.action === 'carMenu') showCarMenu(message);
    else if (message.action === 'carMenuOff') $('car-menu').classList.add('hidden');
});

// The station wardrobe: uniforms for this body, or the officer's own clothes back
let wardrobeTab = 'uniforms';
let wardrobeData = null;

const SHIRT = 'M8 3l-5 3 2 5 3-1v11h8V10l3 1 2-5-5-3a4 4 0 0 1-8 0z';

function shirtIcon() {
    ICONS.shirt = SHIRT;
    return svgIcon('shirt', 46);
}

// A button that asks once more before doing it
function sureButton(className, text, sure, onConfirm) {
    const button = node('button', className, text);
    button.type = 'button';
    let armed = false;

    button.addEventListener('click', () => {
        if (!armed) {
            armed = true;
            button.textContent = sure;
            setTimeout(() => { armed = false; button.textContent = text; }, 3000);
            return;
        }
        onConfirm();
    });

    return button;
}

function drawWardrobe() {
    const data = wardrobeData;
    const labels = data.labels || {};

    const tabs = [['uniforms', labels.uniforms], ['mine', labels.mine]].map(([id, text]) => {
        const button = node('button', `wardrobe-tab${wardrobeTab === id ? ' on' : ''}`, text);
        button.type = 'button';
        button.addEventListener('click', () => { wardrobeTab = id; drawWardrobe(); });
        return button;
    });
    $('wardrobe-tabs').replaceChildren(...tabs);

    if (wardrobeTab === 'mine') {
        const box = node('div', 'wardrobe-mine');
        box.append(node('p', null, data.wearing ? labels.mineHint : labels.notWearing));

        const back = node('button', 'wardrobe-btn', labels.back);
        back.type = 'button';
        back.disabled = !data.wearing;
        back.addEventListener('click', () => post('wardrobeBack', { offDuty: false }));

        const backOff = node('button', 'wardrobe-btn accent', labels.backOff);
        backOff.type = 'button';
        backOff.disabled = !data.wearing && !data.onDuty;
        backOff.addEventListener('click', () => post('wardrobeBack', { offDuty: true }));

        box.append(back, backOff);
        return $('wardrobe-body').replaceChildren(box);
    }

    const cards = (data.uniforms || []).map((uniform) => {
        const card = node('div', 'wardrobe-card');
        card.append(shirtIcon(), node('strong', null, uniform.label), node('small', null, uniform.by ? `${labels.by} ${uniform.by}` : 'LSPD'));

        const wear = node('button', 'wardrobe-btn accent', labels.wear);
        wear.type = 'button';
        wear.addEventListener('click', () => post('wardrobeWear', { id: uniform.id }));
        card.append(wear);

        if (data.canManage && !uniform.fixed) {
            const remove = sureButton('wardrobe-x', '×', '?', () => post('wardrobeDelete', { id: uniform.id }));
            card.append(remove);
        }

        return card;
    });

    if (data.canManage) {
        const add = node('button', 'wardrobe-card add');
        add.type = 'button';
        add.append(node('span', 'wardrobe-plus', '+'), node('strong', null, labels.new));
        add.addEventListener('click', () => post('wardrobeNew'));
        cards.push(add);
    }

    $('wardrobe-body').replaceChildren(cards.length ? Object.assign(node('div', 'wardrobe-grid'), {}) : node('p', 'wardrobe-none', labels.none));
    if (cards.length) $('wardrobe-body').firstChild.append(...cards);
}

function showWardrobe(message) {
    wardrobeData = message;
    const labels = message.labels || {};
    $('wardrobe-title').textContent = labels.title || '';
    $('wardrobe-subtitle').textContent = labels.subtitle || '';
    $('wardrobe-side').textContent = (labels.title || '').toUpperCase();
    drawWardrobe();
    $('wardrobe').classList.remove('hidden');
}

$('wardrobe-close').addEventListener('click', () => post('wardrobeClose'));

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !$('wardrobe').classList.contains('hidden')) post('wardrobeClose');
});

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message.action !== 'string') return;

    if (message.action === 'wardrobe') showWardrobe(message);
    else if (message.action === 'wardrobeOff') $('wardrobe').classList.add('hidden');
});

// A police badge someone close showed (or our own), for a few seconds
let badgeTimer = null;

function showBadge(message) {
    const card = message.card || {};
    const labels = message.labels || {};

    $('badge-dept').textContent = card.department || '';
    $('badge-name').textContent = card.name || '';

    const rows = [[labels.rank, card.rank], [labels.callsign, card.callsign], [labels.number, card.number]]
        .filter(([, value]) => value)
        .flatMap(([label, value]) => [node('dt', null, label), node('dd', null, value)]);
    $('badge-rows').replaceChildren(...rows);

    const bar = $('badge-bar');
    bar.style.animation = 'none';
    void bar.offsetWidth;
    bar.style.animation = `shrink ${message.seconds || 6}s linear forwards`;

    $('badge').classList.remove('hidden');
    clearTimeout(badgeTimer);
    badgeTimer = setTimeout(() => $('badge').classList.add('hidden'), (message.seconds || 6) * 1000);
}

window.addEventListener('message', (event) => {
    const message = event.data;
    if (message && message.action === 'badge') showBadge(message);
});
