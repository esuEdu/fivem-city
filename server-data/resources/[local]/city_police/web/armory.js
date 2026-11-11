// The station armory: the Armory tab takes gear, the Unlocks tab (padlock) unlocks the tiers rank by rank, like a tech
// tree. Uses $, post, node and applyTheme from screen.js. Game data goes in with textContent only.

const SVG_NS = 'http://www.w3.org/2000/svg';
const IMAGE_URL = 'https://cfx-nui-city_inventory/web/images/%s.png';
const PADLOCK = 'M7 10V7a5 5 0 0 1 10 0v3h1a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1h1zm2 0h6V7a3 3 0 0 0-6 0v3z';
const PADLOCK_OPEN = 'M7 10V7a5 5 0 0 1 9.6-2l-1.8.9A3 3 0 0 0 9 7v3h9a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1h1z';
const CHECK = 'M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z';

let armoryTab = 'stock';
let armoryData = null;
let armoryLabels = {};

function svgEl(tag, attrs) {
    const element = document.createElementNS(SVG_NS, tag);
    for (const [key, value] of Object.entries(attrs)) element.setAttribute(key, String(value));
    return element;
}

function pathIcon(d, size = 16) {
    const svg = svgEl('svg', { viewBox: '0 0 24 24', width: size, height: size, class: 'armory-icon' });
    svg.append(svgEl('path', { d }));
    return svg;
}

function star(cx, cy, r) {
    const points = [];
    for (let i = 0; i < 10; i += 1) {
        const radius = i % 2 === 0 ? r : r * 0.45;
        const angle = (Math.PI / 5) * i - Math.PI / 2;
        points.push(`${(cx + radius * Math.cos(angle)).toFixed(2)},${(cy + radius * Math.sin(angle)).toFixed(2)}`);
    }
    return svgEl('polygon', { points: points.join(' '), class: 'ins-star' });
}

// The rank insignia of the military police (0 Recruta ... 13 Coronel): chevrons, arcs, a triangle or stars
function insignia(grade, size = 34) {
    const svg = svgEl('svg', { viewBox: '0 0 40 40', width: size, height: size, class: 'insignia' });
    const chevron = (y) => svg.append(svgEl('path', { d: `M8 ${y + 7} L20 ${y} L32 ${y + 7}`, class: 'ins-line' }));
    const arc = (y) => svg.append(svgEl('path', { d: `M9 ${y} Q20 ${y + 6} 31 ${y}`, class: 'ins-line' }));
    const stars = (count, r, y = 20) => {
        const gap = r * 2.3;
        const start = 20 - (gap * (count - 1)) / 2;
        for (let i = 0; i < count; i += 1) svg.append(star(start + gap * i, y, r));
    };
    const bar = (y) => svg.append(svgEl('rect', { x: 8, y, width: 24, height: 3, rx: 1.5, class: 'ins-fill' }));

    if (grade <= 0) svg.append(svgEl('circle', { cx: 20, cy: 20, r: 7, class: 'ins-line' }));
    else if (grade <= 3) for (let i = 0; i < grade; i += 1) chevron(9 + i * 7);
    else if (grade <= 5) {
        for (let i = 0; i < 3; i += 1) chevron(5 + i * 6);
        for (let i = 0; i < grade - 3; i += 1) arc(27 + i * 5);
    } else if (grade === 6) svg.append(svgEl('path', { d: 'M20 9 L31 30 L9 30 Z', class: 'ins-line' }));
    else if (grade === 7) stars(1, 6);
    else if (grade === 8) stars(1, 9);
    else if (grade === 9) stars(2, 7);
    else if (grade === 10) stars(3, 5.5);
    else if (grade === 11) { stars(3, 5, 16); bar(27); }
    else if (grade === 12) { stars(3, 5, 13); bar(23); bar(29); }
    else stars(3, 6.5);

    return svg;
}

function itemImage(name) {
    const image = node('img', 'armory-img');
    image.alt = '';
    image.src = IMAGE_URL.replace('%s', encodeURIComponent(name));
    image.addEventListener('error', () => image.classList.add('missing'));
    return image;
}

function format(text, ...values) {
    let index = 0;
    return String(text || '').replace(/%s/g, () => String(values[index++] ?? ''));
}

function drawTabs() {
    const labels = armoryLabels;
    const stock = node('button', `armory-tab${armoryTab === 'stock' ? ' on' : ''}`, labels.stock);
    stock.type = 'button';
    stock.addEventListener('click', () => { armoryTab = 'stock'; drawArmory(); });

    const unlocks = node('button', `armory-tab lock${armoryTab === 'unlocks' ? ' on' : ''}`);
    unlocks.type = 'button';
    unlocks.title = labels.unlocks || '';
    unlocks.setAttribute('aria-label', labels.unlocks || '');
    unlocks.append(pathIcon(PADLOCK, 15), node('span', null, labels.unlocks));
    const next = armoryData.unlocked + 1;
    if (next <= Math.min(armoryData.grade, armoryData.lastTier)) unlocks.append(node('i', 'armory-dot'));
    unlocks.addEventListener('click', () => { armoryTab = 'unlocks'; drawArmory(); });

    $('armory-tabs').replaceChildren(stock, unlocks);
}

