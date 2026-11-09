// Small DOM and text helpers shared by the Gang app's tabs. Game data only ever goes in with textContent.

let labels = {};

export function setLabels(next) {
    labels = next || {};
}

export function L(key, ...args) {
    let text = labels[key] ?? key;
    for (const arg of args) text = text.replace(/%[sd]/, String(arg));
    return text.replace(/%%/g, '%');
}

// 24x24 stroke icons
export const ICONS = {
    gang: 'M12 2.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 15.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-.8zM8 21.5h8',
    overview: 'M4 13h6V4H4zM14 20h6v-9h-6zM4 20h6v-3H4zM14 7h6V4h-6z',
    members: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1M17 3.5a4 4 0 0 1 0 7.5M22 21v-1a6 6 0 0 0-4-5.6',
    recruit: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1M19 8v6M16 11h6',
    drugs: 'M10.5 20.5a5 5 0 0 1-7-7l6-6a5 5 0 0 1 7 7zM7 10l7 7',
    log: 'M5 4h14v16H5zM9 8h6M9 12h6M9 16h4',
    money: 'M12 3v18M17 7.5c0-1.9-2.2-3-5-3s-5 1.1-5 3 2.2 2.7 5 3.2 5 1.3 5 3.3-2.2 3.5-5 3.5-5-1.2-5-3.2',
    flask: 'M9 3h6M10 3v6l-5.5 9.5A1.7 1.7 0 0 0 6 21h12a1.7 1.7 0 0 0 1.5-2.5L14 9V3M7.5 14h9',
    cart: 'M3 4h2l2.4 11h10.2L20 7H6.2M9 20h.01M17 20h.01',
    place: 'M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11zM12 8a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
    leaf: 'M5 19c0-8 5-14 15-15-1 10-7 15-15 15zM5 19l7-7',
    warn: 'M12 3l9.5 17h-19zM12 10v4.5M12 17.5v.01',
    up: 'M12 19V5M5 12l7-7 7 7',
    down: 'M12 5v14M5 12l7 7 7-7',
    kick: 'M14 4h5v16h-5M10 8l4 4-4 4M14 12H3',
    refresh: 'M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7',
};

export function icon(name, size = 20, stroke = 1.8) {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('width', size);
    svg.setAttribute('height', size);
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', stroke);
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', ICONS[name] || ICONS.gang);
    svg.append(path);

    return svg;
}

// el('button', { class: 'kit-btn', text: 'Go', onclick: fn }, child, ...)
export function el(tag, props = {}, ...children) {
    const node = document.createElement(tag);

    for (const [key, value] of Object.entries(props)) {
        if (value === undefined || value === null || value === false) continue;
        if (key === 'class') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key === 'style') node.style.cssText = value;
        else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
        else node.setAttribute(key, value === true ? '' : value);
    }

    for (const child of children.flat()) {
        if (child === null || child === undefined || child === false) continue;
        node.append(typeof child === 'string' || typeof child === 'number' ? document.createTextNode(String(child)) : child);
    }

    return node;
}

let toastTimer = null;

export function toast(text, kind = 'ok') {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.className = `show ${kind}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (node.className = ''), 3200);
}

// One request through the app's client script; failures show why
export async function run(action, args = {}, done) {
    const response = await window.CityOS.send('run', { action, args });

    if (!response || !response.ok) {
        toast(L(`error_${(response && response.reason) || 'failed'}`), 'bad');
        return null;
    }

    if (done) toast(done);
    return response;
}

// A button that asks once more ("Sure?") before doing something hard to undo
export function confirmButton(content, onConfirm, kind = 'danger') {
    let armed = false;
    let timer = null;

    const button = el('button', { class: `kit-btn ${kind}` }, content);
    const original = [...button.childNodes];

    button.addEventListener('click', () => {
        if (!armed) {
            armed = true;
            button.replaceChildren(L('ui_sure'));
            timer = setTimeout(() => {
                armed = false;
                button.replaceChildren(...original);
            }, 3000);
            return;
        }

        clearTimeout(timer);
        armed = false;
        button.replaceChildren(...original);
        onConfirm();
    });

    return button;
}

export function heading(title, ...extra) {
    return el('div', { class: 'heading' }, el('h1', { text: title }), ...extra);
}

export function pill(text, kind = '') {
    return el('span', { class: `pill ${kind}`, text });
}

export function tile(iconName, kind, label, value, sub) {
    return el('div', { class: 'card tile' },
        el('div', { class: 'tile-head' }, el('span', { class: `tile-icon ${kind}` }, icon(iconName, 18, 2)), el('span', { text: label })),
        el('strong', { class: 'tile-value', text: value }),
        sub ? el('small', { class: 'tile-sub', text: sub }) : null,
    );
}

export function initials(name) {
    return (name || '?').trim().split(/\s+/).map((part) => part[0] || '').join('').slice(0, 2).toUpperCase();
}

export function money(amount) {
    return `$${Math.round(amount || 0).toLocaleString('en-US')}`;
}

export function ago(unix) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000 - unix));
    if (seconds < 60) return L('ui_just_now');
    if (seconds < 3600) return L('ui_minutes_ago', Math.floor(seconds / 60));
    if (seconds < 86400) return L('ui_hours_ago', Math.floor(seconds / 3600));
    return L('ui_days_ago', Math.floor(seconds / 86400));
}

// Drug ids from city_drugs -> their label, filled from the drugs guide
export const drugLabels = {};

export function drugLabel(id) {
    return drugLabels[id] || id;
}

// Lua sends an empty table as {} rather than []
export function list(value) {
    return Array.isArray(value) ? value : [];
}

// A segmented control: options [[value, label]], calls pick(value)
export function segmented(options, current, pick) {
    return el('div', { class: 'segmented' }, options.map(([value, label]) =>
        el('button', { class: value === current ? 'on' : '', text: label, onclick: () => pick(value) })));
}

// Money earned per day as bars, with units made as a thin second bar; `start` is the window's first second (unix)
export function chart(title, data) {
    const days = list(data.days);
    const maxMoney = Math.max(1, ...days.map((day) => day.sale));
    const maxMade = Math.max(1, ...days.map((day) => day.made));
    const label = (index) => new Date((data.start + (index + 1) * 86400 - 1) * 1000).toLocaleDateString([], { day: '2-digit', month: '2-digit' });

    return el('div', { class: 'card' },
        el('div', { class: 'card-head' }, el('strong', { class: 'card-title', text: title }), el('span', { class: 'spacer' }),
            el('span', { class: 'legend' }, el('i', { class: 'money' }), L('ui_earned')),
            el('span', { class: 'legend' }, el('i', { class: 'made' }), L('ui_made'))),
        el('div', { class: 'bars', style: `grid-template-columns: repeat(${days.length}, minmax(0, 1fr))` }, days.map((day, index) => el('div', { class: 'bar-day' },
            el('div', { class: 'bar-pair' },
                el('span', { class: 'bar money', style: `height: ${Math.round((day.sale / maxMoney) * 120)}px`, title: money(day.sale) }),
                el('span', { class: 'bar made', style: `height: ${Math.round((day.made / maxMade) * 120)}px`, title: `${day.made} ${L('ui_units')}` })),
            el('small', { text: label(index) })))),
    );
}

export function periodPicker(periods, current, pick) {
    return segmented(list(periods).map((days) => [days, days === 1 ? L('ui_24h') : L('ui_days_n', days)]), current, pick);
}
