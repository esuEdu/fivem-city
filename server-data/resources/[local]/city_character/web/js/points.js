import { el, clamp } from './util.js';
import { FEATURES } from './labels.js';

// Pixels of mouse travel for a feature to go from 0 to 1
const TRAVEL = 140;

const layer = document.getElementById('points');
let defs = [];
let nodes = new Map();
let positions = new Map();
let tip = null;
let handlers = { get: () => 0, set: () => {}, commit: () => {} };
let visible = false;

function describe(def) {
    tip.replaceChildren(el('b', '', def.label));
    for (const axis of ['x', 'y']) {
        const name = def[axis];
        if (!name) continue;
        const row = el('div');
        const value = handlers.get(name);
        row.append(el('span', '', FEATURES[name]?.label || name), el('span', '', (value > 0 ? '+' : '') + value.toFixed(2)));
        tip.append(row);
    }
}

function placeTip(node) {
    tip.style.left = node.style.left;
    tip.style.top = node.style.top;
}

function centerX() {
    const nose = positions.get('nose') || positions.get('bridge');
    return nose ? nose.x : 0.5;
}

function attach(def, node) {
    node.addEventListener('pointerenter', () => {
        if (node.classList.contains('is-dragging')) return;
        describe(def);
        placeTip(node);
        tip.classList.remove('hidden');
    });

    node.addEventListener('pointerleave', () => {
        if (!node.classList.contains('is-dragging')) tip.classList.add('hidden');
    });

    node.addEventListener('pointerdown', (event) => {
        event.preventDefault();
        event.stopPropagation();
        node.setPointerCapture(event.pointerId);
        node.classList.add('is-dragging');
        layer.querySelectorAll('.point').forEach((other) => other.classList.toggle('is-dim', other !== node));

        const startX = event.clientX;
        const startY = event.clientY;
        const startValues = { x: def.x ? handlers.get(def.x) : 0, y: def.y ? handlers.get(def.y) : 0 };

        // A point on the left half of the face moves its feature the other way, so pulling outwards always widens
        const pos = positions.get(def.id);
        const flipX = def.mirror && pos && pos.x < centerX() ? -1 : 1;

        const move = (e) => {
            const dx = ((e.clientX - startX) / TRAVEL) * flipX;
            const dy = (e.clientY - startY) / TRAVEL;

            if (def.x) handlers.set(def.x, Math.round(clamp(startValues.x + dx, -1, 1) * 100) / 100);
            // Same direction as the pads: down moves towards the feature's second end label
            if (def.y) handlers.set(def.y, Math.round(clamp(startValues.y + dy, -1, 1) * 100) / 100);

            describe(def);
            placeTip(node);
            tip.classList.remove('hidden');
        };

        const up = () => {
            node.classList.remove('is-dragging');
            layer.querySelectorAll('.point').forEach((other) => other.classList.remove('is-dim'));
            tip.classList.add('hidden');
            node.removeEventListener('pointermove', move);
            node.removeEventListener('pointerup', up);
            node.removeEventListener('pointercancel', up);
            handlers.commit();
        };

        node.addEventListener('pointermove', move);
        node.addEventListener('pointerup', up);
        node.addEventListener('pointercancel', up);
    });
}

export function setupPoints(pointDefs, pointHandlers) {
    defs = pointDefs || [];
    handlers = pointHandlers;
    layer.replaceChildren();
    nodes = new Map();
    positions = new Map();

    tip = el('div', 'point-tip hidden');
    layer.append(tip);

    for (const def of defs) {
        const node = el('div', 'point hidden');
        attach(def, node);
        layer.append(node);
        nodes.set(def.id, node);
    }
}

export function showPoints(show) {
    visible = show;
    if (!show) {
        nodes.forEach((node) => node.classList.add('hidden'));
        tip?.classList.add('hidden');
    }
}

export function movePoints(points) {
    positions = new Map((points || []).map((p) => [p.id, p]));

    nodes.forEach((node, id) => {
        const pos = positions.get(id);
        if (!visible || !pos) {
            node.classList.add('hidden');
            return;
        }

        node.classList.remove('hidden');
        node.style.left = `${pos.x * 100}%`;
        node.style.top = `${pos.y * 100}%`;
    });
}
