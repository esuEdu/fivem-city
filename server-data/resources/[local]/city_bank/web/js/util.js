const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_bank';

export const state = { labels: {}, currency: '$', features: {} };

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

// A panel request forwarded to the server (client/main.lua 'call')
export async function call(name, ...args) {
    return (await post('call', { name, args })) || { ok: false, error: 'failed' };
}

// city_ui/theme.lua keys become CSS variables: accentText -> --accent-text
export function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

export function label(key, ...values) {
    let text = state.labels[key] ?? key;
    for (const value of values) text = text.replace('%s', value);
    return text;
}

export function errorText(code) {
    return state.labels[`error_${code}`] ?? label('error_failed');
}

/**
 * Builds an element. props: className, text, on{Event}, dataset, attrs (setAttribute), style (object), anything else
 * as a property. Children may be nodes, strings, nested arrays (any depth) or falsy (skipped). Never uses innerHTML.
 */
export function h(tag, props = {}, ...children) {
    const node = document.createElement(tag);

    for (const [key, value] of Object.entries(props || {})) {
        if (value === undefined || value === null || value === false) continue;
        if (key === 'className') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key === 'dataset') Object.assign(node.dataset, value);
        else if (key === 'style') Object.assign(node.style, value);
        else if (key === 'attrs') for (const [name, attr] of Object.entries(value)) node.setAttribute(name, attr);
        else if (key.startsWith('on')) node.addEventListener(key.slice(2).toLowerCase(), value);
        else node[key] = value;
    }

    for (const child of children.flat(Infinity)) {
        if (child === undefined || child === null || child === false) continue;
        node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }

    return node;
}

const SVG = 'http://www.w3.org/2000/svg';

export function svg(tag, attrs = {}, ...children) {
    const node = document.createElementNS(SVG, tag);
    for (const [name, value] of Object.entries(attrs)) node.setAttribute(name, value);
    for (const child of children.flat(Infinity)) if (child) node.append(child);
    return node;
}

