const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_dealership';

const $ = (id) => document.getElementById(id);

const STATS = ['speed', 'acceleration', 'braking', 'traction'];

let labels = {};
let data = null;
let category = 'all';
let selected = null;
let plan = 'full';
let account = 'bank';
let count = null;
let confirming = false;
let busy = false;

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

function format(text, ...values) {
    let out = text || '';
    for (const value of values) out = out.replace('%s', value);
    return out;
}

function money(value) {
    return `$${Number(value || 0).toLocaleString('en-US')}`;
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

function categoryLabel(id) {
    const found = data.categories.find((cat) => cat.id === id);
    return found ? found.label : id;
}

// Same math as server/quote.lua; the server recomputes it, this is only what the player sees
function quote(price, downPct, installments) {
    const fin = data.finance;
    const down = Math.ceil(price * downPct / 100);
    const financed = price - down;
    const debt = financed + Math.ceil(financed * fin.interestPct / 100);
    const installment = Math.floor(debt / installments);

    return { down, financed, debt, interest: debt - financed, installment, last: debt - installment * (installments - 1) };
}

function visibleCars() {
    const query = $('search').value.trim().toLowerCase();
    const sort = $('sort').value;

    return data.vehicles
        .filter((car) => category === 'all' || car.category === category)
        .filter((car) => !query || `${car.brand} ${car.name} ${car.model}`.toLowerCase().includes(query))
        .sort((a, b) => {
            if (sort === 'price-desc') return b.price - a.price;
            if (sort === 'name') return `${a.brand} ${a.name}`.localeCompare(`${b.brand} ${b.name}`);
            return a.price - b.price;
        });
}

function renderCategories() {
    const list = $('cats');
    list.replaceChildren();

    const entries = [{ id: 'all', label: labels.ui_all }, ...data.categories];

    for (const cat of entries) {
        const total = cat.id === 'all' ? data.vehicles.length : data.vehicles.filter((car) => car.category === cat.id).length;
        if (total === 0) continue;

        const item = el('li', `cats__item${category === cat.id ? ' is-active' : ''}`);
        item.append(el('span', null, cat.label), el('b', null, String(total)));
        item.addEventListener('click', () => {
            category = cat.id;
            renderCategories();
            renderGrid();
        });
        list.append(item);
    }
}

// Waiting images stay in the layout (opacity, not display: none) so loading="lazy" still fetches them.
function photo(img, fallback, car) {
    img.classList.remove('hidden');
    img.classList.add('is-loading');
    fallback.classList.add('hidden');
    img.onload = () => img.classList.remove('is-loading');
    img.onerror = () => {
        img.classList.add('hidden');
        fallback.classList.remove('hidden');
    };
    img.alt = car.name;
    img.src = car.image;
}

function fallbackIcon() {
    const svg = $('photo-fallback').cloneNode(true);
    svg.removeAttribute('id');
    svg.setAttribute('class', 'card__fallback hidden');
    return svg;
}

function renderGrid() {
    const grid = $('grid');
    const cars = visibleCars();
    grid.replaceChildren();

    for (const car of cars) {
        const card = el('li', `card${selected && selected.model === car.model ? ' is-selected' : ''}`);
        const figure = el('figure', 'card__photo');
        const img = document.createElement('img');
        img.loading = 'lazy';
        const fallback = fallbackIcon();
        figure.append(img, fallback);
        photo(img, fallback, car);

        const info = el('div', 'card__info');
        info.append(el('span', 'card__brand', car.brand || categoryLabel(car.category)), el('span', 'card__name', car.name));

        card.append(figure, info, el('span', 'card__price', money(car.price)));
        card.addEventListener('click', () => select(car));
        grid.append(card);
    }

    $('count').textContent = format(labels.ui_count, cars.length);
    $('empty').classList.toggle('hidden', cars.length > 0);
}

function renderStats(stats) {
    const box = $('stats');
    box.replaceChildren();

    for (const key of STATS) {
        const value = Number(stats[key] || 0);
        const row = el('div', 'stat');
        const bar = el('div', 'stat__bar');
        const fill = el('i');
        fill.style.width = `${value}%`;
        bar.append(fill);
        row.append(el('span', 'stat__label', labels[`ui_${key}`]), bar, el('span', 'stat__value', String(value)));
        box.append(row);
    }

    $('d-seats').textContent = stats.seats ? String(stats.seats) : '-';
    $('d-top').textContent = stats.topSpeed ? `${stats.topSpeed} km/h` : '-';
}

async function select(car) {
    selected = car;
    confirming = false;

    $('placeholder').classList.add('hidden');
    $('detail').classList.remove('hidden');
    photo($('photo'), $('photo-fallback'), car);

    $('d-brand').textContent = car.brand;
    $('d-name').textContent = car.name;
    $('d-category').textContent = categoryLabel(car.category);
    $('d-price').textContent = money(car.price);
    renderStats({});
    renderPay();
    renderGrid();

    const stats = await post('stats', { model: car.model });
    if (selected === car && stats) renderStats(stats);
}

function renderPay() {
    if (!selected) return;

    const fin = data.finance;
    const financed = plan === 'finance';

    for (const button of document.querySelectorAll('[data-plan]')) button.classList.toggle('is-active', button.dataset.plan === plan);
    for (const button of document.querySelectorAll('[data-account]')) button.classList.toggle('is-active', button.dataset.account === account);

    $('fin').classList.toggle('hidden', !financed);

    let due = selected.price;

    if (financed) {
        const downPct = Number($('down').value);
        const q = quote(selected.price, downPct, count);
        due = q.down;

        $('down-value').textContent = `${downPct}% · ${money(q.down)}`;
        $('s-down').textContent = money(q.down);
        $('s-interest').textContent = `${fin.interestPct}% · ${money(q.interest)}`;
        $('s-inst').textContent = format(labels.ui_installment_of, count, Number(q.installment).toLocaleString('en-US'));
        $('s-total').textContent = money(q.down + q.debt);

        for (const chip of $('counts').children) chip.classList.toggle('is-active', Number(chip.dataset.count) === count);
    }

    const balance = data.balances[account] || 0;
    const buy = $('buy');
    buy.disabled = busy || balance < due;
    buy.textContent = confirming ? `${labels.ui_confirm} · ${money(due)}` : `${labels.ui_buy} · ${money(due)}`;
    buy.classList.toggle('is-confirm', confirming);
    $('cancel').classList.toggle('hidden', !confirming);
}

function renderFinances() {
    const list = $('finance-list');
    const rows = data.finances || [];
    list.replaceChildren();

    $('finance-count').textContent = String(rows.length);
    $('finance-count').classList.toggle('hidden', rows.length === 0);
    $('finance-empty').classList.toggle('hidden', rows.length > 0);

    for (const row of rows) {
        const car = data.vehicles.find((entry) => entry.model === row.model);
        const item = el('li', 'loan');
        const figure = el('figure', 'loan__photo');
        const img = document.createElement('img');
        const fallback = fallbackIcon();
        figure.append(img, fallback);
        photo(img, fallback, car || { name: row.model, image: '' });

        const head = el('div', 'loan__head');
        head.append(el('b', null, car ? `${car.brand} ${car.name}`.trim() : row.model), el('span', 'plate', row.plate));
        if (row.overdue > 0) head.append(el('span', 'chip chip--danger', format(labels.ui_overdue, row.overdue)));

        const progress = el('div', 'loan__bar');
        const fill = el('i');
        fill.style.width = `${Math.min(100, Math.round(row.paid / row.debt * 100))}%`;
        progress.append(fill);

        const facts = el('dl', 'loan__facts');
        const add = (label, value) => {
            const pair = el('div');
            pair.append(el('dt', null, label), el('dd', null, value));
            facts.append(pair);
        };
        add(labels.ui_paid, `${money(row.paid)} / ${money(row.debt)}`);
        add(labels.ui_installments, `${row.issued} / ${row.count}`);
        add(labels.ui_left, money(row.debt - row.paid));
        add(labels.ui_next, row.nextAt ? `${money(row.installment)} · ${nextIn(row.nextAt)}` : '-');

        const body = el('div', 'loan__body');
        body.append(head, progress, facts);

        const pay = el('button', 'btn btn--accent', format(labels.ui_pay_off, Number(row.payoff).toLocaleString('en-US')));
        pay.title = labels.ui_pay_off_hint;
        pay.disabled = busy || row.payoff <= 0 || (data.balances.bank || 0) < row.payoff;
        pay.addEventListener('click', () => payOff(row));

        item.append(figure, body, pay);
        list.append(item);
    }
}

function nextIn(timestamp) {
    const seconds = timestamp - Math.floor(Date.now() / 1000);
    if (seconds <= 0) return labels.ui_now;

    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
}

function renderWallet() {
    $('cash').textContent = money(data.balances.cash);
    $('bank').textContent = money(data.balances.bank);
}

function setView(view) {
    for (const tab of document.querySelectorAll('[data-view]')) tab.classList.toggle('is-active', tab.dataset.view === view);
    $('catalog').classList.toggle('hidden', view !== 'catalog');
    $('finance').classList.toggle('hidden', view !== 'finance');
    if (view === 'finance') renderFinances();
}

function update(result) {
    if (result.balances) data.balances = result.balances;
    if (result.finances) data.finances = result.finances;
    renderWallet();
    renderFinances();
}

async function buy() {
    if (!selected || busy) return;

    if (!confirming) {
        confirming = true;
        renderPay();
        return;
    }

    busy = true;
    renderPay();

    const result = await post('buy', {
        model: selected.model,
        account,
        financed: plan === 'finance',
        downPct: Number($('down').value),
        count,
    });

    busy = false;
    confirming = false;
    if (result) update(result);
    renderPay();
}

async function payOff(row) {
    if (busy) return;

    busy = true;
    renderFinances();
    const result = await post('payOff', { id: row.id });
    busy = false;
    if (result) update(result);
    renderFinances();
}

function open(payload) {
    data = payload;
    category = 'all';
    selected = null;
    plan = 'full';
    account = 'bank';
    confirming = false;
    busy = false;

    const fin = data.finance;
    count = fin.installments[0];

    $('title').textContent = data.label;
    $('search').value = '';
    $('sort').value = 'price-asc';
    $('down').min = fin.minDownPct;
    $('down').max = 90;
    $('down').value = fin.minDownPct;
    $('l-inst').textContent = labels.ui_installments;
    $('fin-note').textContent = `${format(labels.ui_every, fin.everyHours)}. ${format(labels.ui_finance_note, fin.repoAfter)}`;
    $('test-hint').textContent = format(labels.ui_test_drive_hint, data.testDriveSeconds);

    const counts = $('counts');
    counts.replaceChildren();
    for (const value of fin.installments) {
        const chip = el('button', 'chip chip--pick', `${value}x`);
        chip.dataset.count = value;
        chip.addEventListener('click', () => {
            count = value;
            confirming = false;
            renderPay();
        });
        counts.append(chip);
    }

    // Financing switched off in Config.Features: only buying in full, no "my financing" view
    $('plan-finance').classList.toggle('hidden', !data.financeEnabled);
    $('view-finance').classList.toggle('hidden', !data.financeEnabled);

    $('placeholder').classList.remove('hidden');
    $('detail').classList.add('hidden');

    renderWallet();
    renderCategories();
    renderGrid();
    renderFinances();
    setView('catalog');

    $('shop').classList.remove('hidden');
}

function close() {
    $('shop').classList.add('hidden');
    data = null;
}

function applyLabels() {
    $('kicker').textContent = labels.ui_kicker;
    $('view-catalog').textContent = labels.ui_catalog;
    $('view-finance-label').textContent = labels.ui_my_finance;
    $('cash-label').textContent = labels.ui_cash;
    $('bank-label').textContent = labels.ui_bank;
    $('close').setAttribute('aria-label', labels.ui_close);
    $('search').placeholder = labels.ui_search;
    $('sort-price-asc').textContent = labels.ui_sort_price_asc;
    $('sort-price-desc').textContent = labels.ui_sort_price_desc;
    $('sort-name').textContent = labels.ui_sort_name;
    $('empty').textContent = labels.ui_empty;
    $('placeholder').textContent = labels.ui_select;
    $('l-category').textContent = labels.ui_category;
    $('l-seats').textContent = labels.ui_seats;
    $('l-top').textContent = labels.ui_top_speed;
    $('l-price').textContent = labels.ui_price;
    $('test-label').textContent = labels.ui_test_drive;
    $('plan-full').textContent = labels.ui_pay_full;
    $('plan-finance').textContent = labels.ui_finance;
    $('acc-bank').textContent = labels.ui_bank;
    $('acc-cash').textContent = labels.ui_cash;
    $('l-down').textContent = labels.ui_down;
    $('l-down2').textContent = labels.ui_down;
    $('l-installments').textContent = labels.ui_installments;
    $('l-interest').textContent = labels.ui_interest;
    $('l-total').textContent = labels.ui_total;
    $('garage-hint').textContent = labels.ui_garage_hint;
    $('cancel').textContent = labels.ui_cancel;
    $('finance-empty').textContent = labels.ui_finance_empty;
}

$('search').addEventListener('input', renderGrid);
$('sort').addEventListener('change', renderGrid);
$('close').addEventListener('click', () => post('close'));
$('buy').addEventListener('click', buy);
$('cancel').addEventListener('click', () => {
    confirming = false;
    renderPay();
});
$('down').addEventListener('input', () => {
    confirming = false;
    renderPay();
});
$('test').addEventListener('click', () => {
    if (selected) post('testDrive', { model: selected.model });
});

for (const tab of document.querySelectorAll('[data-view]')) tab.addEventListener('click', () => setView(tab.dataset.view));

for (const button of document.querySelectorAll('[data-plan]')) {
    button.addEventListener('click', () => {
        plan = button.dataset.plan;
        confirming = false;
        renderPay();
    });
}

for (const button of document.querySelectorAll('[data-account]')) {
    button.addEventListener('click', () => {
        account = button.dataset.account;
        confirming = false;
        renderPay();
    });
}

window.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || !data) return;
    if (confirming) {
        confirming = false;
        renderPay();
        return;
    }
    post('close');
});

window.addEventListener('message', ({ data: message }) => {
    if (message.action === 'open') open(message);
    else if (message.action === 'close') close();
});

post('ready').then((setup) => {
    if (!setup) return;
    applyTheme(setup.theme);
    labels = setup.labels || {};
    applyLabels();
});
