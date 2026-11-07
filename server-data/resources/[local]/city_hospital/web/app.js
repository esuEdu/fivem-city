const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_hospital';
const $ = (id) => document.getElementById(id);

let labels = {};
let remaining = 0;
let ticker = null;

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

// Lua-style '%s' / '%d' placeholders, filled in order
function format(text, ...values) {
    let index = 0;
    return (text || '').replace(/%[sd]/g, () => String(values[index++] ?? ''));
}

function toggle(node, visible) {
    node.classList.toggle('hidden', !visible);
}

function clock(seconds) {
    const minutes = Math.floor(seconds / 60);
    return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}

function renderTimer() {
    $('timer-value').textContent = clock(remaining);
    toggle($('timer'), remaining > 0);
}

// The server's remaining time arrives every couple of seconds; count down smoothly in between
function startTicker() {
    if (ticker) return;
    ticker = setInterval(() => {
        if (remaining > 0) remaining -= 1;
        renderTimer();
    }, 1000);
}

function stopTicker() {
    clearInterval(ticker);
    ticker = null;
}

function render(data) {
    const panel = $('downed');

    if (!data) {
        toggle(panel, false);
        stopTicker();
        return;
    }

    if (!data.down) return;

    const gone = data.finalized === true;

    panel.classList.toggle('downed--gone', gone);
    $('title').textContent = gone ? labels.ui_finalized : labels.ui_unconscious;
    $('hint').textContent = labels.ui_finalized_hint;
    toggle($('hint'), gone);

    $('ems-label').textContent = labels.ui_ems_on_duty;
    $('ems-count').textContent = String(data.ems ?? 0);

    const coming = $('coming');
    let comingText = labels.ui_no_ems_coming;
    if (data.sos && data.sos.accepted) comingText = format(labels.ui_ems_coming, data.sos.accepted);
    else if (data.npcComing) comingText = labels.ui_npc_coming;
    coming.textContent = comingText;
    coming.classList.toggle('stat__text--on', comingText !== labels.ui_no_ems_coming);

    remaining = Math.max(0, Number(data.remaining) || 0);
    $('timer-label').textContent = labels.ui_wait;
    renderTimer();

    const respawn = $('key-respawn');
    respawn.textContent = format(labels.ui_respawn, data.prices?.respawn ?? 0);
    toggle(respawn, remaining === 0);

    const sos = $('key-sos');
    sos.textContent = data.sos ? labels.ui_sos_sent : labels.ui_sos;
    sos.classList.toggle('key--done', Boolean(data.sos));
    toggle(sos, !gone);

    const pray = $('key-pray');
    pray.textContent = format(labels.ui_pray, data.prices?.prayer ?? 0);
    toggle(pray, data.canPray === true && !data.npcComing);

    toggle(panel, true);
    startTicker();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'downed') render(message.data);
});

fetch(`https://${resource}/ready`, { method: 'POST', body: '{}' })
    .then((response) => response.json())
    .then((setup) => {
        applyTheme(setup.theme);
        labels = setup.labels || {};
    })
    .catch(() => null);
