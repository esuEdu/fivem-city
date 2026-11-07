// The sentence counter and the prison computer. Text from the game is always set with textContent.
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_prison';

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((response) => response.json()).catch(() => null);
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
    if (text !== undefined && text !== null) node.textContent = String(text);
    return node;
}

const $ = (id) => document.getElementById(id);

let labels = {};
let data = { inmates: [], history: [], allowed: {} };
let dialogAction = null;

function counter(message) {
    $('counter').classList.toggle('hidden', !message.visible);
    $('counter').classList.toggle('done', !!message.done);
    $('counter-label').textContent = message.label || '';
    $('counter-text').textContent = message.text || '';
}

function when(seconds) {
    return new Date(seconds * 1000).toLocaleString([], { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
}

function button(text, className, onClick) {
    const node = el('button', className, text);
    node.addEventListener('click', onClick);
    return node;
}

function table(headers) {
    const node = el('table');
    const row = el('tr');
    for (const header of headers) row.appendChild(el('th', null, header));
    const head = el('thead');
    head.appendChild(row);
    node.appendChild(head);
    node.appendChild(el('tbody'));
    return node;
}

function renderInmates() {
    const view = $('inmates');
    view.replaceChildren();

    if (!data.inmates.length) {
        view.appendChild(el('div', 'empty', labels.empty_inmates));
        return;
    }

    const list = table([labels.col_name, labels.col_status, labels.col_left, labels.col_sentence, labels.col_reduced, labels.col_officer, '']);
    const body = list.querySelector('tbody');

    for (const inmate of data.inmates) {
        const row = el('tr');
        const escaped = inmate.status === 'escaped';

        const name = el('td');
        name.appendChild(el('span', 'name', inmate.name));
        const sub = el('span', 'sub');
        sub.appendChild(el('span', inmate.online ? 'dot on' : 'dot'));
        sub.appendChild(document.createTextNode(`${inmate.online ? labels.online : labels.offline} · ${inmate.citizenid}`));
        name.appendChild(sub);
        row.appendChild(name);

        const status = el('td');
        status.appendChild(el('span', escaped ? 'badge escaped' : 'badge', escaped ? labels.status_escaped : labels.status_serving));
        row.appendChild(status);

        row.appendChild(el('td', 'mono', escaped ? `${labels.owed} ${inmate.owed} ${labels.months_short}` : `${inmate.months} ${labels.months_short}`));
        row.appendChild(el('td', 'mono', `${inmate.original} ${labels.months_short}`));
        row.appendChild(el('td', 'mono', `${inmate.reduced} ${labels.months_short}`));
        row.appendChild(el('td', null, inmate.officer || '—'));

        const actions = el('td');
        const box = el('div', 'actions');

        if (!escaped && data.allowed.setTime) {
            box.appendChild(button(labels.set_time, 'ghost', () => openDialog(inmate)));
        }
        if (!escaped && data.allowed.release && inmate.months > 0) {
            box.appendChild(button(labels.release, 'ghost', () => act('release', { citizenid: inmate.citizenid })));
        }
        if (escaped && data.allowed.clearEscape) {
            box.appendChild(button(labels.clear_escape, 'ghost danger', () => act('clearEscape', { citizenid: inmate.citizenid })));
        }

        actions.appendChild(box);
        row.appendChild(actions);
        body.appendChild(row);
    }

    view.appendChild(list);
}

function renderHistory() {
    const view = $('history');
    view.replaceChildren();

    if (!data.history.length) {
        view.appendChild(el('div', 'empty', labels.empty_history));
        return;
    }

    const list = table([labels.col_when, labels.col_name, labels.col_action, labels.col_months, labels.col_officer]);
    const body = list.querySelector('tbody');

    for (const entry of data.history) {
        const row = el('tr');
        row.appendChild(el('td', 'mono', when(entry.at)));
        row.appendChild(el('td', 'name', entry.name));
        row.appendChild(el('td', null, labels[`action_${entry.action}`] || entry.action));
        row.appendChild(el('td', 'mono', entry.months));
        row.appendChild(el('td', null, entry.actor || '—'));
        body.appendChild(row);
    }

    view.appendChild(list);
}

function render() {
    renderInmates();
    renderHistory();
}

async function act(action, payload) {
    const result = await post('computerAction', { action, data: payload });
    if (result && result.ok && result.data) {
        data = result.data;
        render();
    }
}

function openDialog(inmate) {
    dialogAction = inmate.citizenid;
    $('dialog-title').textContent = `${labels.set_time}: ${inmate.name}`;
    $('dialog-input').value = inmate.months;
    $('dialog').classList.remove('hidden');
    $('dialog-input').focus();
}

function closeDialog() {
    dialogAction = null;
    $('dialog').classList.add('hidden');
}

function showTab(name) {
    for (const tab of document.querySelectorAll('.tab')) tab.classList.toggle('active', tab.dataset.tab === name);
    $('inmates').classList.toggle('hidden', name !== 'inmates');
    $('history').classList.toggle('hidden', name !== 'history');
}

function openComputer(message) {
    labels = message.labels || {};
    data = message.data || data;

    $('title').textContent = labels.computer_title;
    $('tab-inmates').textContent = labels.tab_inmates;
    $('tab-history').textContent = labels.tab_history;
    $('close').textContent = labels.close;
    $('dialog-cancel').textContent = labels.cancel;
    $('dialog-save').textContent = labels.save;

    showTab('inmates');
    render();
    $('computer').classList.remove('hidden');
}

function closeComputer() {
    closeDialog();
    $('computer').classList.add('hidden');
    post('computerClose');
}

for (const tab of document.querySelectorAll('.tab')) tab.addEventListener('click', () => showTab(tab.dataset.tab));
$('close').addEventListener('click', closeComputer);
$('dialog-cancel').addEventListener('click', closeDialog);
$('dialog-save').addEventListener('click', () => {
    const months = Math.floor(Number($('dialog-input').value));
    if (!dialogAction || !Number.isFinite(months) || months < 0) return;

    act('setTime', { citizenid: dialogAction, months });
    closeDialog();
});

document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || $('computer').classList.contains('hidden')) return;
    if (!$('dialog').classList.contains('hidden')) closeDialog();
    else closeComputer();
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'counter') counter(message);
    else if (message.action === 'computer') openComputer(message);
});

post('ready').then((result) => applyTheme(result && result.theme));
