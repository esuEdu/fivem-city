const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_militech_staff';

const $ = (id) => document.getElementById(id);

const STATS = [
    { key: 'speed', label: 'Speed' },
    { key: 'handling', label: 'Handling' },
    { key: 'acceleration', label: 'Acceleration' },
    { key: 'launch', label: 'Launch' },
    { key: 'braking', label: 'Braking' },
];

const CLASS_COLORS = { D: '--class-d', C: '--class-c', B: '--class-b', A: '--class-a', S1: '--class-s1', S2: '--class-s2', X: '--class-x' };

const ERRORS = {
    not_staff: 'Only staff can use this module',
    not_driver: 'You need to be in the driver seat',
    moving: 'Stop the car first',
    no_item: 'You need the Staff Militech module',
    wait: 'Wait a moment',
    failed: 'The tuner refused that setup',
};

let data = null;
let values = {};
let applied = {};
let stats = null;
let group = 0;
let query = '';
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

function signed(value, digits = 1) {
    const rounded = Number(value.toFixed(digits));
    if (rounded === 0) return '0';
    return `${rounded > 0 ? '+' : '−'}${Math.abs(rounded).toFixed(digits)}`;
}

function digitsOf(step) {
    const text = String(step);
    return text.includes('.') ? text.split('.')[1].length : 0;
}

function same(a, b) {
    const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
    for (const key of keys) if (a[key] !== b[key]) return false;
    return true;
}

function valueOf(row) {
    return row.id in values ? values[row.id] : row.stock;
}

function format(row, value) {
    return Number(value).toFixed(row.int ? 0 : digitsOf(row.step));
}

// The slider covers the usual range, grown to fit the stock and current values, inside the hard limits
function range(row) {
    const value = valueOf(row);
    return {
        min: Math.max(row.min, Math.min(row.soft[0], row.stock, value)),
        max: Math.min(row.max, Math.max(row.soft[1], row.stock, value)),
    };
}

function visibleRows() {
    if (query) {
        const text = query.toLowerCase();
        return data.rows.filter((row) => row.label.toLowerCase().includes(text) || row.id.toLowerCase().includes(text));
    }

    return data.rows.filter((row) => row.group === data.groups[group].id);
}

function groupsWithRows() {
    return data.groups.filter((entry) => data.rows.some((row) => row.group === entry.id));
}

function setHelp(row) {
    $('help-title').textContent = row ? `${row.label}  ·  ${row.id}` : '';
    $('help-text').textContent = row
        ? `${row.help} Stock ${format(row, row.stock)}. Allowed ${row.min} to ${row.max}.`
        : 'Pick a field to see what it does. Type any value in the box, or drag the slider.';
}

function renderGroups() {
    const nav = $('groups');
    nav.replaceChildren();

    for (const entry of groupsWithRows()) {
        const index = data.groups.indexOf(entry);
        const button = el('button', `group${!query && index === group ? ' is-active' : ''}`);
        button.append(el('span', null, entry.label));

        if (data.rows.some((row) => row.group === entry.id && row.id in values)) button.append(el('i', 'group__dot'));

        button.addEventListener('click', () => {
            group = index;
            query = '';
            $('search').value = '';
            renderGroups();
            renderParams();
        });

        nav.append(button);
    }
}

function setValue(row, value) {
    if (row.int) value = Math.round(value);
    value = Number(value.toFixed(6));

    if (Math.abs(value - row.stock) < 1e-9) delete values[row.id];
    else values[row.id] = value;

    updateRow(row);
    updateMeta();
    schedulePreview();
}

function updateRow(row, skipInput) {
    const entry = rows.get(row.id);
    if (!entry) return;

    const value = valueOf(row);
    const { min, max } = range(row);
    const span = max - min || 1;
    const at = ((value - min) / span) * 100;
    const zero = ((row.stock - min) / span) * 100;

    entry.node.classList.toggle('is-changed', row.id in values);
    entry.slider.min = min;
    entry.slider.max = max;
    entry.slider.value = value;
    entry.fill.style.left = `${Math.min(at, zero)}%`;
    entry.fill.style.width = `${Math.abs(at - zero)}%`;
    entry.mark.style.left = `calc(${zero}% - 1px)`;
    entry.reset.disabled = !(row.id in values);
    entry.delta.textContent = row.id in values ? signed(value - row.stock, row.int ? 0 : Math.min(3, digitsOf(row.step))) : '';

    if (!skipInput) {
        entry.number.value = format(row, value);
        entry.number.classList.remove('is-invalid');
    }
}

