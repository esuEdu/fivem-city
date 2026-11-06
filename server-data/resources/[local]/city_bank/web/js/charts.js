import { h, svg, label, money, moneyShort } from './util.js';

// Small SVG charts for the dashboard (no chart library: NUI pages stay light)
const W = 520;
const H = 170;
const PAD = { top: 12, right: 8, bottom: 22, left: 44 };

// Fills in the days with no movement so the axis always shows the last `count` days
export function lastDays(rows, count = 7) {
    const byDay = new Map((rows || []).map((row) => [row.day, row]));
    const days = [];

    for (let i = count - 1; i >= 0; i -= 1) {
        const date = new Date();
        date.setHours(0, 0, 0, 0);
        date.setDate(date.getDate() - i);

        const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        const row = byDay.get(key);

        days.push({
            key,
            short: date.toLocaleDateString('en-US', { weekday: 'short' }),
            income: row ? Number(row.income) : 0,
            expenses: row ? Number(row.expenses) : 0,
            close: row ? Number(row.close) : null,
        });
    }

    return days;
}

function axis(max) {
    const lines = [];
    const plotH = H - PAD.top - PAD.bottom;

    for (let i = 0; i <= 3; i += 1) {
        const y = PAD.top + plotH - (plotH * i) / 3;
        lines.push(svg('line', { x1: PAD.left, x2: W - PAD.right, y1: y, y2: y, class: 'chart__grid' }));
        lines.push(svg('text', { x: PAD.left - 6, y: y + 3, class: 'chart__axis', 'text-anchor': 'end' }, document.createTextNode(moneyShort((max * i) / 3))));
    }

    return lines;
}

function legend(items) {
    return h('div', { className: 'chart__legend' }, items.map((item) => h('span', { className: 'chart__key' },
        h('i', { className: `chart__swatch chart__swatch--${item.kind}` }), item.text)));
}

// Income vs expenses per day, side by side bars
export function cashFlow(days) {
    const max = Math.max(1, ...days.map((d) => Math.max(d.income, d.expenses)));
    const plotW = W - PAD.left - PAD.right;
    const plotH = H - PAD.top - PAD.bottom;
    const slot = plotW / days.length;
    const bar = Math.min(16, slot / 3);
    const nodes = [...axis(max)];

    days.forEach((day, i) => {
        const x = PAD.left + slot * i + slot / 2;
        const inH = (day.income / max) * plotH;
        const outH = (day.expenses / max) * plotH;

        nodes.push(svg('rect', { x: x - bar - 1, y: PAD.top + plotH - inH, width: bar, height: Math.max(inH, 0), rx: 2, class: 'chart__bar chart__bar--in' },
            svg('title', {}, document.createTextNode(`${day.short}: +${money(day.income)}`))));
        nodes.push(svg('rect', { x: x + 1, y: PAD.top + plotH - outH, width: bar, height: Math.max(outH, 0), rx: 2, class: 'chart__bar chart__bar--out' },
            svg('title', {}, document.createTextNode(`${day.short}: -${money(day.expenses)}`))));
        nodes.push(svg('text', { x, y: H - 6, class: 'chart__axis', 'text-anchor': 'middle' }, document.createTextNode(day.short)));
    });

    return h('div', { className: 'chart' },
        svg('svg', { viewBox: `0 0 ${W} ${H}`, class: 'chart__svg' }, nodes),
        legend([{ kind: 'in', text: label('income_short') }, { kind: 'out', text: label('expenses_short') }]));
}

// Closing balance per day; days without movement keep the previous balance
export function balanceLine(days, current) {
    let last = null;
    const points = days.map((d) => (last = d.close ?? last));
    const firstKnown = points.find((p) => p !== null);
    const values = points.map((p) => (p === null ? (firstKnown ?? current) : p));

    values[values.length - 1] = current;

    const max = Math.max(1, ...values);
    const plotW = W - PAD.left - PAD.right;
    const plotH = H - PAD.top - PAD.bottom;
    const step = plotW / Math.max(1, values.length - 1);
    const coords = values.map((v, i) => [PAD.left + step * i, PAD.top + plotH - (v / max) * plotH]);
    const line = coords.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
    const area = `${line} L${coords[coords.length - 1][0].toFixed(1)},${PAD.top + plotH} L${PAD.left},${PAD.top + plotH} Z`;

    const nodes = [
        ...axis(max),
        svg('path', { d: area, class: 'chart__area' }),
        svg('path', { d: line, class: 'chart__line' }),
        ...coords.map(([x, y], i) => svg('circle', { cx: x, cy: y, r: 3, class: 'chart__dot' },
            svg('title', {}, document.createTextNode(`${days[i].short}: ${money(values[i])}`)))),
        ...days.map((d, i) => svg('text', { x: PAD.left + step * i, y: H - 6, class: 'chart__axis', 'text-anchor': 'middle' }, document.createTextNode(d.short))),
    ];

    return h('div', { className: 'chart' }, svg('svg', { viewBox: `0 0 ${W} ${H}`, class: 'chart__svg' }, nodes));
}
