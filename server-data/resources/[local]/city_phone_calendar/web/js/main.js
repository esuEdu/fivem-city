// The Calendar page: the real month, swipe through months with the arrows, today in red, the chosen day below
import { h, button, icon, navBar, applyContext } from 'https://cfx-nui-city_phone/web/kit/kit.js';

const TEXTS = {
    en: { today: 'Today', week: 'Week %s', day: 'Day %s of the year' },
    'pt-br': { today: 'Hoje', week: 'Semana %s', day: 'Dia %s do ano' },
};

let language = 'en';
let shown = new Date();
let picked = new Date();

const locale = () => (language === 'pt-br' ? 'pt-BR' : 'en-US');
const t = (key, value) => ((TEXTS[language] || TEXTS.en)[key] || key).replace('%s', value ?? '');
const same = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

function weekdays() {
    // Sunday first, short names in the phone's language
    return [...Array(7)].map((_, i) => new Date(2023, 0, 1 + i).toLocaleDateString(locale(), { weekday: 'narrow' }));
}

function weekOfYear(date) {
    const start = new Date(date.getFullYear(), 0, 1);
    return Math.ceil(((date - start) / 86400000 + start.getDay() + 1) / 7);
}

function dayOfYear(date) {
    return Math.floor((date - new Date(date.getFullYear(), 0, 0)) / 86400000);
}

function render() {
    const year = shown.getFullYear();
    const month = shown.getMonth();
    const first = new Date(year, month, 1).getDay();
    const days = new Date(year, month + 1, 0).getDate();
    const today = new Date();

    const cells = [];
    for (let i = 0; i < first; i++) cells.push(h('span', 'day day--empty'));
    for (let d = 1; d <= days; d++) {
        const date = new Date(year, month, d);
        const classes = ['day'];
        if (same(date, today)) classes.push('day--today');
        if (same(date, picked)) classes.push('day--picked');
        if (date.getDay() === 0 || date.getDay() === 6) classes.push('day--weekend');
        cells.push(button(classes.join(' '), String(d), () => { picked = date; render(); }));
    }

    const title = shown.toLocaleDateString(locale(), { month: 'long', year: 'numeric' });

    document.getElementById('content').replaceChildren(
        navBar(
            button('k-link cal-link', t('today'), () => { shown = new Date(); picked = new Date(); render(); }),
            null,
            h('span', 'arrows', null,
                button('k-link cal-link', null, () => { shown = new Date(year, month - 1, 1); render(); }, icon('back')),
                button('k-link cal-link', null, () => { shown = new Date(year, month + 1, 1); render(); }, icon('chevron')),
            ),
        ),
        h('h1', 'k-large-title month', title),
        h('div', 'weekdays', null, weekdays().map((name) => h('span', '', name))),
        h('div', 'days', null, cells),
        h('div', 'picked', null,
            h('div', 'picked__date', picked.toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })),
            h('div', 'picked__info', `${t('week', weekOfYear(picked))} · ${t('day', dayOfYear(picked))}`),
        ),
    );
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.type !== 'city_phone:context') return;

    applyContext(message);
    language = message.language === 'pt-br' ? 'pt-br' : 'en';
    render();
});

// Past midnight the "today" mark moves
setInterval(render, 60000);
render();
