// The Weather page: Los Santos now (icon, a temperature worked out from the weather and the hour, wind) and the next
// changes with how long until each. The game has no temperature, so it is a believable number, not a reading.
import { h, icon, applyContext } from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_weather';
const REFRESH_MS = 30000;

// weather -> icon, sky colors, base temperature (°C)
const KINDS = {
    EXTRASUNNY: { icon: 'sun', sky: ['#2f8ae0', '#7cc4f5'], temp: 31 },
    CLEAR: { icon: 'sun', sky: ['#3a8dde', '#86c9f3'], temp: 28 },
    NEUTRAL: { icon: 'cloud', sky: ['#5c88b5', '#9ec1df'], temp: 25 },
    SMOG: { icon: 'fog', sky: ['#a08f6e', '#d1c3a0'], temp: 27 },
    FOGGY: { icon: 'fog', sky: ['#7d8794', '#b7bec7'], temp: 19 },
    CLOUDS: { icon: 'cloud', sky: ['#5a7ea3', '#a3bcd3'], temp: 24 },
    OVERCAST: { icon: 'cloud', sky: ['#5f6b78', '#9aa5b1'], temp: 21 },
    CLEARING: { icon: 'cloud', sky: ['#4f83b8', '#a9c9e4'], temp: 22 },
    RAIN: { icon: 'rain', sky: ['#3f4f63', '#7b8a9c'], temp: 17 },
    THUNDER: { icon: 'storm', sky: ['#2c3440', '#5d6878'], temp: 16 },
    SNOW: { icon: 'snow', sky: ['#8ea4bd', '#d7e1ec'], temp: -2 },
    SNOWLIGHT: { icon: 'snow', sky: ['#97abc1', '#dfe7f0'], temp: 0 },
    BLIZZARD: { icon: 'snow', sky: ['#7a8ea5', '#c3cfdc'], temp: -6 },
    XMAS: { icon: 'snow', sky: ['#8fa7c0', '#e0e8f1'], temp: -1 },
    HALLOWEEN: { icon: 'fog', sky: ['#2b2236', '#5a4a6b'], temp: 14 },
};

const TEXTS = {
    en: {
        city: 'Los Santos', now: 'Now', in: 'in %s min', wind: 'Wind', calm: 'Calm', light: 'Light', strong: 'Strong',
        forecast: 'Coming up', lasts: 'about %s min', feels: 'Feels like %s°', unknown: 'No forecast right now',
        EXTRASUNNY: 'Sunny', CLEAR: 'Clear', NEUTRAL: 'Mild', SMOG: 'Smog', FOGGY: 'Fog', CLOUDS: 'Cloudy', OVERCAST: 'Overcast',
        CLEARING: 'Clearing up', RAIN: 'Rain', THUNDER: 'Thunderstorm', SNOW: 'Snow', SNOWLIGHT: 'Light snow', BLIZZARD: 'Blizzard',
        XMAS: 'Snow', HALLOWEEN: 'Spooky fog',
    },
    'pt-br': {
        city: 'Los Santos', now: 'Agora', in: 'em %s min', wind: 'Vento', calm: 'Calmo', light: 'Fraco', strong: 'Forte',
        forecast: 'Próximas horas', lasts: 'cerca de %s min', feels: 'Sensação de %s°', unknown: 'Sem previsão no momento',
        EXTRASUNNY: 'Ensolarado', CLEAR: 'Céu limpo', NEUTRAL: 'Ameno', SMOG: 'Poluição', FOGGY: 'Neblina', CLOUDS: 'Nublado',
        OVERCAST: 'Encoberto', CLEARING: 'Abrindo', RAIN: 'Chuva', THUNDER: 'Tempestade', SNOW: 'Neve', SNOWLIGHT: 'Neve fraca',
        BLIZZARD: 'Nevasca', XMAS: 'Neve', HALLOWEEN: 'Neblina sinistra',
    },
};

let language = 'en';
let data = null;

const t = (key, value) => ((TEXTS[language] || TEXTS.en)[key] ?? TEXTS.en[key] ?? key).replace('%s', value ?? '');
const kind = (name) => KINDS[name] || KINDS.CLEAR;
const night = (hour) => hour < 6 || hour >= 20;

function temperature(name, hour) {
    // Cooler at night, warmest in the afternoon
    const curve = night(hour) ? -6 : hour >= 12 && hour < 17 ? 2 : 0;
    return kind(name).temp + curve;
}

function windText(speed) {
    if (!speed || speed < 0.1) return t('calm');
    return speed < 0.5 ? t('light') : t('strong');
}

async function load() {
    try {
        const response = await fetch(`https://${RESOURCE}/get`, { method: 'POST', body: '{}' });
        const result = await response.json();
        if (result.ok) data = result.result;
    } catch { /* keep what we had */ }

    render();
}

function render() {
    const root = document.getElementById('content');
    const current = data?.current;

    if (!current) {
        root.replaceChildren(h('div', 'k-empty', null, icon('cloud'), h('span', '', t('unknown'))));
        return;
    }

    const hour = data.hour ?? 12;
    const now = kind(current.weather);
    const temp = temperature(current.weather, hour);
    const [top, bottom] = night(hour) ? ['#0d1b33', '#273b5c'] : now.sky;
    document.body.style.background = `linear-gradient(180deg, ${top}, ${bottom})`;

    // The forecast list starts with the weather running now; its time is what is left of it
    let minutes = 0;
    const rows = (data.forecast || []).map((entry, index) => {
        const when = index === 0 ? t('now') : t('in', minutes);
        minutes += Number(entry.time) || 0;

        return h('div', 'row', null,
            h('span', 'row__when', when),
            h('span', 'row__icon', null, icon(night(hour) && kind(entry.weather).icon === 'sun' ? 'moonIcon' : kind(entry.weather).icon)),
            h('span', 'row__name', t(entry.weather)),
            h('span', 'row__temp', `${temperature(entry.weather, hour)}°`),
        );
    });

    root.replaceChildren(
        h('div', 'hero', null,
            h('div', 'hero__city', t('city')),
            h('div', 'hero__temp', `${temp}°`),
            h('div', 'hero__name', t(current.weather)),
            h('div', 'hero__icon', null, icon(night(hour) && now.icon === 'sun' ? 'moonIcon' : now.icon)),
        ),
        h('div', 'card', null,
            h('div', 'card__label', null, icon('wind'), h('span', '', t('wind'))),
            h('div', 'card__value', windText(current.windSpeed)),
            h('div', 'card__sub', t('feels', temp + (current.isRain ? -2 : 0))),
        ),
        h('div', 'card', null,
            h('div', 'card__label', null, icon('clock'), h('span', '', t('forecast'))),
            rows.length ? h('div', 'rows', null, rows) : h('div', 'card__sub', t('unknown')),
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

setInterval(load, REFRESH_MS);
load();
