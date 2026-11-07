// The Maps page: a button that opens the game map, and the route set on it (street, area, distance)
import { h, button, icon, toast, navBar, applyContext } from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_gps';
const dictionaries = {};
let language = 'en';
let route = null;

async function call(name, data = {}) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, { method: 'POST', body: JSON.stringify(data) });
        return await response.json();
    } catch {
        return null;
    }
}

function t(key, ...values) {
    const text = dictionaries[language]?.[key] ?? dictionaries.en?.[key] ?? key;
    let index = 0;
    return text.replace(/%s/g, () => String(values[index++] ?? ''));
}

function distance(meters) {
    return meters >= 1000 ? `${(meters / 1000).toFixed(1)} km` : `${meters} m`;
}

function render() {
    const routeRows = route
        ? [
            h('div', 'k-row', null,
                h('span', 'route', null, h('span', 'route__street', route.street || route.zone), h('span', 'route__zone', route.street ? route.zone : '')),
                h('span', 'k-row__value', t('distance', distance(route.distance))),
            ),
            button('k-row k-row--danger', t('clear'), async () => {
                await call('clear');
                toast(t('cleared'));
                refresh();
            }),
        ]
        : [h('div', 'k-row', null, h('span', 'k-row__value', t('noRoute')))];

    document.getElementById('content').replaceChildren(
        navBar(null, null, null),
        h('h1', 'k-large-title', t('title')),
        h('div', 'hero', null,
            h('div', 'hero__map', null, icon('pin')),
            button('k-button hero__open', t('open'), () => call('open')),
            h('p', 'hero__hint', t('hint')),
        ),
        h('p', 'k-group__label', t('route')),
        h('div', 'k-group', null, routeRows),
    );
}

async function refresh() {
    const result = await call('status');
    route = result && result.street !== undefined ? result : null;
    render();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        language = message.language === 'pt-br' ? 'pt-br' : 'en';
        refresh();
    }

    if (message.type === 'city_phone:message' && message.data?.action === 'refresh') refresh();
});

async function start() {
    for (const lang of ['en', 'pt-br']) {
        dictionaries[lang] = await fetch(`locales/${lang}.json`).then((r) => r.json()).catch(() => ({}));
    }
    await refresh();
}

start();
