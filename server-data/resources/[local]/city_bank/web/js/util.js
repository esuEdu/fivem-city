const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_bank';

export const state = { labels: {}, currency: '$' };

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
 * Builds an element. props: className, text, on{Event}, dataset, attrs (setAttribute), anything else as a property.
 * Children may be nodes, strings (as text) or falsy (skipped). Never uses innerHTML.
 */
export function h(tag, props = {}, ...children) {
    const node = document.createElement(tag);

    for (const [key, value] of Object.entries(props || {})) {
        if (value === undefined || value === null) continue;
        if (key === 'className') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key === 'dataset') Object.assign(node.dataset, value);
        else if (key === 'attrs') for (const [name, attr] of Object.entries(value)) node.setAttribute(name, attr);
        else if (key.startsWith('on')) node.addEventListener(key.slice(2).toLowerCase(), value);
        else node[key] = value;
    }

    for (const child of children.flat()) {
        if (child === undefined || child === null || child === false) continue;
        node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }

    return node;
}

const numberFormat = new Intl.NumberFormat('en-US');

// 18000 -> $18,000 ; with sign: +$18,000 / -$250
export function money(amount, signed = false) {
    const value = Number(amount) || 0;
    const text = `${state.currency}${numberFormat.format(Math.abs(value))}`;

    if (!signed) return value < 0 ? `-${text}` : text;
    return value < 0 ? `-${text}` : `+${text}`;
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

export function pill(text, kind = '') {
    return h('span', { className: `pill ${kind ? `pill--${kind}` : ''}`, text });
}

export function button(text, onClick, kind = 'ghost', disabled = false) {
    return h('button', { className: `button button--${kind}`, type: 'button', text, onClick, disabled });
}

export function field(text, input) {
    return h('label', { className: 'field' }, h('span', { className: 'field__label', text }), input);
}

export function input(props = {}) {
    return h('input', { className: 'input', autocomplete: 'off', spellcheck: false, ...props });
}

export function select(options, value) {
    const node = h('select', { className: 'input' });
    for (const option of options) node.append(h('option', { value: option.value, text: option.label, selected: option.value === value }));
    return node;
}

// Whole number from an input, or null
export function whole(node) {
    const value = Number(node.value);
    return Number.isInteger(value) ? value : null;
}

/**
 * Modal dialog. actions: [{ text, kind, onClick(close) }]. Resolves when closed.
 */
export function modal(title, body, actions = []) {
    return new Promise((resolve) => {
        const root = document.getElementById('modal');
        const close = (value) => {
            root.classList.add('hidden');
            root.replaceChildren();
            resolve(value);
        };

        const footer = h('div', { className: 'modal__actions' },
            button(label('cancel'), () => close(null)),
            actions.map((action) => button(action.text, () => action.onClick(close), action.kind || 'primary')),
        );

        root.replaceChildren(h('div', { className: 'modal__card' },
            h('h2', { className: 'modal__title', text: title }),
            h('div', { className: 'modal__body' }, body),
            footer,
        ));
        root.classList.remove('hidden');
    });
}

export function section(title, ...children) {
    return h('section', { className: 'card' }, h('p', { className: 'eyebrow', text: title }), children);
}

export function empty(key) {
    return h('p', { className: 'muted', text: label(key) });
}
