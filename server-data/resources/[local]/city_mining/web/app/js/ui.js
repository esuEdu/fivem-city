// Small DOM and text helpers for the Mining app. Game data only ever goes in with textContent.

let labels = {};

export function setLabels(next) {
    labels = next || {};
}

export function L(key, ...args) {
    let text = labels[key] ?? key;
    for (const arg of args) text = text.replace(/%[sd]/, String(arg));
    return text;
}

export const ICONS = {
    profile: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21v-1a7 7 0 0 1 7-7h2a7 7 0 0 1 7 7v1',
    skills: 'M12 3v6M12 9l-6 5M12 9l6 5M6 14v5M18 14v5M12 9v10',
    market: 'M4 20V10M10 20V4M16 20v-7M22 20H2',
    orders: 'M5 8h14l-2 12H7zM9 8V5h6v3M5 12h14',
    track: 'M12 2v4M12 18v4M2 12h4M18 12h4M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z',
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

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', ICONS[name] || ICONS.market);
    svg.append(path);

    return svg;
}

// el('button', { class: 'kit-btn', text: 'Go', onclick: fn }, child, ...)
export function el(tag, props = {}, ...children) {
    const node = document.createElement(tag);

    for (const [key, value] of Object.entries(props)) {
        if (value === undefined || value === null || value === false) continue;
        if (key === 'text') node.textContent = value;
        else if (key === 'class') node.className = value;
        else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
        else node.setAttribute(key, value === true ? '' : value);
    }

    for (const child of children) {
        if (child !== null && child !== undefined && child !== false) node.append(child);
    }

    return node;
}

let toastTimer;

export function toast(text, bad = false) {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.classList.toggle('bad', bad);
    node.classList.add('on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => node.classList.remove('on'), 2600);
}

// One server action through this resource's Lua (client/app.lua)
export async function run(action, args) {
    const response = await window.CityOS.send('run', { action, args });
    if (!response) return null;
    if (!response.ok) {
        toast(L(response.reason || 'failed'), true);
        return null;
    }

    return response.data ?? true;
}

// "1h 05m", "12m", "40s"
export function duration(seconds) {
    seconds = Math.max(0, Math.floor(seconds));
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    if (days > 0) return `${days}d ${hours}h`;
    if (hours > 0) return `${hours}h ${String(minutes).padStart(2, '0')}m`;
    if (minutes > 0) return `${minutes}m`;
    return `${seconds % 60}s`;
}

export function row(...children) {
    return el('div', { class: 'kit-row' }, ...children);
}

export function group(head, rows, foot) {
    return el('div', {},
        head ? el('div', { class: 'kit-head', text: head }) : null,
        el('div', { class: 'kit-group' }, ...rows),
        foot ? el('div', { class: 'kit-foot', text: foot }) : null,
    );
}
