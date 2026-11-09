// Small DOM and text helpers shared by the MDT's tabs. Game data only ever goes in with textContent.

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
    dispatch: 'M12 3a6 6 0 0 0-6 6v4l-2 3h16l-2-3V9a6 6 0 0 0-6-6zM10 19a2 2 0 0 0 4 0',
    map: 'M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14',
    units: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1M17 3.5a4 4 0 0 1 0 7.5M22 21v-1a6 6 0 0 0-4-5.6',
    people: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21v-1a7 7 0 0 1 7-7h2a7 7 0 0 1 7 7v1',
    vehicles: 'M5 16h14v-4l-2-5H7l-2 5zM5 16v2M19 16v2M8 13h.01M16 13h.01',
    weapons: 'M3 9h14l2 2h2v3h-6l-1 3h-3l-1-3H3zM7 9V7',
    reports: 'M6 3h9l4 4v14H6zM14 3v5h5M9 12h7M9 16h5',
    warrants: 'M12 3l9.5 17h-19zM12 10v4.5M12 17.5v.01',
    bolos: 'M2 12s3.5-6.5 10-6.5S22 12 22 12s-3.5 6.5-10 6.5S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z',
    charges: 'M12 3v18M5 7h14M7 7l-3 7a3.5 3.5 0 0 0 6 0zM17 7l-3 7a3.5 3.5 0 0 0 6 0zM8 21h8',
    impounds: 'M3 17h2l1-5h12l1 5h2M6 12l2-4h8l2 4M7 20a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zM17 20a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z',
    licences: 'M4 6h16v12H4zM8 10h5M8 14h8M16 10h.01',
    evidence: 'M10 3a7 7 0 1 0 4.9 12l5.1 5.1M10 7v6M7 10h6',
    cameras: 'M3 8h12v8H3zM15 11l6-3v8l-6-3',
    certs: 'M12 3l2.5 5 5.5.8-4 3.9.9 5.5L12 15.6 7.1 18.2l.9-5.5-4-3.9 5.5-.8z',
    management: 'M4 8h16v11H4zM9 8V5h6v3M4 13h16',
    shield: 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6z',
    search: 'M11 4.5a6.5 6.5 0 1 1 0 13a6.5 6.5 0 1 1 0-13zM16 16l4.5 4.5',
    place: 'M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11zM12 8a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
    clock: 'M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18zM12 7v5l3 2',
    check: 'M5 12.5l4.5 4.5L19 7.5',
    plus: 'M12 5v14M5 12h14',
    close: 'M6 6l12 12M18 6L6 18',
    chevron: 'M9 5l7 7-7 7',
    back: 'M15 5l-7 7 7 7',
    phone: 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z',
    gps: 'M4.5 11.2L19.5 4.5l-6.7 15-1.9-6.4z',
    note: 'M4 5h16v11H8l-4 4zM8 9h8M8 12h5',
    fingerprint: 'M8 11a4 4 0 0 1 8 0v2a8 8 0 0 1-1 4M12 11v3a10 10 0 0 1-2 6M5 9a7 7 0 0 1 14 0v4M5 13v-1',
    anklet: 'M12 2v4M5 8a7 7 0 0 0 14 0M8 18a4 4 0 0 0 8 0M12 12v6',
    edit: 'M15.5 5.5l3 3M4 20l1-4 11-11a2.1 2.1 0 0 1 3 3L8 19z',
    trash: 'M5 7h14M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
    lock: 'M6 11h12v9H6zM8 11V7a4 4 0 0 1 8 0v4',
    bell: 'M12 3a6 6 0 0 0-6 6v4l-2 3h16l-2-3V9a6 6 0 0 0-6-6zM10 19a2 2 0 0 0 4 0',
    camera: 'M3 8h12v8H3zM15 11l6-3v8l-6-3',
    flag: 'M5 21V4h11l-2 4 2 4H5',
    user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21v-1a7 7 0 0 1 7-7h2a7 7 0 0 1 7 7v1',
    cases: 'M4 7h16v12H4zM9 7V5h6v2M4 12h16M11 12v2h2v-2',
    prison: 'M4 4h16v16H4zM8 4v16M12 4v16M16 4v16',
    penal: 'M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3zM5 17a3 3 0 0 1 3-3h11M9 8h6',
    image: 'M4 5h16v14H4zM4 16l5-5 4 4 3-3 4 4M15 9h.01',
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

// One MDT action through the app's client script; failures show why
export async function run(action, args = {}, done) {
    const response = await window.CityOS.send('run', { action, args });

    if (!response || !response.ok) {
        console.warn(`MDT ${action} failed: ${response ? response.reason : 'no reply from the client'}`);
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


// A label above a form control
export function labeled(label, control) {
    return el('label', { class: 'labeled' }, el('span', { text: label }), control);
}

// A <select> from [[value, label]]
export function select(options, value) {
    const node = el('select', { class: 'field' }, options.map(([optionValue, label]) => el('option', { value: optionValue, text: label })));
    if (value !== undefined && value !== null) node.value = String(value);
    return node;
}

// A booking photo (a data:image/png URL the server checked) or the person's initials
export function photo(src, name, size = 'big') {
    if (typeof src === 'string' && src.startsWith('data:image/png;base64,')) {
        return el('img', { class: `photo ${size}`, src, alt: '' });
    }
    return el('span', { class: `photo ${size} initials`, text: initials(name) });
}

export function dateOnly(unix) {
    if (!unix) return '—';
    return new Date(unix * 1000).toLocaleDateString([], { day: '2-digit', month: 'short', year: 'numeric' });
}

// Empty state for a list or a panel
export function empty(text) {
    return el('div', { class: 'list-empty', text });
}
