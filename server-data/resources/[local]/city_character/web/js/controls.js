import { el, icon, clamp } from './util.js';

function dragOn(node, onMove, onEnd) {
    node.addEventListener('pointerdown', (event) => {
        event.preventDefault();
        node.setPointerCapture(event.pointerId);
        node.classList.add('is-dragging');
        onMove(event);

        const move = (e) => onMove(e);
        const up = () => {
            node.classList.remove('is-dragging');
            node.removeEventListener('pointermove', move);
            node.removeEventListener('pointerup', up);
            node.removeEventListener('pointercancel', up);
            onEnd?.();
        };

        node.addEventListener('pointermove', move);
        node.addEventListener('pointerup', up);
        node.addEventListener('pointercancel', up);
    });
}

const fmt = (v) => (v > 0 ? '+' : '') + v.toFixed(2);

/**
 * A custom range: centered fill for -1..1 values, end labels, live value
 * @returns {{ node: HTMLElement, set: (v: number) => void }}
 */
export function slider({ label, min = -1, max = 1, value = 0, ends, format = fmt, onInput, onCommit }) {
    const node = el('div', 'slider');
    const head = el('div', 'slider__head');
    const valueText = el('span', 'slider__value');
    head.append(el('span', 'slider__label', label), valueText);

    const range = el('div', 'range');
    const track = el('div', 'range__track');
    const fill = el('div', 'range__fill');
    const thumb = el('div', 'range__thumb');
    const centered = min < 0 && max > 0;
    range.append(track, fill);
    if (centered) range.append(el('div', 'range__center'));
    range.append(thumb);

    node.append(head, range);
    if (ends) {
        const endRow = el('div', 'slider__ends');
        endRow.append(el('span', '', ends[0]), el('span', '', ends[1]));
        node.append(endRow);
    }

    let current = value;

    const draw = () => {
        const pct = ((current - min) / (max - min)) * 100;
        thumb.style.left = `${pct}%`;
        if (centered) {
            const zero = ((0 - min) / (max - min)) * 100;
            fill.style.left = `${Math.min(zero, pct)}%`;
            fill.style.width = `${Math.abs(pct - zero)}%`;
        } else {
            fill.style.left = '0%';
            fill.style.width = `${pct}%`;
        }
        valueText.textContent = format(current);
    };

    dragOn(range, (event) => {
        const rect = range.getBoundingClientRect();
        const t = clamp((event.clientX - rect.left) / rect.width, 0, 1);
        current = Math.round((min + t * (max - min)) * 100) / 100;
        draw();
        onInput?.(current);
    }, () => onCommit?.(current));

    range.addEventListener('dblclick', () => {
        current = centered ? 0 : min;
        draw();
        onInput?.(current);
        onCommit?.(current);
    });

    draw();

    return {
        node,
        set(v) {
            current = v;
            draw();
        },
    };
}

/**
 * A square you drag a dot around in: two values (-1..1) at once
 * @returns {{ node: HTMLElement, set: (x: number, y: number) => void }}
 */
export function pad({ x = 0, y = 0, labels = {}, invertY = false, onInput, onCommit }) {
    const node = el('div', 'pad');
    const guideX = el('div', 'pad__guide-x');
    const guideY = el('div', 'pad__guide-y');
    const dot = el('div', 'pad__dot');
    node.append(guideX, guideY, dot);

    for (const side of ['top', 'bottom', 'left', 'right']) {
        if (labels[side]) node.append(el('span', `pad__label pad__label--${side}`, labels[side]));
    }

    let cx = x;
    let cy = y;

    const draw = () => {
        const left = ((cx + 1) / 2) * 100;
        const screenY = invertY ? -cy : cy;
        const top = ((screenY + 1) / 2) * 100;
        dot.style.left = `${left}%`;
        dot.style.top = `${top}%`;
        guideX.style.left = `${left}%`;
        guideY.style.top = `${top}%`;
    };

    dragOn(node, (event) => {
        const rect = node.getBoundingClientRect();
        cx = Math.round(clamp(((event.clientX - rect.left) / rect.width) * 2 - 1, -1, 1) * 100) / 100;
        const sy = Math.round(clamp(((event.clientY - rect.top) / rect.height) * 2 - 1, -1, 1) * 100) / 100;
        cy = invertY ? -sy : sy;
        draw();
        onInput?.(cx, cy);
    }, () => onCommit?.(cx, cy));

    node.addEventListener('dblclick', () => {
        cx = 0;
        cy = 0;
        draw();
        onInput?.(cx, cy);
        onCommit?.(cx, cy);
    });

    draw();

    return {
        node,
        set(nx, ny) {
            cx = nx;
            cy = ny;
            draw();
        },
    };
}

/**
 * ‹ value › picker for whole numbers, wrapping around
 * @returns {{ node: HTMLElement, set: (v: number) => void, setRange: (min: number, max: number) => void }}
 */
export function stepper({ label, value = 0, min = 0, max = 0, format, onChange }) {
    const node = el('div', 'stepper');
    const box = el('div', 'stepper__box');
    const prev = el('button', 'stepper__btn');
    const next = el('button', 'stepper__btn');
    const text = el('span', 'stepper__value');
    prev.type = 'button';
    next.type = 'button';
    prev.append(icon('left'));
    next.append(icon('right'));
    box.append(prev, text, next);
    node.append(el('span', 'stepper__label', label), box);

    let current = value;
    let lo = min;
    let hi = max;

    const show = format || ((v) => `${v - lo + 1} / ${hi - lo + 1}`);
    const draw = () => { text.textContent = show(current, lo, hi); };

    const step = (delta) => {
        if (hi < lo) return;
        current += delta;
        if (current > hi) current = lo;
        if (current < lo) current = hi;
        draw();
        onChange?.(current);
    };

    prev.addEventListener('click', () => step(-1));
    next.addEventListener('click', () => step(1));
    node.addEventListener('wheel', (event) => {
        event.preventDefault();
        event.stopPropagation();
        step(event.deltaY > 0 ? 1 : -1);
    }, { passive: false });

    draw();

    return {
        node,
        set(v) {
            current = v;
            draw();
        },
        setRange(newMin, newMax) {
            lo = newMin;
            hi = newMax;
            current = clamp(current, lo, Math.max(lo, hi));
            draw();
        },
    };
}

/**
 * A grid of color dots
 * @returns {{ node: HTMLElement, set: (index: number) => void }}
 */
export function swatches({ colors, value = 0, className = '', onChange }) {
    const node = el('div', `swatches ${className}`);
    const items = colors.map((color, index) => {
        const swatch = el('button', 'swatch');
        swatch.type = 'button';
        swatch.style.background = color;
        swatch.addEventListener('click', () => {
            set(index);
            onChange?.(index);
        });
        node.append(swatch);
        return swatch;
    });

    function set(index) {
        items.forEach((item, i) => item.classList.toggle('is-active', i === index));
    }

    set(value);

    return { node, set };
}

export function group(title, onReset) {
    const node = el('div', 'group');
    const head = el('div', 'group__head');
    head.append(el('span', 'group__title', title));

    if (onReset) {
        const reset = el('button', 'group__reset', 'Reset');
        reset.type = 'button';
        reset.addEventListener('click', onReset);
        head.append(reset);
    }

    node.append(head);
    return node;
}
