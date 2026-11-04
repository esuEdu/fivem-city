const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_inventory';

export function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch(() => null);
}

export function formatWeight(grams) {
    return grams >= 1000 ? `${(grams / 1000).toFixed(2)} kg` : `${grams} g`;
}

// '#f5c542' -> 'rgba(245, 197, 66, alpha)'
export function tint(hex, alpha) {
    const value = parseInt(hex.replace('#', ''), 16);
    return `rgba(${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255}, ${alpha})`;
}

// city_ui's theme.lua: { accentText = '#15181d' } -> --accent-text: #15181d
export function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

// A shop item's price: 'Free', '$25', or '50000 Black Money' when paid with an item
export function formatPrice(item, labels) {
    if (item.price === 0) return labels.free;
    return item.currency ? `${item.price} ${item.currency}` : `$${item.price}`;
}

export function createElement(tag, className, text) {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}
