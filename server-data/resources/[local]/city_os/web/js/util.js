const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_os';
const SVG = 'http://www.w3.org/2000/svg';

// Built-in glyphs (SVG path data, 24x24, stroked) for the tablet's own screens
export const GLYPHS = {
    gear: 'M15.2 12a3.2 3.2 0 1 1-6.4 0a3.2 3.2 0 1 1 6.4 0M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1',
    lock: 'M7.5 11h9a2.5 2.5 0 0 1 2.5 2.5v5a2.5 2.5 0 0 1-2.5 2.5h-9A2.5 2.5 0 0 1 5 18.5v-5A2.5 2.5 0 0 1 7.5 11zM8 11V8a4 4 0 0 1 8 0v3',
    wifi: 'M2 9a15 15 0 0 1 20 0M5.5 12.5a10 10 0 0 1 13 0M9 16a5 5 0 0 1 6 0M12 19.5v.01',
    picture: 'M6 4h12a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3zM3 16l5-5 4 4 3-3 6 6',
    grid: 'M5.8 4h2.9a1.8 1.8 0 0 1 1.8 1.8v2.9a1.8 1.8 0 0 1-1.8 1.8H5.8A1.8 1.8 0 0 1 4 8.7V5.8A1.8 1.8 0 0 1 5.8 4zM15.3 4h2.9A1.8 1.8 0 0 1 20 5.8v2.9a1.8 1.8 0 0 1-1.8 1.8h-2.9a1.8 1.8 0 0 1-1.8-1.8V5.8A1.8 1.8 0 0 1 15.3 4zM5.8 13.5h2.9a1.8 1.8 0 0 1 1.8 1.8v2.9A1.8 1.8 0 0 1 8.7 20H5.8A1.8 1.8 0 0 1 4 18.2v-2.9a1.8 1.8 0 0 1 1.8-1.8zM15.3 13.5h2.9a1.8 1.8 0 0 1 1.8 1.8v2.9a1.8 1.8 0 0 1-1.8 1.8h-2.9a1.8 1.8 0 0 1-1.8-1.8v-2.9a1.8 1.8 0 0 1 1.8-1.8z',
    dock: 'M5 14h14a2 2 0 0 1 2 2v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-2a2 2 0 0 1 2-2zM7 10h.01M12 10h.01M17 10h.01',
    bell: 'M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0',
    info: 'M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18zM12 11v6M12 7.5v.01',
    check: 'M5 12.5l4.5 4.5L19 7.5',
    chevron: 'M9 5l7 7-7 7',
    search: 'M11 4.5a6.5 6.5 0 1 1 0 13a6.5 6.5 0 1 1 0-13zM16 16l4.5 4.5',
    warning: 'M12 3l9.5 17h-19zM12 10v4.5M12 17.5v.01',
    tablet: 'M7 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM11 18h2',
};

// The tablet's own Settings app, shown like a registered app
export const SETTINGS_APP = {
    id: 'settings',
    label: 'Settings',
    icon: { glyph: GLYPHS.gear, colors: ['#c1c7d2', '#808898', '#535a68'], glyphColor: '#ffffff', tint: '#d6dae2' },
};

export async function post(name, data = {}) {
    try {
        const response = await fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await response.json();
    } catch {
        return null;
    }
}

export function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

export function svg(path, size = 24, strokeWidth = 2.1) {
    const node = document.createElementNS(SVG, 'svg');
    node.setAttribute('width', size);
    node.setAttribute('height', size);
    node.setAttribute('viewBox', '0 0 24 24');
    node.setAttribute('fill', 'none');
    node.setAttribute('stroke', 'currentColor');
    node.setAttribute('stroke-width', strokeWidth);
    node.setAttribute('stroke-linecap', 'round');
    node.setAttribute('stroke-linejoin', 'round');
    node.setAttribute('aria-hidden', 'true');

    const shape = document.createElementNS(SVG, 'path');
    shape.setAttribute('d', path);
    node.append(shape);

    return node;
}

// An app icon in the player's icon style; colors were checked on the server (#rrggbb only)
export function iconTile(app, style, className = 'tile', glyphSize = 32) {
    const icon = app.icon;
    const tile = el('span', className);

    if (style === 'clear') {
        tile.style.background = 'linear-gradient(160deg, rgba(255, 255, 255, 0.38), rgba(255, 255, 255, 0.1) 60%, rgba(255, 255, 255, 0.18))';
        tile.style.color = '#ffffff';
    } else if (style === 'tinted') {
        tile.style.background = 'linear-gradient(160deg, #2b2f38, #15171d 60%, #0d0e12)';
        tile.style.color = icon.tint;
    } else {
        tile.style.background = `linear-gradient(160deg, ${icon.colors[0]}, ${icon.colors[1]} 45%, ${icon.colors[2]})`;
        tile.style.color = icon.glyphColor;
    }

    tile.append(svg(icon.glyph, glyphSize));

    return tile;
}

// city_ui/theme.lua keys as CSS variables (accentText -> --accent-text)
export function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        const name = key.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
        document.documentElement.style.setProperty(`--${name}`, value);
    }
}

// Locale strings use %s for values
export function format(text, ...values) {
    let i = 0;
    return String(text ?? '').replace(/%s/g, () => String(values[i++] ?? ''));
}

export function pad(value) {
    return String(value).padStart(2, '0');
}

// Same rule as shared/settings.lua isWallpaperUrl
export function isWallpaperUrl(url) {
    return typeof url === 'string' && url.length > 12 && url.length <= 480 && /^https:\/\/[^\s"'()\\<>]+$/.test(url);
}
