export const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_clothing';

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
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

export function money(value) {
    return `$${Math.round(value || 0).toLocaleString('en-US')}`;
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

/**
 * ‹ value › picker for whole numbers, wrapping around
 */
export function stepper({ label, value, min, max, format, onChange }) {
    const node = el('div', 'stepper');
    const box = el('div', 'stepper__box');
    const prev = el('button', 'stepper__btn', '‹');
    const next = el('button', 'stepper__btn', '›');
    const text = el('span', 'stepper__value');
    prev.type = 'button';
    next.type = 'button';
    box.append(prev, text, next);
    node.append(el('span', 'stepper__label', label), box);

    let current = value;
    const show = format || ((v) => `${v - min + 1} / ${max - min + 1}`);
    const draw = () => { text.textContent = show(current); };

    const step = (delta) => {
        if (max <= min) return;
        current += delta;
        if (current > max) current = min;
        if (current < min) current = max;
        draw();
        onChange(current);
    };

    prev.addEventListener('click', () => step(-1));
    next.addEventListener('click', () => step(1));
    draw();

    return node;
}

/**
 * A 0-1 range with a live value, for overlay opacity
 */
export function range({ label, value, min = 0, step = 1, onInput }) {
    const node = el('div', 'range');
    const head = el('div', 'range__head');
    const valueText = el('span', 'range__value', `${Math.round(value * 100)}%`);
    head.append(el('span', 'range__label', label), valueText);

    const input = document.createElement('input');
    input.type = 'range';
    input.min = String(min);
    input.max = '100';
    input.step = String(step);
    input.value = String(Math.round(value * 100));
    input.addEventListener('input', () => {
        valueText.textContent = `${input.value}%`;
        onInput(Number(input.value) / 100);
    });

    node.append(head, input);
    return node;
}

export function swatches({ label, colors, value, onChange }) {
    const node = el('div', 'swatch-group');
    node.append(el('span', 'swatch-group__label', label));
    const grid = el('div', 'swatches');

    const items = colors.map((color, index) => {
        const swatch = el('button', 'swatch');
        swatch.type = 'button';
        swatch.style.background = color;
        swatch.classList.toggle('is-active', index === value);
        swatch.addEventListener('click', () => {
            items.forEach((item, i) => item.classList.toggle('is-active', i === index));
            onChange(index);
        });
        grid.append(swatch);
        return swatch;
    });

    node.append(grid);
    return node;
}
