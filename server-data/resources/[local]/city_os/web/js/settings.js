import { el, svg, iconTile, post, isWallpaperUrl, GLYPHS } from './util.js';
import { state, L, onRender, render, changeSettings, applySettings, allApps, dockApps, wallpaperCss } from './state.js';

const page = document.getElementById('settings');

const SECTIONS = [
    [['wallpaper', 'wallpaper', GLYPHS.picture, '#4fd1d9', '#1f9aa8'], ['home', 'home_icons', GLYPHS.grid, '#6f9bff', '#3f74f0'], ['dock', 'dock', GLYPHS.dock, '#a2aab8', '#6b7383']],
    [['notifications', 'notifications', GLYPHS.bell, '#ff7a7e', '#e5484d'], ['display', 'display', null, '#ffb057', '#f08a1a'], ['privacy', 'privacy', GLYPHS.lock, '#8b8ff8', '#5a5fe0']],
    [['about', 'about', GLYPHS.info, '#a2aab8', '#6b7383']],
];

let section = 'wallpaper';
let query = '';
let draft = '';
let pictureError = false;
let codeEntry = false;
let drawn = '';

function group(...rows) {
    const node = el('div', 'kit-group');
    node.append(...rows.filter(Boolean));
    return node;
}

function block(head, content, foot, footBad) {
    const node = el('div');
    if (head) node.append(el('div', 'kit-head', head));
    node.append(content);
    if (foot) node.append(el('div', footBad ? 'kit-foot bad' : 'kit-foot', foot));
    return node;
}

function icon(glyph, from, to, text) {
    const node = el('span', 'kit-icon', text);
    node.style.background = `linear-gradient(160deg, ${from}, ${to})`;
    if (glyph) node.append(svg(glyph, 17, 2.2));
    return node;
}

function sw(on, onChange, label) {
    const button = el('button', on ? 'kit-switch on' : 'kit-switch');
    button.setAttribute('role', 'switch');
    button.setAttribute('aria-checked', String(on));
    button.setAttribute('aria-label', label);
    button.addEventListener('click', () => onChange(!on));
    return button;
}

// A row: label plus an optional leading icon/thumbnail and a trailing switch, value, check or chevron
function row(label, { lead, value, check, toggle, onClick, chevron, danger } = {}) {
    const node = el(onClick ? 'button' : 'div', lead ? 'kit-row icon' : 'kit-row');
    if (lead) node.append(lead);
    node.append(el('span', danger ? 'kit-danger' : '', label));
    if (value !== undefined) node.append(el('span', 'kit-value', value));
    if (check) node.append(Object.assign(svg(GLYPHS.check, 18, 2.8), { classList: 'kit-check' }));
    if (toggle) node.append(sw(toggle.on, toggle.change, label));
    if (chevron) node.append(Object.assign(svg(GLYPHS.chevron, 14, 2.6), { classList: 'kit-chevron' }));
    if (onClick) node.addEventListener('click', onClick);
    return node;
}

// Small app icons in lists; Clear icons get the wallpaper behind them, or they vanish on a light list
function listIcon(app, style) {
    const tile = iconTile(app, style, 'tile tile-xs', 16);
    if (style === 'clear') tile.style.background += `, ${wallpaperCss()}`;
    return tile;
}

function thumb(css) {
    const node = el('span', 'kit-thumb');
    node.style.background = css;
    return node;
}

function setting(key) {
    return { on: state.settings[key], change: (value) => changeSettings({ [key]: value }) };
}

