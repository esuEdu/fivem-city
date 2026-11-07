// Small DOM and text helpers shared by the Staff app's tabs. Game data only ever goes in with textContent.

let labels = {};

export function setLabels(next) {
    labels = next || {};
}

export function L(key, ...args) {
    let text = labels[key] ?? key;
    for (const arg of args) text = text.replace(/%[sd]/, String(arg));
    return text;
}

// 24x24 stroke icons
export const ICONS = {
    dashboard: 'M4 13h6V4H4zM14 20h6v-9h-6zM4 20h6v-3H4zM14 7h6V4h-6z',
    players: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1M17 3.5a4 4 0 0 1 0 7.5M22 21v-1a6 6 0 0 0-4-5.6',
    reports: 'M4 5h16v11H8l-4 4zM8 9h8M8 12h5',
    star: 'M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z',
    ban: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM5.6 5.6l12.8 12.8',
    log: 'M5 4h14v16H5zM9 8h6M9 12h6M9 16h4',
    tools: 'M15 4a5 5 0 0 0-4.6 6.9L3 18.3 5.7 21l7.4-7.4A5 5 0 0 0 20 9l-3 1-2-2 1-3z',
    shield: 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6zM9 12l2 2 4-4',
    check: 'M5 12.5l4.5 4.5L19 7.5',
    clock: 'M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18zM12 7v5l3 2',
    search: 'M11 4.5a6.5 6.5 0 1 1 0 13a6.5 6.5 0 1 1 0-13zM16 16l4.5 4.5',
    goto: 'M4.5 11.2L19.5 4.5l-6.7 15-1.9-6.4z',
    bring: 'M6 4.5h4v6.8a2 2 0 0 0 4 0V4.5h4v6.8a6 6 0 0 1-12 0zM6 8.5h4M14 8.5h4',
    spectate: 'M2.5 12c2-4.2 5.5-6.5 9.5-6.5s7.5 2.3 9.5 6.5c-2 4.2-5.5 6.5-9.5 6.5S4.5 16.2 2.5 12zM12 9.2a2.8 2.8 0 1 0 0 5.6 2.8 2.8 0 0 0 0-5.6z',
    heal: 'M14.6 3.9l5.5 5.5a1.9 1.9 0 0 1 0 2.7l-8 8a1.9 1.9 0 0 1-2.7 0l-5.5-5.5a1.9 1.9 0 0 1 0-2.7l8-8a1.9 1.9 0 0 1 2.7 0zM10.6 10.6h.01M13.4 13.4h.01M10.6 13.4h.01M13.4 10.6h.01',
    revive: 'M12 20.3S3.8 15.6 3.8 9.4A4.2 4.2 0 0 1 12 7.2a4.2 4.2 0 0 1 8.2 2.2c0 6.2-8.2 10.9-8.2 10.9zM7 12.2h2.6l1.4-2.4 2.1 4.6 1.3-2.2H17',
    freeze: 'M12 3v18M4.2 7.5l15.6 9M19.8 7.5l-15.6 9M9.6 4.6L12 6.4l2.4-1.8M9.6 19.4L12 17.6l2.4 1.8',
    inventory: 'M8.5 7V5.5A2.5 2.5 0 0 1 11 3h2a2.5 2.5 0 0 1 2.5 2.5V7M6.5 7h11A2.5 2.5 0 0 1 20 9.5v9a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 18.5v-9A2.5 2.5 0 0 1 6.5 7zM9 13h6v3H9z',
    cuff: 'M7.5 10.5a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9zM16.5 4.5a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9zM10.6 11.4l2.8-2.8',
    clothing: 'M9 3.5c.6 1.2 1.7 2 3 2s2.4-.8 3-2l5 2.5-2 4.5-2-.8v10.8H8V9.7l-2 .8-2-4.5z',
    kill: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM9.2 9.2l5.6 5.6M14.8 9.2l-5.6 5.6',
    bucket: 'M12 3l9 5-9 5-9-5zM3 13l9 5 9-5',
    place: 'M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11zM12 8a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
    vehicle: 'M5 16h14v-4l-2-5H7l-2 5zM5 16v2M19 16v2M8 13h.01M16 13h.01',
    job: 'M4 8h16v11H4zM9 8V5h6v3',
    gang: 'M12 3l2.5 5 5.5.8-4 3.9.9 5.5L12 15.6 7.1 18.2l.9-5.5-4-3.9 5.5-.8z',
    license: 'M4 6h16v12H4zM8 10h5M8 14h8',
    warn: 'M12 3l9.5 17h-19zM12 10v4.5M12 17.5v.01',
    kick: 'M14 4h5v16h-5M10 8l4 4-4 4M14 12H3',
    noclip: 'M12 3v18M5 10l7-7 7 7',
    invisible: 'M6 20V10a6 6 0 0 1 12 0v10l-2-2-2 2-2-2-2 2-2-2zM10 10h.01M14 10h.01',
    godmode: 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6z',
    names: 'M3 12V4h8l10 10-8 8zM7.5 8h.01',
    blips: 'M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14',
    chevron: 'M9 5l7 7-7 7',
    edit: 'M15.5 5.5l3 3M4 20l1-4 11-11a2.1 2.1 0 0 1 3 3L8 19z',
    fire: 'M9.5 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM3.5 20a6 6 0 0 1 12 0M16 9.5h5',
    armor: 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6z',
    hunger: 'M7 3v7a2 2 0 0 0 4 0V3M9 10v11M17 3c-1.7 0-3 2-3 5s1.3 4 3 4v9',
    thirst: 'M12 3.5s6 6.5 6 10.5a6 6 0 0 1-12 0c0-4 6-10.5 6-10.5z',
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
    path.setAttribute('d', ICONS[name] || ICONS.chevron);
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
        else if (key === 'value') node.value = value;
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

// One staff action through the app's client script; failures show why
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
export function confirmButton(content, onConfirm, kind = 'danger', className = 'kit-btn') {
    let armed = false;
    let timer = null;

    const button = el('button', { class: `${className} ${kind}` }, content);
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

// A segmented control: options [[value, label]], calls pick(value)
export function segmented(options, current, pick) {
    return el('div', { class: 'segmented' }, options.map(([value, label]) =>
        el('button', { class: value === current ? 'on' : '', text: label, onclick: () => pick(value) })));
}

export function searchField(placeholder, oninput) {
    return el('label', { class: 'search' }, icon('search', 16, 2),
        el('input', { type: 'text', placeholder, 'aria-label': placeholder, oninput: (event) => oninput(event.target.value.trim().toLowerCase()) }));
}

// A number box with our own − and + buttons (the browser's arrows are hidden in style.css)
export function stepper(input) {
    const min = Number(input.min || 0);
    const max = Number(input.max || Infinity);
    const step = (delta) => {
        const current = Number(input.value) || 0;
        input.value = String(Math.min(max, Math.max(min, Math.round(current) + delta)));
        input.dispatchEvent(new Event('input'));
    };

    return el('div', { class: 'stepper' },
        el('button', { type: 'button', class: 'step', 'aria-label': L('ui_less'), onclick: () => step(-1) }, '−'),
        input,
        el('button', { type: 'button', class: 'step', 'aria-label': L('ui_more'), onclick: () => step(1) }, '+'),
    );
}

export function stars(count) {
    const n = Math.max(0, Math.min(5, Math.round(count || 0)));
    return '★★★★★'.slice(0, n) + '☆☆☆☆☆'.slice(0, 5 - n);
}

export function initials(name) {
    return (name || '?').replace(/\(.*\)/, '').trim().split(/\s+/).map((part) => part[0] || '').join('').slice(0, 2).toUpperCase();
}

// "Firstname Lastname (account)" -> "Firstname Lastname"
export function shortName(name) {
    return (name || '').replace(/\s*\(.*\)$/, '');
}

export function duration(seconds) {
    if (seconds === null || seconds === undefined) return '—';
    if (seconds < 60) return `${Math.round(seconds)}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${String(Math.round(seconds % 60)).padStart(2, '0')}s`;
    return `${Math.floor(seconds / 3600)}h ${String(Math.floor((seconds % 3600) / 60)).padStart(2, '0')}m`;
}

export function money(amount) {
    return `$${Math.round(amount || 0).toLocaleString('en-US')}`;
}

export function formatTime(unix) {
    if (!unix) return '—';
    return new Date(unix * 1000).toLocaleString([], { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
}

export function ago(unix) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000 - unix));
    if (seconds < 60) return L('ui_just_now');
    if (seconds < 3600) return L('ui_minutes_ago', Math.floor(seconds / 60));
    if (seconds < 86400) return L('ui_hours_ago', Math.floor(seconds / 3600));
    return L('ui_days_ago', Math.floor(seconds / 86400));
}

// Health bar color: red when low, orange in the middle, green when fine
export function healthKind(percent) {
    return percent < 25 ? 'bad' : percent < 60 ? 'warn' : 'ok';
}
