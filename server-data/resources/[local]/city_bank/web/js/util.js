const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_bank';

// Calls a RegisterNUICallback on the Lua side and returns its answer
export async function post(name, data = {}) {
    try {
        const response = await fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });

        return await response.json();
    } catch {
        return null;
    }
}

// city_ui/theme.lua keys become CSS variables: accentText -> --accent-text
export function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

export function createElement(tag, className, text) {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

const numberFormat = new Intl.NumberFormat('en-US');

// 18000 -> $18,000 ; with sign: +$18,000 / -$250
export function formatMoney(amount, currency, signed = false) {
    const value = Number(amount) || 0;
    const text = `${currency}${numberFormat.format(Math.abs(value))}`;

    if (!signed) return value < 0 ? `-${text}` : text;
    return value < 0 ? `-${text}` : `+${text}`;
}

export function formatTime(seconds) {
    const date = new Date(Number(seconds) * 1000);

    return date.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}
