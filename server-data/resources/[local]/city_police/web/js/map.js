import { el, L, run, icon, heading, toast } from './ui.js';
import { app } from './main.js';

const SVG = 'http://www.w3.org/2000/svg';

// A rough outline of San Andreas in world coordinates (x, y), drawn instead of the game's map picture
const COAST = [
    [-1900, -3450], [-650, -3700], [900, -3500], [1400, -2900], [1500, -2300], [2250, -1650], [2800, -900], [3000, 0],
    [3500, 1500], [3800, 3200], [3700, 4600], [3300, 5600], [2600, 6400], [1600, 6800], [600, 7300], [-100, 7100],
    [-700, 6500], [-1500, 5800], [-2300, 4800], [-2900, 3800], [-3200, 2600], [-3450, 1200], [-3200, 200], [-2400, -400],
    [-2050, -1100], [-1700, -1900], [-1850, -2700],
];
const AREAS = [
    ['Los Santos', 100, -900], ['Vinewood', 300, 500], ['LSIA', -1100, -2800], ['Sandy Shores', 1900, 3600],
    ['Grapeseed', 2100, 4900], ['Paleto Bay', -250, 6350], ['Chumash', -3000, 1100], ['Zancudo', -2300, 3100],
    ['Mount Chiliad', 500, 5600], ['Palomino', 2500, -300],
];
const MIN_X = -4000;
const MAX_Y = 8000;
const WIDTH = 8500;
const HEIGHT = 12000;

function svg(tag, attrs = {}, ...children) {
    const node = document.createElementNS(SVG, tag);
    for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
    for (const child of children) if (child) node.append(child);
    return node;
}

function waypoint(x, y, label) {
    window.CityOS.send('waypoint', { x, y });
    toast(L('ui_gps_set_to', label));
}

function marker(kind, x, y, label, title) {
    const group = svg('g', { class: `marker ${kind}`, transform: `translate(${x} ${-y})` });
    group.append(svg('circle', { r: kind === 'call' ? 110 : 90 }));

    if (label) {
        const text = svg('text', { y: -150, 'text-anchor': 'middle' });
        text.textContent = label;
        group.append(text);
    }

    const tip = svg('title');
    tip.textContent = title;
    group.append(tip);
    group.addEventListener('click', () => waypoint(x, y, title));

    return group;
}

export async function renderMap() {
    const response = await run('map');
    const data = response ? response.data : { units: [], calls: [], anklets: [] };

    const coast = svg('polygon', { class: 'land', points: COAST.map(([x, y]) => `${x},${-y}`).join(' ') });
    const sea = svg('ellipse', { class: 'lake', cx: 1100, cy: -4050, rx: 900, ry: 320, transform: 'rotate(-12 1100 -4050)' });

    const labels = AREAS.map(([name, x, y]) => {
        const text = svg('text', { x, y: -y, class: 'area', 'text-anchor': 'middle' });
        text.textContent = name;
        return text;
    });

    const map = svg('svg', { class: 'world', viewBox: `${MIN_X} ${-MAX_Y} ${WIDTH} ${HEIGHT}`, preserveAspectRatio: 'xMidYMid meet' },
        coast, sea, ...labels,
        ...data.anklets.map((entry) => marker('anklet', entry.x, entry.y, null, `${L('ui_anklet')}: ${entry.name}`)),
        ...data.calls.map((call) => marker(`call${call.priority === 2 ? ' urgent' : ''}`, call.x, call.y, call.code, `${call.code} · ${call.title}`)),
        ...data.units.map((unit) => marker(`unit ${unit.id === app.me.id ? 'me' : ''}`, unit.x, unit.y, unit.callsign || '', unit.callsign ? `${unit.callsign} · ${unit.name}` : unit.name)),
    );

    const legend = el('div', { class: 'legend-row' },
        el('span', { class: 'legend' }, el('i', { class: 'unit' }), L('ui_units_count', data.units.length)),
        el('span', { class: 'legend' }, el('i', { class: 'call' }), L('ui_calls_count', data.calls.length)),
        el('span', { class: 'legend' }, el('i', { class: 'anklet' }), L('ui_anklets_count', data.anklets.length)),
    );

    return el('div', { class: 'stack map-page' },
        heading(L('ui_tab_map'), el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn', onclick: () => window.CityOS.send('openMap') }, icon('map', 16), ' ', L('ui_open_game_map'))),
        legend,
        el('div', { class: 'card map-card' }, map),
        el('p', { class: 'muted small', text: L('ui_map_hint') }),
    );
}
