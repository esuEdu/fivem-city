// The Clock page: world clock (real time zones), alarms (saved on the server, rung by our client), stopwatch (here,
// in the page) and timer (run by our client so it rings with the phone closed)
import {
    h, button, icon, input, toast, navBar, openSheet, closeSheet, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_clock';
const STORAGE = 'city_phone_clock:cities';
const ZONES = [
    ['Los Santos', 'America/Los_Angeles'], ['São Paulo', 'America/Sao_Paulo'], ['New York', 'America/New_York'],
    ['Lisboa', 'Europe/Lisbon'], ['London', 'Europe/London'], ['Paris', 'Europe/Paris'], ['Dubai', 'Asia/Dubai'],
    ['Tokyo', 'Asia/Tokyo'], ['Sydney', 'Australia/Sydney'], ['Mexico City', 'America/Mexico_City'],
    ['Buenos Aires', 'America/Argentina/Buenos_Aires'], ['Moscow', 'Europe/Moscow'],
];
const TEXTS = {
    en: {
        world: 'World Clock', alarms: 'Alarms', stopwatch: 'Stopwatch', timer: 'Timer', edit: 'Edit', done: 'Done', add: 'Add',
        cancel: 'Cancel', save: 'Save', newAlarm: 'Add Alarm', label: 'Label', repeat: 'Every day', noAlarms: 'No alarms',
        start: 'Start', stop: 'Stop', reset: 'Reset', lap: 'Lap', resume: 'Resume', pause: 'Cancel', full: 'Too many alarms',
        today: 'Today', hours: 'h', minutes: 'min', seconds: 's', addCity: 'Add City', once: 'Once', daily: 'Every day',
        local: 'Your time', remove: 'Remove',
    },
    'pt-br': {
        world: 'Relógio Mundial', alarms: 'Alarmes', stopwatch: 'Cronômetro', timer: 'Timer', edit: 'Editar', done: 'OK', add: 'Adicionar',
        cancel: 'Cancelar', save: 'Salvar', newAlarm: 'Novo Alarme', label: 'Nome', repeat: 'Todo dia', noAlarms: 'Nenhum alarme',
        start: 'Iniciar', stop: 'Parar', reset: 'Zerar', lap: 'Volta', resume: 'Continuar', pause: 'Cancelar', full: 'Alarmes demais',
        today: 'Hoje', hours: 'h', minutes: 'min', seconds: 's', addCity: 'Adicionar Cidade', once: 'Uma vez', daily: 'Todo dia',
        local: 'Sua hora', remove: 'Remover',
    },
};

const state = {
    tab: 'world', language: 'en', alarms: [], timer: null, editing: false,
    cities: load(), watch: { running: false, start: 0, elapsed: 0, laps: [] },
};

function load() {
    try { return JSON.parse(localStorage.getItem(STORAGE)) || ['America/Los_Angeles', 'America/Sao_Paulo', 'Europe/Lisbon', 'Asia/Tokyo']; } catch { return ['America/Los_Angeles']; }
}

function saveCities() {
    try { localStorage.setItem(STORAGE, JSON.stringify(state.cities)); } catch { /* no storage: the list just isn't kept */ }
}

const t = (key) => (TEXTS[state.language] || TEXTS.en)[key] ?? TEXTS.en[key] ?? key;
const locale = () => (state.language === 'pt-br' ? 'pt-BR' : 'en-US');
const pad = (n) => String(n).padStart(2, '0');

async function call(name, data = {}) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, { method: 'POST', body: JSON.stringify(data) });
        return await response.json();
    } catch {
        return { ok: false };
    }
}

function zoneTime(zone) {
    return new Date().toLocaleTimeString(locale(), { timeZone: zone, hour: '2-digit', minute: '2-digit' });
}

function zoneOffset(zone) {
    const here = new Date();
    const there = new Date(here.toLocaleString('en-US', { timeZone: zone }));
    const hours = Math.round((there - here) / 3600000);
    return `${t('today')}, ${hours >= 0 ? '+' : ''}${hours}${t('hours')}`;
}

