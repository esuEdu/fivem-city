const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_militech';

const $ = (id) => document.getElementById(id);

const STATS = [
    { key: 'speed', label: 'Speed' },
    { key: 'handling', label: 'Handling' },
    { key: 'acceleration', label: 'Acceleration' },
    { key: 'launch', label: 'Launch' },
    { key: 'braking', label: 'Braking' },
];

const CLASS_COLORS = { D: '--class-d', C: '--class-c', B: '--class-b', A: '--class-a', S1: '--class-s1', S2: '--class-s2', X: '--class-x' };

let data = null;
let settings = {};
let applied = {};
let current = null;
let group = 0;
let focused = null;
let busy = false;
let rows = new Map();
let previewTimer = null;
let previewing = false;
let previewQueued = false;
let resetTimer = null;
let toastTimer = null;

function post(name, body = {}) {
    return fetch(`https://${resource}/${name}`, { method: 'POST', body: JSON.stringify(body) })
        .then((response) => response.json())
        .catch(() => null);
}

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function signed(value, digits = 0, suffix = '') {
    const rounded = Number(value.toFixed(digits));
    if (rounded === 0) return `0${suffix}`;
    return `${rounded > 0 ? '+' : '−'}${Math.abs(rounded).toFixed(digits)}${suffix}`;
}

function digitsOf(step) {
    const text = String(step);
    return text.includes('.') ? text.split('.')[1].length : 0;
}

function same(a, b) {
    const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
    for (const key of keys) if ((a[key] || 0) !== (b[key] || 0)) return false;
    return true;
}

// What a slider shows: the resulting handling value, and the change from stock
function describe(param, value) {
    const effective = current?.values?.[param.field];
    const has = typeof effective === 'number';

    switch (param.unit) {
        case 'front':
            return { value: has ? `${(effective * 50).toFixed(1)}% F` : '—', delta: signed(value * 50, 1, '%') };
        case 'cm':
            return { value: has ? `${(effective * 100).toFixed(1)} cm` : '—', delta: signed(value * 100, 1, ' cm') };
        case 'int':
            return { value: has ? String(Math.round(effective)) : '—', delta: signed(value) };
        case 'num':
            return { value: has ? effective.toFixed(3) : '—', delta: signed(value, digitsOf(param.step)) };
        default:
            return { value: has ? effective.toFixed(3) : '—', delta: signed(value * 100, Math.max(0, digitsOf(param.step) - 2), '%') };
    }
}

function paramsOf(groupId) {
    return data.params.filter((param) => param.group === groupId);
}

function setHelp(param) {
    $('help-title').textContent = param ? param.label : '';
    $('help-text').textContent = param ? param.help : 'Pick a setting to see what it does.';
}

function renderGroups() {
    const nav = $('groups');
    nav.replaceChildren();

    data.groups.forEach((entry, index) => {
        const list = paramsOf(entry.id);
        if (list.length === 0) return;

        const button = el('button', `group${index === group ? ' is-active' : ''}`);
        button.append(el('span', null, entry.label));

        if (list.some((param) => settings[param.id])) button.append(el('i', 'group__dot'));

        button.addEventListener('click', () => {
            group = index;
            renderGroups();
            renderParams();
        });

        nav.append(button);
    });
}

function position(param, value) {
    return ((value - param.min) / (param.max - param.min)) * 100;
}

function updateRow(param) {
    const row = rows.get(param.id);
    if (!row) return;

    const value = settings[param.id] || 0;
    const text = describe(param, value);
    const at = position(param, value);
    const zero = position(param, 0);

    row.node.classList.toggle('is-changed', value !== 0);
    row.value.textContent = text.value;
    row.delta.textContent = text.delta;
    row.fill.style.left = `${Math.min(at, zero)}%`;
    row.fill.style.width = `${Math.abs(at - zero)}%`;

    if (Number(row.input.value) !== value) row.input.value = value;
}

function renderParams() {
    const entry = data.groups[group];
    const list = paramsOf(entry.id);

    $('group-title').textContent = entry.label;
    $('group-count').textContent = `${list.filter((param) => settings[param.id]).length} / ${list.length} tuned`;

    const root = $('params');
    root.replaceChildren();
    rows = new Map();

    for (const param of list) {
        const node = el('li', 'param');
        const top = el('div', 'param__top');
        const value = el('span', 'param__value');
        const delta = el('span', 'param__delta');
        top.append(el('span', 'param__label', param.label), value, delta);

        const row = el('div', 'param__row');
        const slider = el('div', 'slider');
        const track = el('span', 'slider__track');
        const fill = el('span', 'slider__fill');
        const stock = el('span', 'slider__stock');
        stock.style.left = `calc(${position(param, 0)}% - 1px)`;

        const input = document.createElement('input');
        input.type = 'range';
        input.min = param.min;
        input.max = param.max;
        input.step = param.step;
        input.value = settings[param.id] || 0;

        input.addEventListener('input', () => {
            const next = Number(Number(input.value).toFixed(4));
            if (next === 0) delete settings[param.id];
            else settings[param.id] = next;

            updateRow(param);
            updateMeta();
            schedulePreview();
        });

        // double click puts the slider back to stock
        input.addEventListener('dblclick', () => {
            delete settings[param.id];
            updateRow(param);
            updateMeta();
            schedulePreview();
        });

        slider.append(track, fill, stock, input);
        row.append(el('span', 'param__end', param.left), slider, el('span', 'param__end param__end--right', param.right));

        node.append(top, row);
        node.addEventListener('mouseenter', () => {
            focused = param.id;
            setHelp(param);
        });

        root.append(node);
        rows.set(param.id, { node, value, delta, fill, input });
        updateRow(param);
    }

    setHelp(list.find((param) => param.id === focused));
}