// 24x24 outline icons, drawn with paths (no icon font)
const ICONS = {
    dashboard: 'M4 13h7V4H4v9Zm0 7h7v-5H4v5Zm9 0h7v-9h-7v9Zm0-16v5h7V4h-7Z',
    accounts: 'M3 7h18v12H3V7Zm2 2v8h14V9H5Zm11 3h2v2h-2v-2ZM5 5h12v2H5V5Z',
    cards: 'M3 6h18v12H3V6Zm2 2v2h14V8H5Zm0 5v3h14v-3H5Zm2 1h4v1H7v-1Z',
    transfers: 'M7 7h11l-3-3 1.4-1.4L22 8l-5.6 5.4L15 12l3-3H7V7Zm10 10H6l3 3-1.4 1.4L2 16l5.6-5.4L9 12l-3 3h11v2Z',
    loans: 'M12 2 3 7v2h18V7l-9-5ZM5 11h2v6H5v-6Zm4 0h2v6H9v-6Zm4 0h2v6h-2v-6Zm4 0h2v6h-2v-6ZM3 19h18v2H3v-2Z',
    billing: 'M6 2h12v20l-3-2-3 2-3-2-3 2V2Zm2 2v14.3l1-.7 3 2 3-2 1 .7V4H8Zm2 3h4v2h-4V7Zm0 4h4v2h-4v-2Z',
    history: 'M13 3a9 9 0 1 0 9 9h-2a7 7 0 1 1-2.05-4.95L15 10h7V3l-2.64 2.64A8.96 8.96 0 0 0 13 3Zm-1 5h2v5l4 2.4-1 1.7-5-3V8Z',
    staff: 'M12 2 4 5v6c0 5 3.4 9.7 8 11 4.6-1.3 8-6 8-11V5l-8-3Zm0 2.2 6 2.2V11c0 3.9-2.5 7.6-6 8.9-3.5-1.3-6-5-6-8.9V6.4l6-2.2Zm-1 10.4-2.3-2.3-1.4 1.4L11 17.4l5.7-5.7-1.4-1.4L11 14.6Z',
    close: 'm12 10.6 5.3-5.3 1.4 1.4-5.3 5.3 5.3 5.3-1.4 1.4-5.3-5.3-5.3 5.3-1.4-1.4 5.3-5.3-5.3-5.3 1.4-1.4 5.3 5.3Z',
    plus: 'M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6V5Z',
    move: 'M7 7h11l-3-3 1.4-1.4L22 8l-5.6 5.4L15 12l3-3H7V7Z',
    goal: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm0 2a8 8 0 1 1 0 16 8 8 0 0 1 0-16Zm0 3a5 5 0 1 0 0 10 5 5 0 0 0 0-10Zm0 2a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z',
    edit: 'M4 17.2V20h2.8l8.3-8.3-2.8-2.8L4 17.2Zm13.7-7.5a1 1 0 0 0 0-1.4l-2-2a1 1 0 0 0-1.4 0l-1.4 1.4 2.8 2.8 2-.8Z',
    users: 'M9 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8Zm0-2a2 2 0 1 0 0-4 2 2 0 0 0 0 4Zm7 2a3 3 0 1 1 0-6v2a1 1 0 1 0 0 2v2ZM2 20c0-3.3 3.1-6 7-6s7 2.7 7 6h-2c0-2.2-2.2-4-5-4s-5 1.8-5 4H2Zm16 0c0-1.5-.6-2.9-1.6-4 2.6.4 4.6 2 4.6 4h-3Z',
    exit: 'M10 3h9v18h-9v-2h7V5h-7V3Zm-1 5 1.4 1.4L8.8 11H15v2H8.8l1.6 1.6L9 16l-4-4 4-4Z',
    lock: 'M7 10V7a5 5 0 0 1 10 0v3h2v11H5V10h2Zm2 0h6V7a3 3 0 0 0-6 0v3Zm-2 2v7h10v-7H7Z',
    unlock: 'M7 10V7a5 5 0 0 1 9.6-2l-1.8.9A3 3 0 0 0 9 7v3h10v11H5V10h2Zm0 2v7h10v-7H7Z',
    wifi: 'M12 18a2 2 0 1 0 0 4 2 2 0 0 0 0-4Zm-4.2-2.8 1.4 1.4a4 4 0 0 1 5.6 0l1.4-1.4a6 6 0 0 0-8.4 0Zm-2.8-2.8 1.4 1.4a8 8 0 0 1 11.2 0l1.4-1.4a10 10 0 0 0-14 0Z',
    key: 'M7 14a5 5 0 1 1 4.6-7H22v4h-2v3h-3v-3h-5.4A5 5 0 0 1 7 14Zm0-2a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z',
    sliders: 'M4 6h9v2H4V6Zm13 0h3v2h-3v2h-2V4h2v2ZM4 16h3v2H4v-2Zm7 0h9v2h-9v2H9v-6h2v2Zm-7-5h12v2H4v-2Zm15 0h1v2h-1v2h-2V9h2v2Z',
    block: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20ZM4 12a8 8 0 0 1 12.9-6.3L5.7 16.9A7.9 7.9 0 0 1 4 12Zm8 8c-1.8 0-3.5-.6-4.9-1.7L18.3 7.1A8 8 0 0 1 12 20Z',
    check: 'M9.55 17.6 4.4 12.45l1.4-1.4 3.75 3.74 8.65-8.64 1.4 1.4-10.05 10.05Z',
    trash: 'M9 3h6l1 2h4v2H4V5h4l1-2ZM6 9h12l-1 12H7L6 9Zm2.2 2 .7 8h6.2l.7-8H8.2Z',
    pause: 'M7 5h4v14H7V5Zm6 0h4v14h-4V5Z',
    play: 'M8 5v14l11-7L8 5Z',
    send: 'M3 20.5V14l9-2-9-2V3.5L22 12 3 20.5Z',
    search: 'M10.5 3a7.5 7.5 0 0 1 5.96 12.05l4.25 4.24-1.42 1.42-4.24-4.25A7.5 7.5 0 1 1 10.5 3Zm0 2a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11Z',
    eye: 'M12 5c5 0 9 4.5 10 7-1 2.5-5 7-10 7S3 14.5 2 12c1-2.5 5-7 10-7Zm0 2c-3.6 0-6.6 3-7.8 5 1.2 2 4.2 5 7.8 5s6.6-3 7.8-5c-1.2-2-4.2-5-7.8-5Zm0 2a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z',
    cash: 'M2 6h20v12H2V6Zm2 2v8h16V8H4Zm8 1a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z',
    bank: 'M11.47 2.18a1 1 0 0 1 1.06 0l8.5 5A1 1 0 0 1 20.5 9h-17a1 1 0 0 1-.53-1.82l9-5ZM5 10.5h2.5v7H5v-7Zm5.75 0h2.5v7h-2.5v-7Zm5.75 0H19v7h-2.5v-7ZM3 19.5A1 1 0 0 1 4 18.5h16a1 1 0 0 1 0 2H4a1 1 0 0 1-1-1Z',
};