function world() {
    const names = Object.fromEntries(ZONES.map(([name, zone]) => [zone, name]));

    const rows = state.cities.map((zone) => h('div', 'k-row city', null,
        h('span', 'city__name', null, h('small', '', zoneOffset(zone)), h('strong', '', names[zone] || zone)),
        state.editing
            ? button('k-link k-link--danger', t('remove'), () => { state.cities = state.cities.filter((z) => z !== zone); saveCities(); render(); })
            : h('span', 'city__time', zoneTime(zone)),
    ));

    const add = () => openSheet(
        navBar(button('k-link', t('cancel'), closeSheet), t('addCity'), null),
        h('div', 'k-group', null, ZONES.filter(([, zone]) => !state.cities.includes(zone)).map(([name, zone]) => button('k-row', name, () => {
            state.cities.push(zone);
            saveCities();
            closeSheet();
            render();
        }))),
    );

    return [
        navBar(button('k-link', state.editing ? t('done') : t('edit'), () => { state.editing = !state.editing; render(); }), null, button('k-link', null, add, icon('plus'))),
        h('h1', 'k-large-title', t('world')),
        h('div', 'k-list', null, rows),
    ];
}

function alarmSheet(alarm = { hour: 7, minute: 0, label: '', repeats: false, enabled: true }) {
    const hour = h('select', 'wheel');
    const minute = h('select', 'wheel');
    for (let i = 0; i < 24; i++) hour.append(new Option(pad(i), i, false, i === alarm.hour));
    for (let i = 0; i < 60; i++) minute.append(new Option(pad(i), i, false, i === alarm.minute));

    const label = input('k-field', t('label'), 30);
    label.value = alarm.label || '';

    let repeats = alarm.repeats;
    const repeatRow = button('k-row', null, () => { repeats = !repeats; repeatValue.textContent = repeats ? t('daily') : t('once'); }, h('span', '', t('repeat')));
    const repeatValue = h('span', 'k-row__value', repeats ? t('daily') : t('once'));
    repeatRow.append(repeatValue);

    const save = async () => {
        const result = await call('saveAlarm', { alarm: { id: alarm.id, hour: Number(hour.value), minute: Number(minute.value), label: label.value, repeats, enabled: true } });
        if (!result.ok) return toast(t(result.reason === 'full' ? 'full' : 'cancel'));
        state.alarms = result.result;
        closeSheet();
        render();
    };

    openSheet(
        navBar(button('k-link', t('cancel'), closeSheet), t('newAlarm'), button('k-link', t('save'), save)),
        h('div', 'wheels', null, hour, h('span', 'wheels__colon', ':'), minute),
        h('div', 'k-group', null, label, repeatRow),
        alarm.id ? h('div', 'k-group', null, button('k-row k-row--danger', t('remove'), async () => {
            const result = await call('deleteAlarm', { id: alarm.id });
            if (result.ok) state.alarms = result.result;
            closeSheet();
            render();
        })) : null,
    );
}

function alarmsTab() {
    const list = [...state.alarms].sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));

    return [
        navBar(null, null, button('k-link', null, () => alarmSheet(), icon('plus'))),
        h('h1', 'k-large-title', t('alarms')),
        list.length === 0 ? h('div', 'k-empty', null, icon('bell'), h('span', '', t('noAlarms'))) : h('div', 'k-list', null, list.map((alarm) => {
            const toggle = h('span', `switch${alarm.enabled ? ' switch--on' : ''}`);
            toggle.addEventListener('click', async (event) => {
                event.stopPropagation();
                const result = await call('saveAlarm', { alarm: { ...alarm, enabled: !alarm.enabled } });
                if (result.ok) state.alarms = result.result;
                render();
            });

            return button(`k-row alarm${alarm.enabled ? '' : ' alarm--off'}`, null, () => alarmSheet(alarm),
                h('span', 'alarm__main', null, h('span', 'alarm__time', `${pad(alarm.hour)}:${pad(alarm.minute)}`), h('span', 'alarm__label', [alarm.label, alarm.repeats ? t('daily') : t('once')].filter(Boolean).join(' · '))),
                toggle,
            );
        })),
    ];
}

function watchText(ms) {
    const total = Math.floor(ms / 10);
    return `${pad(Math.floor(total / 6000))}:${pad(Math.floor(total / 100) % 60)},${pad(total % 100)}`;
}

function watchElapsed() {
    const w = state.watch;
    return w.elapsed + (w.running ? Date.now() - w.start : 0);
}

