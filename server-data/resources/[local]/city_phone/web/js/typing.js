// The player walks while the phone is open; typing in a text field (on the phone or inside an app's frame) gives the
// keys back to the page so WASD writes letters instead of moving.
import { post } from './util.js';

const NOT_TEXT = new Set(['button', 'checkbox', 'radio', 'range', 'submit', 'reset', 'color', 'file', 'image']);
let typing = false;
let frameTyping = null;

function isField(node) {
    if (!node) return false;
    if (node.isContentEditable || node.tagName === 'TEXTAREA') return true;
    return node.tagName === 'INPUT' && !NOT_TEXT.has(node.type);
}

function update() {
    const focused = document.activeElement;
    const on = isField(focused) || (focused?.tagName === 'IFRAME' && focused === frameTyping);
    if (on === typing) return;

    typing = on;
    post('typing', { on });
}

// An app's frame says whether one of its own fields has focus (kit.js)
export function setFrameTyping(frame, on) {
    if (on) frameTyping = frame;
    else if (frameTyping === frame) frameTyping = null;
    update();
}

// Switching or closing apps: a frame that is hidden or gone can't keep the keys
export function resetFrameTyping() {
    if (document.activeElement?.tagName === 'IFRAME') document.activeElement.blur();
    frameTyping = null;
    update();
}

export function initTyping() {
    document.addEventListener('focusin', update);
    document.addEventListener('focusout', () => setTimeout(update));
}
