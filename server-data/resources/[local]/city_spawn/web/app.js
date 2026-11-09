const picker = document.getElementById('picker');
const list = document.getElementById('spots');

const ICONS = {
    garage: 'M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11v7a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-1H8v1a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1zm2.2 0h9.6l-1-3.2a1 1 0 0 0-1-.8H9.2a1 1 0 0 0-1 .8zM7.5 15a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zm9 0a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z',
    police: 'M12 2l8 3v6c0 5-3.4 9.4-8 11-4.6-1.6-8-6-8-11V5zm0 5.5l-1.2 2.6-2.8.3 2.1 1.9-.6 2.8 2.5-1.4 2.5 1.4-.6-2.8 2.1-1.9-2.8-.3z',
    hospital: 'M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zm5 4v3H7v4h3v3h4v-3h3v-4h-3V7z',
    north: 'M12 2l7 19-7-4-7 4z',
    pin: 'M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9.5a2.5 2.5 0 1 1 0-5 2.5 2.5 0 0 1 0 5z',
};
const ARROW = 'M8 5l8 7-8 7z';

let spots = [];
let index = 0;
let busy = false;

const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_spawn';

function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((res) => res.json()).catch(() => null);
}

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

function svg(path) {
    const node = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    node.setAttribute('viewBox', '0 0 24 24');
    const shape = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    shape.setAttribute('d', path);
    shape.setAttribute('fill-rule', 'evenodd');
    node.appendChild(shape);
    return node;
}

function element(tag, className, text) {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function select(next) {
    if (busy || next === index || !spots[next]) return;
    index = next;
    [...list.children].forEach((node, i) => node.classList.toggle('is-active', i === index));
    post('preview', { id: spots[index].id });
}

function confirm(i) {
    if (busy || !spots[i]) return;
    busy = true;
    picker.classList.add('is-busy');
    post('choose', { id: spots[i].id });
}

function render(labels) {
    list.replaceChildren();

    spots.forEach((spot, i) => {
        const column = element('article', `spot${i === index ? ' is-active' : ''}`);

        const icon = element('div', 'spot__icon');
        icon.style.background = /^#[0-9a-f]{3,8}$/i.test(spot.color) ? spot.color : 'var(--accent)';
        icon.appendChild(svg(ICONS[spot.icon] || ICONS.pin));

        const button = element('button', 'spot__confirm', labels.confirm);
        button.appendChild(svg(ARROW));
        button.addEventListener('click', (event) => {
            event.stopPropagation();
            select(i);
            confirm(i);
        });

        column.append(icon, element('h2', 'spot__label', spot.label), button);
        column.addEventListener('mouseenter', () => select(i));
        column.addEventListener('click', () => select(i));
        list.appendChild(column);
    });
}

function open(data) {
    applyTheme(data.theme);
    spots = Array.isArray(data.spots) ? data.spots : [];
    index = 0;
    busy = false;
    picker.classList.remove('is-busy');

    const labels = data.labels || {};
    document.getElementById('title').textContent = labels.title || '';
    document.getElementById('subtitle').textContent = labels.subtitle || '';
    document.getElementById('hint').textContent = labels.hint || '';

    render(labels);
    picker.classList.remove('hidden');
}

window.addEventListener('message', ({ data }) => {
    if (!data || typeof data !== 'object') return;

    if (data.action === 'open') open(data);
    else if (data.action === 'close') picker.classList.add('hidden');
    else if (data.action === 'unlock') {
        busy = false;
        picker.classList.remove('is-busy');
    }
});

window.addEventListener('keydown', (event) => {
    if (picker.classList.contains('hidden')) return;

    if (event.key === 'ArrowLeft' || event.key === 'a') select((index - 1 + spots.length) % spots.length);
    else if (event.key === 'ArrowRight' || event.key === 'd') select((index + 1) % spots.length);
    else if (event.key === 'Enter') confirm(index);
});