function stopwatch() {
    const w = state.watch;

    const left = w.running
        ? button('round round--gray', t('lap'), () => { w.laps.unshift(watchElapsed()); render(); })
        : button('round round--gray', t('reset'), () => { w.elapsed = 0; w.laps = []; render(); });
    const right = w.running
        ? button('round round--red', t('stop'), () => { w.elapsed = watchElapsed(); w.running = false; render(); })
        : button('round round--green', t('start'), () => { w.start = Date.now(); w.running = true; render(); });

    return [
        h('div', 'big-time', watchText(watchElapsed())),
        h('div', 'round-row', null, left, right),
        h('div', 'k-list laps', null, w.laps.map((lap, i) => h('div', 'k-row', null, h('span', '', `${t('lap')} ${w.laps.length - i}`), h('span', 'mono', watchText(lap))))),
    ];
}

function timerTab() {
    const running = state.timer && state.timer.left > 0;

    if (running) {
        const left = state.timer.left;
        return [
            h('div', 'big-time', `${pad(Math.floor(left / 3600))}:${pad(Math.floor(left / 60) % 60)}:${pad(left % 60)}`),
            h('div', 'round-row', null,
                button('round round--gray', t('pause'), async () => { await call('stopTimer'); state.timer = null; render(); }),
                h('span'),
            ),
        ];
    }

    const make = (max, unit) => {
        const select = h('select', 'wheel');
        for (let i = 0; i <= max; i++) select.append(new Option(`${i} ${t(unit)}`, i, false, unit === 'minutes' && i === 5));
        return select;
    };
    const hours = make(23, 'hours');
    const minutes = make(59, 'minutes');
    const seconds = make(59, 'seconds');

    return [
        h('div', 'wheels wheels--timer', null, hours, minutes, seconds),
        h('div', 'round-row', null,
            button('round round--gray', t('stop'), () => call('stopRinging')),
            button('round round--green', t('start'), async () => {
                const total = Number(hours.value) * 3600 + Number(minutes.value) * 60 + Number(seconds.value);
                if (total < 1) return;
                if ((await call('startTimer', { seconds: total })).ok) state.timer = { left: total, total };
                render();
            }),
        ),
    ];
}

const TABS = [['world', 'globe', world], ['alarms', 'bell', alarmsTab], ['stopwatch', 'stopwatch', stopwatch], ['timer', 'timer', timerTab]];

function render() {
    const view = TABS.find(([id]) => id === state.tab)[2];
    document.getElementById('content').replaceChildren(...view().flat().filter(Boolean));
    document.getElementById('tabbar').replaceChildren(...TABS.map(([id, iconName]) => button(`k-tab${state.tab === id ? ' k-tab--on' : ''}`, null, () => {
        state.tab = id;
        state.editing = false;
        render();
    }, icon(iconName), h('span', '', t(id)))));
}

// Clocks, the stopwatch and the timer tick; only the time texts are redrawn, so taps aren't lost
setInterval(() => {
    if (state.timer && state.timer.left > 0) state.timer.left -= 1;

    if (state.tab === 'world' && !state.editing) {
        document.querySelectorAll('.city__time').forEach((node, i) => { node.textContent = zoneTime(state.cities[i]); });
    }
    if (state.tab === 'timer' && state.timer) {
        const left = Math.max(0, state.timer.left);
        const big = document.querySelector('.big-time');
        if (big) big.textContent = `${pad(Math.floor(left / 3600))}:${pad(Math.floor(left / 60) % 60)}:${pad(left % 60)}`;
        if (left === 0) { state.timer = null; render(); }
    }
}, 1000);

setInterval(() => {
    if (state.tab !== 'stopwatch' || !state.watch.running) return;
    const big = document.querySelector('.big-time');
    if (big) big.textContent = watchText(watchElapsed());
}, 50);

async function refresh() {
    const result = await call('state');
    if (result.ok) {
        state.alarms = result.result.alarms || [];
        state.timer = result.result.timer || null;
    }
    render();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        state.language = message.language === 'pt-br' ? 'pt-br' : 'en';
        render();
    }

    if (message.type === 'city_phone:message' && message.data?.action === 'timer') {
        state.timer = null;
        render();
    }
});

refresh();