function wallpaperSection() {
    const s = state.settings;
    const previews = el('div', 'kit-card');
    previews.style.cssText = 'display: flex; justify-content: center; gap: 28px;';

    for (const label of ['lock_screen', 'home_screen']) {
        const item = el('div');
        item.style.cssText = 'display: flex; flex-direction: column; align-items: center; gap: 8px;';
        const preview = el('div', 'kit-preview');
        preview.style.background = wallpaperCss();
        item.append(preview, el('span', 'muted', L(label)));
        previews.append(item);
    }

    const list = group(...state.wallpapers.map((w) => row(w.label, {
        lead: thumb(w.css), check: s.wallpaper === w.id, onClick: () => changeSettings({ wallpaper: w.id }),
    })));

    const input = el('input', 'kit-input wide');
    input.placeholder = L('picture_link');
    input.value = draft;
    input.addEventListener('input', () => { draft = input.value; });

    const use = el('button', 'kit-btn accent', L('use_picture'));
    use.addEventListener('click', async () => {
        const url = draft.trim();
        const result = isWallpaperUrl(url) ? await post('setWallpaper', { url }) : null;

        pictureError = !(result && result.ok);
        if (!pictureError) {
            state.customWallpaper = url;
            draft = '';
            return changeSettings({ wallpaper: 'custom' });
        }
        render();
    });

    const entry = el('div', 'kit-row');
    entry.style.cssText = 'gap: 10px; padding: 8px 12px;';
    entry.append(input, use);

    const own = group(
        state.customWallpaper && row(L('your_picture'), { lead: thumb(`url("${state.customWallpaper}") center / cover`), check: s.wallpaper === 'custom', onClick: () => changeSettings({ wallpaper: 'custom' }) }),
        entry,
        state.customWallpaper && row(L('remove_picture'), { danger: true, onClick: async () => {
            await post('setWallpaper', { url: false });
            state.customWallpaper = false;
            changeSettings({ wallpaper: s.wallpaper === 'custom' ? state.wallpapers[0].id : s.wallpaper });
        } }),
    );

    return [previews, block(L('wallpaper'), list, L('wallpaper_note')), block(L('own_picture'), own, pictureError ? L('picture_bad') : L('picture_note'), pictureError)];
}

function homeSection() {
    const s = state.settings;
    const sample = allApps()[0];
    const styles = group(...['color', 'clear', 'tinted'].map((style) => row(L(`icon_${style}`), {
        lead: listIcon(sample, style), check: s.iconStyle === style, onClick: () => changeSettings({ iconStyle: style }),
    })));

    return [
        block(L('icon_style'), styles, L('icon_note')),
        group(row(L('show_labels'), { toggle: setting('labels') }), row(L('show_widgets'), { toggle: setting('widgets') }), row(L('show_badges'), { toggle: setting('badges') })),
    ];
}

function dockSection() {
    const current = dockApps().map((app) => app.id);
    const max = state.config.dockSize;

    const list = group(...allApps().map((app) => row(app.label, {
        lead: listIcon(app, state.settings.iconStyle),
        toggle: {
            on: current.includes(app.id),
            change: (on) => {
                const dock = on ? [...current, app.id].slice(0, max) : current.filter((id) => id !== app.id);
                changeSettings({ dock });
            },
        },
    })));

    return [block(L('in_dock'), list, L('dock_note', max))];
}

function notificationsSection() {
    const s = state.settings;
    const apps = state.apps.map((app) => row(app.label, {
        lead: listIcon(app, s.iconStyle),
        toggle: { on: !s.muted[app.id], change: (on) => {
            const muted = { ...s.muted };
            if (on) delete muted[app.id]; else muted[app.id] = true;
            changeSettings({ muted });
        } },
    }));

    return [
        group(row(L('notifications_lock'), { toggle: setting('lockNotes') })),
        block(L('apps'), apps.length ? group(...apps) : group(row(L('no_apps_dock'))), L('notifications_hidden_note')),
    ];
}

function displaySection() {
    const s = state.settings;
    const pick = (key, values, thumbs) => group(...values.map((value, i) => row(L(value === 'default' ? 'text_default' : (key === 'textSize' ? `text_${value}` : value)), {
        lead: thumbs && thumb(thumbs[i]), check: s[key] === value, onClick: () => changeSettings({ [key]: value }),
    })));

    return [
        block(L('appearance'), pick('appearance', ['light', 'dark'], ['linear-gradient(160deg, #ffffff, #e9eaef)', 'linear-gradient(160deg, #2a2d35, #0b0c10)']), L('appearance_note')),
        block(L('text_size'), pick('textSize', ['small', 'default', 'large'])),
        group(row(L('bold_text'), { toggle: setting('bold') }), row(L('animations'), { toggle: setting('motion') })),
    ];
}

function privacySection() {
    const hasCode = state.tablet.hasCode;

    const setCode = async (code) => {
        const result = await post('setCode', { code });
        if (result && result.ok) state.tablet.hasCode = code !== false;
        codeEntry = false;
        drawn = '';
        render();
    };

    const rows = [row(L('require_code'), { toggle: { on: hasCode || codeEntry, change: (on) => {
        if (on) { codeEntry = true; drawn = ''; return render(); }
        setCode(false);
    } } })];

    if (hasCode && !codeEntry) rows.push(row(L('change_code'), { chevron: true, onClick: () => { codeEntry = true; drawn = ''; render(); } }));

    if (codeEntry) {
        const input = el('input', 'kit-input wide');
        input.type = 'password';
        input.inputMode = 'numeric';
        input.maxLength = 4;
        input.placeholder = L('new_code');

        const save = el('button', 'kit-btn accent', L('save'));
        save.addEventListener('click', () => { if (/^\d{4}$/.test(input.value)) setCode(input.value); });

        const entry = el('div', 'kit-row');
        entry.style.cssText = 'gap: 10px; padding: 8px 12px;';
        entry.append(input, save);
        rows.push(entry);
        setTimeout(() => input.focus(), 0);
    }

    return [block(null, group(...rows), L('code_note'))];
}

