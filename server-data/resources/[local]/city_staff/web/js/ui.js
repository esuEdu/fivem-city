// Small DOM and text helpers shared by the Staff app's tabs. Game data only ever goes in with textContent.

let labels = {};

export function setLabels(next) {
    labels = next || {};
}

export function L(key, ...args) {
    let text = labels[key] ?? key;
    for (const arg of args) text = text.replace(/%[sd]/, String(arg));
    return text;
}

// el('button', { class: 'kit-btn', text: 'Go', onclick: fn }, child, ...)
export function el(tag, props = {}, ...children) {
    const node = document.createElement(tag);

    for (const [key, value] of Object.entries(props)) {
        if (value === undefined || value === null || value === false) continue;
        if (key === 'class') node.className = value;
        else if (key === 'text') node.textContent = value;
        else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
        else if (key === 'value') node.value = value;
        else node.setAttribute(key, value === true ? '' : value);
    }

    for (const child of children.flat()) {
        if (child === null || child === undefined || child === false) continue;
        node.append(typeof child === 'string' ? document.createTextNode(child) : child);
    }

    return node;
}

let toastTimer = null;

export function toast(text, kind = 'ok') {
    const node = document.getElementById('toast');
    node.textContent = text;
    node.className = `show ${kind}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => (node.className = ''), 3200);
}

// One staff action through the app's client script; failures show why
export async function run(action, args = {}, done) {
    const response = await window.CityOS.send('run', { action, args });

    if (!response || !response.ok) {
        toast(L(`error_${(response && response.reason) || 'failed'}`), 'bad');
        return null;
    }

    if (done) toast(done);
    return response;
}

// A titled list group, as in Settings
export function section(title, children, foot) {
    return el('section', {},
        title ? el('div', { class: 'kit-head', text: title }) : null,
        el('div', { class: 'kit-group' }, children),
        foot ? el('div', { class: 'kit-foot', text: foot }) : null,
    );
}

export function infoRow(label, value) {
    return el('div', { class: 'kit-row' }, el('span', { text: label }), el('span', { class: 'kit-value', text: value ?? '—' }));
}

// A button that asks once more ("Sure?") before doing something hard to undo
export function confirmButton(label, onConfirm, kind = 'danger') {
    let armed = false;
    let timer = null;

    const button = el('button', { class: `kit-btn ${kind}`, text: label });
    button.addEventListener('click', () => {
        if (!armed) {
            armed = true;
            button.textContent = L('ui_sure');
            timer = setTimeout(() => {
                armed = false;
                button.textContent = label;
            }, 3000);
            return;
        }

        clearTimeout(timer);
        armed = false;
        button.textContent = label;
        onConfirm();
    });

    return button;
}

export function formatTime(unix) {
    if (!unix) return '—';
    const date = new Date(unix * 1000);
    return date.toLocaleString([], { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
}

export function ago(unix) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000 - unix));
    if (seconds < 60) return L('ui_just_now');
    if (seconds < 3600) return L('ui_minutes_ago', Math.floor(seconds / 60));
    return L('ui_hours_ago', Math.floor(seconds / 3600));
}

export function searchField(placeholder, oninput) {
    return el('label', { class: 'kit-search' }, el('input', { type: 'text', placeholder, oninput: (event) => oninput(event.target.value.trim().toLowerCase()) }));
}