function renderParams() {
    const list = visibleRows();

    $('group-title').textContent = query ? `Search: ${query}` : data.groups[group].label;
    $('group-count').textContent = `${list.filter((row) => row.id in values).length} / ${list.length} changed`;

    const root = $('params');
    root.replaceChildren();
    rows = new Map();

    for (const row of list) {
        const node = el('li', 'param');

        const top = el('div', 'param__top');
        const label = el('span', 'param__label', row.label);
        if (row.unit) label.append(el('span', 'param__unit', row.unit === 'front' ? '1.00 = even' : row.unit));
        const delta = el('span', 'param__delta');
        top.append(label, el('span', 'param__field', row.id), el('span', 'param__stock', `stock ${format(row, row.stock)}`), delta);

        const line = el('div', 'param__row param__row--staff');
        const slider = el('div', 'slider');
        const fill = el('span', 'slider__fill');
        const mark = el('span', 'slider__stock');

        const input = document.createElement('input');
        input.type = 'range';
        input.step = row.step;
        input.addEventListener('input', () => setValue(row, Number(input.value)));
        input.addEventListener('dblclick', () => setValue(row, row.stock));
        slider.append(el('span', 'slider__track'), fill, mark, input);

        const number = document.createElement('input');
        number.className = 'number';
        number.type = 'text';
        number.inputMode = 'decimal';
        number.spellcheck = false;

        number.addEventListener('input', () => {
            const value = Number(number.value.replace(',', '.'));
            const valid = number.value.trim() !== '' && Number.isFinite(value) && value >= row.min && value <= row.max
                && (!row.int || Number.isInteger(value));

            number.classList.toggle('is-invalid', !valid);
            if (!valid) return;

            if (row.int) setValue(row, value);
            else {
                values[row.id] = value;
                if (Math.abs(value - row.stock) < 1e-9) delete values[row.id];
                updateRow(row, true);
                updateMeta();
                schedulePreview();
            }
        });

        number.addEventListener('blur', () => updateRow(row));
        number.addEventListener('keydown', (event) => {
            if (event.key === 'Enter') number.blur();
            event.stopPropagation();
        });

        const reset = el('button', 'param__reset', '↺');
        reset.title = 'Back to stock';
        reset.addEventListener('click', () => setValue(row, row.stock));

        line.append(slider, number, reset);
        node.append(top, line);
        node.addEventListener('mouseenter', () => {
            focused = row.id;
            setHelp(row);
        });

        root.append(node);
        rows.set(row.id, { node, slider: input, number, fill, mark, reset, delta });
        updateRow(row);
    }

    setHelp(list.find((row) => row.id === focused));
}

function renderStats() {
    const stock = data.stockStats;
    const now = stats || stock;
    const root = $('stats');
    root.replaceChildren();

    for (const stat of STATS) {
        const before = stock[stat.key];
        const after = now[stat.key];
        const diff = Number((after - before).toFixed(1));

        const item = el('li', 'stat');
        const top = el('div', 'stat__top');
        const value = el('span', 'stat__value', after.toFixed(1));

        if (diff !== 0) value.append(el('small', diff > 0 ? 'up' : 'down', signed(diff)));
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

    $('pi-class').textContent = now.class;
    $('pi-value').textContent = now.pi;
    $('pi-badge').style.setProperty('--class-color', `var(${CLASS_COLORS[now.class] || '--class-d'})`);
    $('pi-stock').textContent = `Stock ${stock.class} ${stock.pi}`;
}

function updateMeta() {
    const dirty = !same(values, applied);
    $('dirty').classList.toggle('hidden', !dirty);
    $('apply').disabled = busy || !dirty;
    $('revert').disabled = busy || !dirty;
    $('reset').disabled = busy || Object.keys(applied).length === 0;

    const list = visibleRows();
    $('group-count').textContent = `${list.filter((row) => row.id in values).length} / ${list.length} changed`;

    const shown = groupsWithRows();
    [...$('groups').children].forEach((node, index) => {
        const entry = shown[index];
        const changed = entry && data.rows.some((row) => row.group === entry.id && row.id in values);
        const dot = node.querySelector('.group__dot');

        if (changed && !dot) node.append(el('i', 'group__dot'));
        if (!changed && dot) dot.remove();
    });
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
    const result = await post('preview', { values });
    previewing = false;

    if (result && result.stats) {
        stats = result.stats;
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

// The server sends back every field it keeps, stock-equal ones included: keep only real changes
function changesOnly(next) {
    const out = {};

    for (const row of data.rows) {
        const value = next?.[row.id];
        if (typeof value === 'number' && Math.abs(value - row.stock) >= 1e-9) out[row.id] = value;
    }

    return out;
}

async function upload(reset) {
    if (busy) return;
    busy = true;
    updateMeta();

    const result = await post('apply', reset ? { reset: true } : { values });
    busy = false;

    if (result && result.ok) {
        applied = changesOnly(result.values);
        values = { ...applied };
        stats = result.stats || stats;
        renderGroups();
        renderParams();
        renderStats();
        toast(reset ? 'Staff setup removed' : 'Staff setup uploaded', 'success');
    } else {
        toast(ERRORS[result?.error] || ERRORS.failed, 'error');
    }

    updateMeta();
}

function resetButton(confirming) {
    const button = $('reset');
    button.classList.toggle('is-confirm', confirming);
    button.textContent = confirming ? 'Click again to confirm' : 'Remove staff setup';
}

function open(message) {
    applyTheme(message.theme);
    data = message;
    values = changesOnly(message.values);
    applied = { ...values };
    stats = message.stats;
    group = 0;
    query = '';
    focused = null;
    busy = false;
    $('search').value = '';
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

$('search').addEventListener('input', () => {
    query = $('search').value.trim();
    renderGroups();
    renderParams();
});

$('search').addEventListener('keydown', (event) => event.stopPropagation());

$('close').addEventListener('click', () => post('close'));
$('apply').addEventListener('click', () => upload(false));

$('revert').addEventListener('click', () => {
    values = { ...applied };
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
