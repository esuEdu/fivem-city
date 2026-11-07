// The phone app kit: what every app page shares so they all look alike. An app loads it with
//   <link rel="stylesheet" href="https://cfx-nui-city_phone/web/kit/kit.css">
//   import { h, button, icon, ... } from 'https://cfx-nui-city_phone/web/kit/kit.js';
// and calls applyContext(message) with the phone's 'city_phone:context' message.
import { ICONS, icon } from './icons.js';

export { ICONS, icon };

// h('div', 'class', 'text', child, ...): text always through textContent, falsy children skipped
export function h(tag, className, text, ...children) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null && text !== '') node.textContent = text;
    node.append(...children.flat(Infinity).filter(Boolean));
    return node;
}

export function button(className, text, onClick, ...children) {
    const node = h('button', className, text, ...children);
    node.type = 'button';
    node.addEventListener('click', onClick);
    return node;
}

// A round or plain button with one of our icons
export function iconButton(className, name, onClick, label) {
    const node = button(className, null, onClick, icon(name));
    if (label) node.setAttribute('aria-label', label);
    return node;
}

export function input(className, placeholder, maxLength) {
    const node = h('input', className);
    Object.assign(node, { placeholder, maxLength, spellcheck: false });
    return node;
}

// Theme, font and the city_ui colors from the phone
export function applyContext(context) {
    const root = document.documentElement;
    root.dataset.theme = context.theme === 'light' ? 'light' : 'dark';
    root.style.setProperty('--font', context.font || 'Inter');

    for (const [name, value] of Object.entries(context.colors || {})) {
        if (value) root.style.setProperty(`--${name}`, value);
    }
}

// 5551234567 -> (555) 123-4567
export function formatNumber(number) {
    if (!number) return '';
    if (number.length === 10) return `(${number.slice(0, 3)}) ${number.slice(3, 6)}-${number.slice(6)}`;
    return number;
}

export function initials(name) {
    const letters = (name || '').split(/\s+/).filter((part) => /\p{L}/u.test(part[0] || '')).map((part) => part[0]);
    return (letters.length > 1 ? letters[0] + letters.at(-1) : letters[0] || '#').toUpperCase();
}

const AVATAR_COLORS = [
    ['#ff8a65', '#f4511e'], ['#64b5f6', '#1e88e5'], ['#81c784', '#43a047'], ['#ba68c8', '#8e24aa'],
    ['#ffd54f', '#f9a825'], ['#4dd0e1', '#00acc1'], ['#f06292', '#d81b60'], ['#a1887f', '#6d4c41'],
];

// A round avatar with initials, colored from the name so the same person always gets the same color
export function avatar(name, size = '', iconName = null) {
    const seed = [...(name || '')].reduce((sum, char) => sum + char.charCodeAt(0), 0);
    const [from, to] = AVATAR_COLORS[seed % AVATAR_COLORS.length];
    const node = h('span', `k-avatar ${size}`);
    node.style.background = `linear-gradient(180deg, ${from}, ${to})`;
    node.append(iconName ? icon(iconName) : document.createTextNode(initials(name)));
    return node;
}

let toastTimer = null;

export function toast(text) {
    let node = document.getElementById('k-toast');
    if (!node) {
        node = h('div', 'k-toast');
        node.id = 'k-toast';
        document.body.append(node);
    }

    node.textContent = text;
    node.classList.add('k-toast--on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => node.classList.remove('k-toast--on'), 2200);
}

// A full-screen sheet that slides up over the app
export function openSheet(...children) {
    let node = document.getElementById('k-sheet');
    if (!node) {
        node = h('section', 'k-sheet');
        node.id = 'k-sheet';
        document.body.append(node);
    }

    node.replaceChildren(...children.flat(Infinity).filter(Boolean));
    node.scrollTop = 0;
    requestAnimationFrame(() => node.classList.add('k-sheet--open'));
}

export function closeSheet() {
    document.getElementById('k-sheet')?.classList.remove('k-sheet--open');
}

// The bar at the top of a page or sheet: left action, centered title (text or an element), right action
export function navBar(left, title, right) {
    const middle = title instanceof Node ? h('div', 'k-navbar__title', null, title) : h('div', 'k-navbar__title', title);
    return h('div', 'k-navbar', null, h('div', 'k-navbar__side', null, left), middle, h('div', 'k-navbar__side k-navbar__side--end', null, right));
}

// A "‹ Back" text button
export function backButton(label, onClick) {
    return button('k-link k-back', null, onClick, icon('back'), h('span', '', label));
}