function renderStats() {
    const stock = data.stock.stats;
    const now = current?.stats || stock;
    const root = $('stats');
    root.replaceChildren();

    for (const stat of STATS) {
        const before = stock[stat.key];
        const after = now[stat.key];
        const diff = Number((after - before).toFixed(1));

        const item = el('li', 'stat');
        const top = el('div', 'stat__top');
        const value = el('span', 'stat__value', after.toFixed(1));

        if (diff !== 0) value.append(el('small', diff > 0 ? 'up' : 'down', signed(diff, 1)));
        top.append(el('span', null, stat.label), value);

        const bar = el('div', 'stat__bar');
        const base = el('span', 'stat__stock');
        base.style.width = `${Math.min(before, after) * 10}%`;
        bar.append(base);

        if (diff !== 0) {
            const change = el('span', diff > 0 ? 'stat__gain' : 'stat__loss');
            change.style.left = `${Math.min(before, after) * 10}%`;
            change.style.width = `${Math.abs(after - before) * 10}%`;
            bar.append(change);
        }

        item.append(top, bar);
        root.append(item);
    }

    const pi = now.pi;
    $('pi-class').textContent = now.class;
    $('pi-value').textContent = pi;
    $('pi-badge').style.setProperty('--class-color', `var(${CLASS_COLORS[now.class] || '--class-d'})`);
    $('pi-stock').textContent = `Stock ${stock.class} ${stock.pi}`;
}

function updateMeta() {
    const dirty = !same(settings, applied);
    $('dirty').classList.toggle('hidden', !dirty);
    $('apply').disabled = busy || !dirty;
    $('revert').disabled = busy || !dirty;
    $('reset').disabled = busy;

    const entry = data.groups[group];
    const list = paramsOf(entry.id);
    $('group-count').textContent = `${list.filter((param) => settings[param.id]).length} / ${list.length} tuned`;

    for (const [index, node] of [...$('groups').children].entries()) {
        const visible = data.groups.filter((item) => paramsOf(item.id).length > 0)[index];
        const changed = visible && paramsOf(visible.id).some((param) => settings[param.id]);
        const dot = node.querySelector('.group__dot');

        if (changed && !dot) node.append(el('i', 'group__dot'));
        if (!changed && dot) dot.remove();
    }
}

function schedulePreview() {
    clearTimeout(previewTimer);
    previewTimer = setTimeout(runPreview, 40);
}

async function runPreview() {
    if (previewing) {
        previewQueued = true;
        return;
    }

    previewing = true;
    const result = await post('preview', { settings });
    previewing = false;

    if (result && result.stats) {
        current = result;
        for (const param of data.params) updateRow(param);
        renderStats();
    }

    if (previewQueued) {
        previewQueued = false;
        runPreview();
    }
}

function toast(text, kind) {
    const node = $('toast');
    node.textContent = text;
    node.className = `toast is-${kind}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => node.classList.add('hidden'), 2600);
}

const ERRORS = {
    not_driver: 'You need to be in the driver seat',
    moving: 'Stop the car first',
    no_item: 'You need the Militech module',
    wait: 'Wait a moment',
    failed: 'The tuner refused that setup',
};

async function upload(reset) {
    if (busy) return;
    busy = true;
    updateMeta();

    const result = await post('apply', reset ? { reset: true } : { settings });
    busy = false;

    if (result && result.ok) {
        applied = { ...(result.settings || {}) };
        settings = { ...applied };
        current = result.current || current;
        renderGroups();
        renderParams();
        renderStats();
        toast(reset ? 'Factory handling restored' : 'Setup uploaded', 'success');
    } else {
        toast(ERRORS[result?.error] || ERRORS.failed, 'error');
    }

    updateMeta();
}

function resetButton(confirming) {
    const button = $('reset');
    button.classList.toggle('is-confirm', confirming);
    button.textContent = confirming ? 'Click again to confirm' : 'Restore factory';
}

function open(message) {
    applyTheme(message.theme);
    data = message;
    settings = { ...(message.settings || {}) };
    applied = { ...settings };
    current = message.current;
    group = 0;
    focused = null;
    busy = false;
    resetButton(false);

    $('car-name').textContent = message.vehicle.name;
    $('car-plate').textContent = message.vehicle.plate;

    renderGroups();
    renderParams();
    renderStats();
    updateMeta();
    $('toast').classList.add('hidden');
    $('app').classList.remove('hidden');
}

function close() {
    $('app').classList.add('hidden');
    data = null;
}

$('close').addEventListener('click', () => post('close'));
$('apply').addEventListener('click', () => upload(false));

$('revert').addEventListener('click', () => {
    settings = { ...applied };
    renderGroups();
    renderParams();
    updateMeta();
    schedulePreview();
});

$('reset').addEventListener('click', () => {
    if (!$('reset').classList.contains('is-confirm')) {
        resetButton(true);
        clearTimeout(resetTimer);
        resetTimer = setTimeout(() => resetButton(false), 3000);
        return;
    }

    clearTimeout(resetTimer);
    resetButton(false);
    upload(true);
});

window.addEventListener('keydown', (event) => {
    if (!data) return;
    if (event.key === 'Escape') post('close');
});

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message !== 'object') return;

    if (message.action === 'open') open(message);
    if (message.action === 'close') close();
});