function drawRank() {
    const box = $('armory-rank');
    const text = node('div');
    text.append(node('small', null, armoryLabels.rank), node('strong', null, armoryData.rank));
    box.replaceChildren(insignia(armoryData.grade, 30), text);
}

function drawStock() {
    const labels = armoryLabels;
    const groups = { weapon: [], ammo: [], gear: [] };

    for (const item of armoryData.stock) (groups[item.kind] || groups.gear).push(item);

    if (!armoryData.stock.length) return [node('p', 'armory-empty', labels.empty)];

    const sections = [];

    for (const kind of ['weapon', 'ammo', 'gear']) {
        if (!groups[kind].length) continue;

        const grid = node('div', 'armory-grid');

        for (const item of groups[kind]) {
            const full = item.have >= item.max;
            const card = node('div', `armory-card${full ? ' full' : ''}`);
            const take = node('button', 'armory-btn accent', item.count > 1 ? `${labels.take} ×${item.count}` : labels.take);
            take.type = 'button';
            take.disabled = full;
            take.addEventListener('click', () => post('armoryTake', { name: item.name }));
            card.append(itemImage(item.name), node('strong', null, item.label), node('small', null, format(labels.carry, item.have, item.max)), take);
            grid.append(card);
        }

        sections.push(node('h3', 'armory-section', labels[kind]), grid);
    }

    return sections;
}

function rowState(tier) {
    const { unlocked, grade } = armoryData;
    if (tier <= unlocked) return 'unlocked';
    if (tier > grade) return 'rank';
    if (tier === unlocked + 1) return 'next';
    return 'previous';
}

function drawUnlocks() {
    const labels = armoryLabels;
    const rows = [];

    for (const row of armoryData.tree) {
        const state = rowState(row.tier);
        const line = node('div', `armory-row ${state}`);

        const nodeBox = node('div', 'armory-node');
        const diamond = node('div', 'armory-diamond');
        diamond.append(insignia(row.tier, 30));
        nodeBox.append(diamond, node('span', 'armory-node-name', row.rank));

        const items = node('div', 'armory-items');
        for (const item of row.items) {
            const card = node('div', 'armory-mini');
            card.title = item.label;
            card.append(itemImage(item.name), node('span', null, item.label));
            items.append(card);
        }
        if (row.tier === armoryData.lastTier) {
            const all = node('div', 'armory-mini all');
            all.append(node('strong', null, '∞'), node('span', null, labels.allWeapons));
            items.prepend(all);
        }

        const side = node('div', 'armory-state');

        if (state === 'unlocked') {
            side.append(pathIcon(CHECK, 18), node('span', null, labels.unlocked));
        } else if (state === 'next') {
            const unlock = node('button', 'armory-btn accent');
            unlock.type = 'button';
            unlock.append(pathIcon(PADLOCK_OPEN, 15), node('span', null, labels.unlock));
            unlock.addEventListener('click', () => post('armoryUnlock', { tier: row.tier }));
            side.append(unlock);
        } else {
            side.append(pathIcon(PADLOCK, 18), node('span', null, state === 'rank' ? format(labels.requires, row.rank) : labels.previous));
        }

        line.append(nodeBox, items, side);
        rows.push(line);
    }

    const tree = node('div', 'armory-tree');
    tree.append(...rows);
    return [tree];
}

function drawArmory() {
    if (!armoryData) return;

    drawTabs();
    drawRank();
    $('armory-body').replaceChildren(...(armoryTab === 'stock' ? drawStock() : drawUnlocks()));
}

function showArmory(message) {
    armoryLabels = message.labels || {};
    armoryData = message.data;
    armoryTab = armoryData.stock.length ? 'stock' : 'unlocks';
    applyTheme(message.theme);

    $('armory-title').textContent = armoryLabels.title || '';
    $('armory-subtitle').textContent = armoryLabels.subtitle || '';
    drawArmory();
    $('armory').classList.remove('hidden');
}

$('armory-close').addEventListener('click', () => post('armoryClose'));

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !$('armory').classList.contains('hidden')) post('armoryClose');
});

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message.action !== 'string') return;

    if (message.action === 'armory') showArmory(message);
    else if (message.action === 'armoryData' && message.data) {
        armoryData = message.data;
        drawArmory();
    } else if (message.action === 'armoryOff') $('armory').classList.add('hidden');
});
