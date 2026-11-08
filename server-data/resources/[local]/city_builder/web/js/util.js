// Small helpers shared by the editor's scripts.
const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_builder';

let labels = {};

export function setLabels(next) {
    labels = next || {};
}

// A label with %s filled in order
export function t(key, ...args) {
    let text = labels[key] ?? key;
    for (const arg of args) text = text.replace('%s', String(arg));
    return text;
}

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

export function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

export function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

export function button(text, className, onClick) {
    const node = el('button', `btn ${className || ''}`.trim(), text);
    node.addEventListener('click', onClick);
    return node;
}

// GTA's model hash (Jenkins one-at-a-time), unsigned
export function joaat(text) {
    let hash = 0;
    const lower = text.toLowerCase();

    for (let i = 0; i < lower.length; i++) {
        hash = (hash + lower.charCodeAt(i)) >>> 0;
        hash = (hash + (hash << 10)) >>> 0;
        hash = (hash ^ (hash >>> 6)) >>> 0;
    }

    hash = (hash + (hash << 3)) >>> 0;
    hash = (hash ^ (hash >>> 11)) >>> 0;
    return (hash + (hash << 15)) >>> 0;
}

export function round(value, digits = 3) {
    const factor = 10 ** digits;
    return Math.round(value * factor) / factor;
}

// A yes/no box over the editor; resolves true when confirmed
export function confirmBox(text, fields = []) {
    const dialog = document.getElementById('dialog');
    dialog.replaceChildren();

    return new Promise((resolve) => {
        const box = el('div', 'box');
        box.append(el('div', 'text', text));

        const inputs = fields.map((field) => {
            const input = el('input', 'input');
            input.type = field.type || 'text';
            input.placeholder = field.placeholder || '';
            input.value = field.value ?? '';
            if (field.step) input.step = field.step;
            input.style.marginBottom = '8px';
            box.append(input);
            return input;
        });

        const done = (ok) => {
            dialog.classList.add('hidden');
            resolve(ok ? inputs.map((input) => input.value) : null);
        };

        const actions = el('div', 'actions');
        actions.append(el('div', 'grow'), button(t('cancel'), '', () => done(false)), button(t('confirm'), 'accent', () => done(true)));
        box.append(actions);

        dialog.append(box);
        dialog.classList.remove('hidden');
        (inputs[0] || actions.lastChild).focus();
    });
}