function aboutSection() {
    const t = state.tablet;
    return [block(null, group(
        row(L('name'), { value: L('tablet_name', t.name) }),
        row(L('model'), { value: 'iFruit Pad' }),
        row(L('software'), { value: 'iFruit OS 1.0' }),
        row(L('serial'), { value: t.serial }),
        row(L('apps'), { value: String(allApps().length) }),
    ), L('serial_note'))];
}

const BUILDERS = { wallpaper: wallpaperSection, home: homeSection, dock: dockSection, notifications: notificationsSection, display: displaySection, privacy: privacySection, about: aboutSection };
const TITLES = { wallpaper: 'wallpaper', home: 'home_icons', dock: 'dock', notifications: 'notifications', display: 'display', privacy: 'privacy', about: 'about' };

function sidebar() {
    const side = el('nav', 'kit-sidebar');
    side.append(el('div', 'kit-title', L('settings')));

    const search = el('label', 'kit-search');
    const input = el('input');
    input.placeholder = L('search');
    input.value = query;
    input.addEventListener('input', () => { query = input.value; drawn = ''; render(); setTimeout(() => { const i = page.querySelector('.kit-search input'); i.focus(); i.setSelectionRange(query.length, query.length); }, 0); });
    search.append(svg(GLYPHS.search, 16, 2.2), input);

    const account = el('button', 'kit-group');
    account.style.cssText = 'display: flex; align-items: center; gap: 12px; padding: 12px; margin-bottom: 12px; border: 0; text-align: left;';
    const initials = state.tablet.name.split(' ').map((part) => part[0] || '').join('').slice(0, 2).toUpperCase();
    const avatar = el('span', '', initials);
    avatar.style.cssText = 'flex: none; width: 48px; height: 48px; border-radius: 24px; display: grid; place-items: center; background: linear-gradient(160deg, #ffe08a, #f5c542 45%, #d99a1e); color: #15181d; font-weight: 700;';
    const who = el('span');
    who.style.flexGrow = '1';
    who.append(Object.assign(el('span', '', state.tablet.name), { style: 'display: block; font-size: 15px; font-weight: 600;' }), Object.assign(el('span', 'muted', L('ifruit_id', state.tablet.citizenid)), { style: 'display: block; font-size: 12px;' }));
    account.append(avatar, who);
    account.addEventListener('click', () => { section = 'about'; render(); });

    side.append(search, account);

    for (const items of SECTIONS) {
        const matches = items.filter(([, key]) => L(key).toLowerCase().includes(query.trim().toLowerCase()));
        if (!matches.length) continue;

        const box = el('div', 'kit-group');
        box.style.cssText = 'padding: 4px; margin-bottom: 10px;';

        for (const [id, key, glyph, from, to] of matches) {
            const button = el('button', id === section ? 'kit-nav on' : 'kit-nav');
            button.append(icon(glyph, from, to, glyph ? undefined : 'Aa'), el('span', '', L(key)));
            button.addEventListener('click', () => { section = id; codeEntry = false; render(); });
            box.append(button);
        }

        side.append(box);
    }

    return side;
}

function renderSettings() {
    page.classList.toggle('hidden', state.screen !== 'settings');
    if (state.screen !== 'settings') return;

    // Redraw only when something on the page changed, so the clock ticking doesn't steal focus from a text field
    const key = JSON.stringify([section, query, pictureError, codeEntry, state.settings, state.customWallpaper, state.tablet.hasCode, state.apps.map((a) => a.id)]);
    if (key === drawn) return;
    drawn = key;

    const content = el('div', 'kit-content');
    content.append(el('div', 'kit-heading', L(TITLES[section])), ...BUILDERS[section]());
    page.replaceChildren(sidebar(), content);
}

export function reset() {
    section = 'wallpaper';
    query = '';
    draft = '';
    pictureError = false;
    codeEntry = false;
    drawn = '';
    applySettings();
}

export function init() {
    onRender(renderSettings);
}