export function icon(name, className = 'icon') {
    return svg('svg', { viewBox: '0 0 24 24', class: className, 'aria-hidden': 'true' }, svg('path', { d: ICONS[name] || ICONS.plus }));
}

const numberFormat = new Intl.NumberFormat('en-US');
const compactFormat = new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 1 });

// 18000 -> $18,000 ; with sign: +$18,000 / -$250
export function money(amount, signed = false) {
    const value = Number(amount) || 0;
    const text = `${state.currency}${numberFormat.format(Math.abs(value))}`;

    if (!signed) return value < 0 ? `-${text}` : text;
    return value < 0 ? `-${text}` : `+${text}`;
}

// 18000 -> $18K (chart axes)
export function moneyShort(amount) {
    return `${state.currency}${compactFormat.format(Number(amount) || 0)}`;
}

export function dateTime(seconds) {
    return new Date(Number(seconds) * 1000).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

export function date(seconds) {
    return new Date(Number(seconds) * 1000).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

// 'bank-pix' -> label reason_bank_pix; 'shop-water' -> reason_shop; unknown -> Other
export function reasonLabel(reason) {
    const text = String(reason);
    return state.labels[`reason_${text.replace(/-/g, '_')}`]
        ?? state.labels[`reason_${text.split('-')[0]}`]
        ?? label('reason_other');
}

let toastTimer;

export function toast(message, kind = 'info') {
    const node = document.getElementById('toast');
    node.textContent = message;
    node.className = `toast toast--${kind}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => node.classList.add('hidden'), 3200);
}

// Shows the server's answer: success message, or the error text
export function report(reply, successKey) {
    if (reply && reply.ok) {
        if (successKey) toast(label(successKey), 'success');
        return true;
    }

    toast(errorText(reply?.error), 'error');
    return false;
}

export function chip(text, kind = '') {
    return h('span', { className: `chip ${kind ? `chip--${kind}` : ''}`, text });
}

export function button(text, onClick, kind = 'ghost', disabled = false, iconName = null) {
    return h('button', { className: `btn btn--${kind}`, type: 'button', onClick, disabled }, iconName ? icon(iconName) : null, text);
}

// Small square button with an icon and a tooltip, for table rows
export function iconButton(iconName, title, onClick, kind = '') {
    return h('button', { className: `ibtn ${kind ? `ibtn--${kind}` : ''}`, type: 'button', title, onClick }, icon(iconName));
}

export function field(text, input) {
    return h('label', { className: 'field' }, h('span', { className: 'field__label', text }), input);
}

export function input(props = {}) {
    return h('input', { className: 'input', autocomplete: 'off', spellcheck: false, ...props });
}

export function select(options, value) {
    const node = h('select', { className: 'input' });
    for (const option of options) node.append(h('option', { value: option.value, text: option.label, selected: String(option.value) === String(value) }));
    return node;
}

// Whole number from an input, or null
export function whole(node) {
    const value = Number(node.value);
    return node.value !== '' && Number.isInteger(value) ? value : null;
}

/**
 * Modal dialog. body: node or (nested) list of nodes. actions: [{ text, kind, onClick(close) }]. Resolves when closed.
 */
export function modal(title, body, actions = []) {
    return new Promise((resolve) => {
        const root = document.getElementById('modal');
        const close = (value) => {
            root.classList.add('hidden');
            root.replaceChildren();
            resolve(value);
        };

        root.replaceChildren(h('div', { className: 'modal__card' },
            h('header', { className: 'modal__head' },
                h('h2', { className: 'modal__title', text: title }),
                iconButton('close', label('close'), () => close(null))),
            h('div', { className: 'modal__body' }, body),
            h('footer', { className: 'modal__actions' },
                button(label(actions.length ? 'cancel' : 'close'), () => close(null)),
                actions.map((action) => button(action.text, () => action.onClick(close), action.kind || 'primary'))),
        ));
        root.classList.remove('hidden');
    });
}

// A dashboard "visual": titled box, optional tools on the right of the title
export function panel(title, body, tools = null, className = '') {
    return h('section', { className: `visual ${className}` },
        h('header', { className: 'visual__head' }, h('h3', { className: 'visual__title', text: title }), tools ? h('div', { className: 'visual__tools' }, tools) : null),
        h('div', { className: 'visual__body' }, body));
}

export function kpi(title, value, sub = '', kind = '') {
    return h('article', { className: `kpi ${kind ? `kpi--${kind}` : ''}` },
        h('p', { className: 'kpi__title', text: title }),
        h('p', { className: 'kpi__value', text: value }),
        sub ? h('p', { className: 'kpi__sub', text: sub }) : null);
}

/**
 * Compact data table. columns: [{ title, render(row) -> node|string, className, align: 'right' }]
 */
export function table(columns, rows, emptyKey = 'no_data') {
    if (!rows || rows.length === 0) return h('p', { className: 'empty', text: label(emptyKey) });

    return h('div', { className: 'table-wrap' }, h('table', { className: 'table' },
        h('thead', {}, h('tr', {}, columns.map((col) => h('th', { className: col.align === 'right' ? 'is-right' : '', text: col.title })))),
        h('tbody', {}, rows.map((row) => h('tr', {}, columns.map((col) => {
            const value = col.render(row);
            const cell = h('td', { className: `${col.className || ''} ${col.align === 'right' ? 'is-right' : ''}` });
            if (value instanceof Node) cell.append(value);
            else if (Array.isArray(value)) cell.append(...value.flat(Infinity).filter(Boolean));
            else cell.textContent = value ?? '';
            if (typeof value === 'string') cell.title = value;
            return cell;
        })))),
    ));
}

export function amountCell(value, signed = true) {
    return h('span', { className: `num ${value < 0 ? 'is-out' : value > 0 && signed ? 'is-in' : ''}`, text: money(value, signed) });
}

export function progress(fraction, text) {
    const pct = Math.max(0, Math.min(100, Math.round(fraction * 100)));
    return h('div', { className: 'progress', title: text || `${pct}%` },
        h('div', { className: 'progress__bar' }, h('div', { className: 'progress__fill', style: { width: `${pct}%` } })),
        h('span', { className: 'progress__text', text: text || `${pct}%` }));
}

export function empty(key) {
    return h('p', { className: 'empty', text: label(key) });
}

export function actions(...nodes) {
    return h('div', { className: 'row-actions' }, nodes);
}
