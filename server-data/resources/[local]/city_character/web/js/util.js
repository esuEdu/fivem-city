const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_character';

export async function post(name, data = {}) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await response.json();
    } catch {
        return null;
    }
}

// Sliders and drags fire far faster than the game needs: keep only the latest value per key, sent once per frame
const pending = new Map();
let scheduled = false;

export function postLatest(key, name, data) {
    pending.set(key, { name, data });
    if (scheduled) return;

    scheduled = true;
    requestAnimationFrame(() => {
        scheduled = false;
        const batch = [...pending.values()];
        pending.clear();
        batch.forEach(({ name: callback, data: payload }) => post(callback, payload));
    });
}

export function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

export function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

// Static, trusted SVG markup only: never pass game or player data here
export function icon(name) {
    const span = document.createElement('span');
    span.innerHTML = ICONS[name] || '';
    return span.firstElementChild || span;
}

export function clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
}

export function money(value) {
    return `$${Math.round(value || 0).toLocaleString('en-US')}`;
}

export function initials(first, last) {
    return `${(first || '?')[0] || ''}${(last || '')[0] || ''}`.toUpperCase();
}

export function toast(text) {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.classList.remove('hidden');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => node.classList.add('hidden'), 3500);
}

export function confirmModal(title, text, okLabel) {
    return new Promise((resolve) => {
        const modal = document.getElementById('modal');
        document.getElementById('modal-title').textContent = title;
        document.getElementById('modal-text').textContent = text;
        const ok = document.getElementById('modal-ok');
        const cancel = document.getElementById('modal-cancel');
        ok.textContent = okLabel || 'Confirm';
        modal.classList.remove('hidden');

        const done = (value) => {
            modal.classList.add('hidden');
            ok.onclick = null;
            cancel.onclick = null;
            resolve(value);
        };

        ok.onclick = () => done(true);
        cancel.onclick = () => done(false);
    });
}

const stroke = 'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"';

const ICONS = {
    left: `<svg viewBox="0 0 24 24" ${stroke}><path d="M15 6l-6 6 6 6"/></svg>`,
    right: `<svg viewBox="0 0 24 24" ${stroke}><path d="M9 6l6 6-6 6"/></svg>`,
    male: `<svg viewBox="0 0 24 24" ${stroke}><circle cx="10" cy="14" r="5"/><path d="M14 10l6-6M15 4h5v5"/></svg>`,
    female: `<svg viewBox="0 0 24 24" ${stroke}><circle cx="12" cy="9" r="5"/><path d="M12 14v7M9 18h6"/></svg>`,
    face: `<svg viewBox="0 0 24 24" ${stroke}><path d="M12 3c-4 0-6.5 3-6.5 7.5 0 5 3 10.5 6.5 10.5s6.5-5.5 6.5-10.5C18.5 6 16 3 12 3z"/><path d="M9.5 11h.01M14.5 11h.01M10 16c1.2.8 2.8.8 4 0"/></svg>`,
    torso: `<svg viewBox="0 0 24 24" ${stroke}><circle cx="12" cy="6" r="3"/><path d="M5 21v-4a7 7 0 0114 0v4"/></svg>`,
    body: `<svg viewBox="0 0 24 24" ${stroke}><circle cx="12" cy="4" r="2"/><path d="M12 7v8M8 10h8M12 15l-3 6M12 15l3 6"/></svg>`,
    feet: `<svg viewBox="0 0 24 24" ${stroke}><path d="M4 17h7l2-4 3 1 4 1v3H4z"/><path d="M8 17V8"/></svg>`,
    undo: `<svg viewBox="0 0 24 24" ${stroke}><path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 010 12h-3"/></svg>`,
    redo: `<svg viewBox="0 0 24 24" ${stroke}><path d="M15 14l5-5-5-5"/><path d="M20 9H10a6 6 0 000 12h3"/></svg>`,
    dice: `<svg viewBox="0 0 24 24" ${stroke}><rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9 9h.01M15 15h.01M15 9h.01M9 15h.01M12 12h.01"/></svg>`,
    tee: `<svg viewBox="0 0 24 24" ${stroke}><path d="M8 3l-5 3 2 4 2-1v12h10V9l2 1 2-4-5-3c-.5 1.5-2 2.5-4 2.5S8.5 4.5 8 3z"/></svg>`,
    hoodie: `<svg viewBox="0 0 24 24" ${stroke}><path d="M8 4c1-1 2.5-1.5 4-1.5S15 3 16 4l4 3-2 4-1-.5V21H7V10.5L6 11 4 7z"/><path d="M9 4c0 2.5 1.5 4 3 4s3-1.5 3-4M10 8v4M14 8v4"/></svg>`,
    shirt: `<svg viewBox="0 0 24 24" ${stroke}><path d="M8 3l4 4 4-4 4 3-2 4-2-1v12H8V9l-2 1-2-4z"/><path d="M12 7v14"/></svg>`,
    suit: `<svg viewBox="0 0 24 24" ${stroke}><path d="M8 3l4 6 4-6 4 3-1 15H5L4 6z"/><path d="M12 9l-1 3 1 9 1-9z"/></svg>`,
    run: `<svg viewBox="0 0 24 24" ${stroke}><circle cx="14" cy="4" r="2"/><path d="M6 21l3-6 3 2v4M9 15l2-6 4 3 3-1M11 9L7 10l-2 3"/></svg>`,
    tool: `<svg viewBox="0 0 24 24" ${stroke}><path d="M14.7 6.3a4 4 0 00-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 005.4-5.4l-2.5 2.5-2.4-.6-.6-2.4z"/></svg>`,
    dress: `<svg viewBox="0 0 24 24" ${stroke}><path d="M9 3h6l-1 5 5 13H5L10 8z"/><path d="M10 8h4"/></svg>`,
    plus: `<svg viewBox="0 0 24 24" ${stroke}><path d="M12 5v14M5 12h14"/></svg>`,
};
