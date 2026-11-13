// Draws city_points' icons as white 128x128 PNGs (the game tints them with city_ui's colors).
// Usage: node scripts/point-icons.mjs   (writes server-data/resources/[local]/city_points/icons/*.png)
// A shape is a list of contours filled with the even-odd rule, so inner contours cut holes.
import { writeFileSync, mkdirSync } from 'node:fs';
import { deflateSync, crc32 } from 'node:zlib';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SIZE = 128;
const SAMPLES = 4; // per axis, for anti-aliasing
const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'server-data', 'resources', '[local]', 'city_points', 'icons');

const rect = (x1, y1, x2, y2) => [[x1, y1], [x2, y1], [x2, y2], [x1, y2]];

function circle(cx, cy, r, steps = 96) {
    const points = [];
    for (let i = 0; i < steps; i++) {
        const a = (i / steps) * Math.PI * 2;
        points.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    }
    return points;
}

function inside(contours, x, y) {
    let odd = false;
    for (const poly of contours) {
        for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
            const [xi, yi] = poly[i];
            const [xj, yj] = poly[j];
            if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) odd = !odd;
        }
    }
    return odd;
}

// Shapes are unions: each one is filled on its own and the brightest coverage wins
function render(shapes) {
    const alpha = new Float32Array(SIZE * SIZE);
    for (const contours of shapes) {
        for (let py = 0; py < SIZE; py++) {
            for (let px = 0; px < SIZE; px++) {
                let hits = 0;
                for (let sy = 0; sy < SAMPLES; sy++) {
                    for (let sx = 0; sx < SAMPLES; sx++) {
                        if (inside(contours, px + (sx + 0.5) / SAMPLES, py + (sy + 0.5) / SAMPLES)) hits++;
                    }
                }
                const i = py * SIZE + px;
                alpha[i] = Math.max(alpha[i], hits / (SAMPLES * SAMPLES));
            }
        }
    }
    return alpha;
}

function png(alpha) {
    const raw = Buffer.alloc(SIZE * (SIZE * 4 + 1));
    for (let y = 0; y < SIZE; y++) {
        const row = y * (SIZE * 4 + 1);
        raw[row] = 0;
        for (let x = 0; x < SIZE; x++) {
            const o = row + 1 + x * 4;
            raw[o] = raw[o + 1] = raw[o + 2] = 255;
            raw[o + 3] = Math.round(alpha[y * SIZE + x] * 255);
        }
    }
    const chunk = (type, data) => {
        const len = Buffer.alloc(4);
        len.writeUInt32BE(data.length);
        const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
        const crc = Buffer.alloc(4);
        crc.writeUInt32BE(crc32(body));
        return Buffer.concat([len, body, crc]);
    };
    const header = Buffer.alloc(13);
    header.writeUInt32BE(SIZE, 0);
    header.writeUInt32BE(SIZE, 4);
    header[8] = 8; // bit depth
    header[9] = 6; // RGBA
    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        chunk('IHDR', header),
        chunk('IDAT', deflateSync(raw)),
        chunk('IEND', Buffer.alloc(0)),
    ]);
}

const icons = {
    // The badge behind every icon and its outline
    disc: [[circle(64, 64, 62)]],
    ring: [[circle(64, 64, 62), circle(64, 64, 55)]],

    // Pistol, muzzle to the left
    weapon: [
        [[[12, 38], [106, 38], [112, 44], [112, 62], [12, 62]]],
        [rect(16, 32, 23, 38)],
        [rect(98, 32, 106, 38)],
        [[[80, 62], [112, 62], [108, 74], [100, 110], [74, 110], [80, 76]]],
        [[[52, 62], [82, 62], [80, 88], [60, 88], [52, 76]], [[59, 66], [75, 66], [74, 82], [63, 82], [58, 75]]],
    ],

    // Personal locker: a cabinet with vents and a handle
    locker: [[
        rect(34, 14, 94, 114),
        rect(44, 26, 84, 31),
        rect(44, 37, 84, 42),
        rect(44, 48, 84, 53),
        rect(72, 66, 79, 90),
        rect(42, 102, 86, 106),
    ]],

    // Wardrobe: a T-shirt
    shirt: [[[
        [44, 20], [54, 20], [58, 27], [64, 30], [70, 27], [74, 20], [84, 20],
        [112, 42], [98, 60], [90, 53], [90, 110], [38, 110], [38, 53], [30, 60], [16, 42],
    ]]],
};

// Clocking in: a clock face with its hands
icons.clock = [
    [circle(64, 64, 50), circle(64, 64, 40)],
    [rect(60, 34, 68, 68)],
    [[[60, 60], [66, 58], [88, 78], [82, 84]]],
    [circle(64, 64, 7)],
];

// Garages: a car from the side, with wheel arches cut out and the wheels drawn in them
icons.car = [
    [[
        [10, 84], [10, 66], [20, 60], [36, 58], [48, 40], [86, 40], [100, 58], [112, 62], [118, 70], [118, 84],
        [104, 84], [102, 76], [94, 70], [84, 70], [76, 76], [74, 84], [52, 84], [50, 76], [42, 70], [32, 70],
        [24, 76], [22, 84],
    ], [[54, 46], [64, 46], [64, 58], [44, 58]], [[70, 46], [83, 46], [92, 58], [70, 58]]],
    [circle(37, 85, 11)],
    [circle(89, 85, 11)],
];

// Shops: a shopping basket
icons.basket = [
    [[[14, 52], [114, 52], [114, 62], [14, 62]]],
    [[[20, 64], [108, 64], [98, 108], [30, 108]], rect(36, 72, 42, 100), rect(50, 72, 56, 100), rect(64, 72, 70, 100), rect(78, 72, 84, 100), rect(92, 72, 96, 100)],
    [[[30, 50], [52, 18], [58, 22], [40, 50]]],
    [[[98, 50], [76, 18], [70, 22], [88, 50]]],
];

mkdirSync(OUT, { recursive: true });
for (const [name, shapes] of Object.entries(icons)) {
    writeFileSync(join(OUT, `${name}.png`), png(render(shapes)));
    console.log(`wrote icons/${name}.png`);
}
