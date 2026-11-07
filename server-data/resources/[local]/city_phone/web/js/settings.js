// The built-in Settings app: profile, wallpaper, appearance, brightness, font, sounds, Do Not Disturb, language and
// about. Every change is saved on the server (character metadata), which checks the value again.
import { t } from './i18n.js';
import { TONES, preview } from './ring.js';
import { state, emit } from './state.js';
import { el, icon, post } from './util.js';

const WALLPAPERS = ['aurora', 'sunset', 'ocean', 'forest', 'graphite', 'candy'];
const FONTS = { inter: 'Inter', poppins: 'Poppins', roboto: 'Roboto', nunito: 'Nunito' };
const LANGUAGES = { en: 'English', 'pt-br': 'Português (Brasil)' };
const VERSION = '0.1.0';

let root = null;
let stack = [];

export async function saveSetting(key, value) {
    const previous = state.settings[key];

    state.settings[key] = value;
    emit('settings', key);

    const ok = await post('saveSetting', { key, value });

    if (ok !== true) {
        state.settings[key] = previous;
        emit('settings', key);
    }
}

function iconTile(name, color) {
    const tile = el('span', 'icon');
    tile.style.background = color;
    tile.append(icon(name));
    return tile;
}

function row({ label, value, iconName, color, onClick, link, right }) {
    const node = el(onClick ? 'button' : 'div', `row${link ? ' row--link' : ''}`);
    if (iconName) node.append(iconTile(iconName, color));
    node.append(el('span', 'row__label', label));
    if (value !== undefined) node.append(el('span', 'row__value', value));
    if (right) node.append(right);
    if (onClick) node.addEventListener('click', onClick);
    return node;
}

function group(title, ...rows) {
    const wrap = el('div');
    if (title) wrap.append(el('div', 'group__label', title));
    const box = el('div', 'group');
    box.append(...rows);
    wrap.append(box);
    return wrap;
}

function toggleSwitch(key) {
    const node = el('span', `switch${state.settings[key] ? ' switch--on' : ''}`);
    return node;
}

function check(selected) {
    return el('span', 'row__check', selected ? '✓' : '');
}

// A page slides in over the one under it; Back slides it out
function page(title, build, isRoot = false) {
    const node = el('div', `page${isRoot ? '' : ' page--enter'}`);

    const draw = () => {
        const children = [];
        if (!isRoot) {
            const back = el('button', 'page__back', t('settings.title'));
            back.addEventListener('click', pop);
            children.push(back);
        }
        children.push(el('h1', 'page__title', title()), ...build(draw));
        node.replaceChildren(...children);
    };

    node.redraw = draw;
    draw();
    return node;
}

function push(node) {
    stack.at(-1)?.classList.add('page--under');
    stack.push(node);
    root.append(node);
    requestAnimationFrame(() => requestAnimationFrame(() => node.classList.remove('page--enter')));
}

function pop() {
    if (stack.length < 2) return;
    const node = stack.pop();
    node.classList.add('page--enter');
    stack.at(-1).classList.remove('page--under');
    stack.at(-1).redraw();
    setTimeout(() => node.remove(), 350);
}

function choicePage(title, key, options, render, onPick) {
    return page(() => t(title), (redraw) => [
        group(null, ...Object.entries(options).map(([value, text]) => {
            const item = row({
                label: text,
                right: check(state.settings[key] === value),
                onClick: async () => {
                    if (onPick) onPick(value);
                    await saveSetting(key, value);
                    redraw();
                },
            });
            if (render) render(item, value);
            return item;
        })),
    ]);
}

function wallpaperPage() {
    return page(() => t('settings.wallpaper'), (redraw) => {
        const grid = el('div', 'wallpapers');
        for (const name of WALLPAPERS) {
            const button = el('button', `wallpaper wp-${name}${state.settings.wallpaper === name ? ' wallpaper--on' : ''}`);
            button.addEventListener('click', async () => { await saveSetting('wallpaper', name); redraw(); });
            grid.append(button);
        }
        return [grid];
    });
}

function appearancePage() {
    return page(() => t('settings.appearance'), (redraw) => {
        const box = el('div', 'group themes');
        for (const theme of ['light', 'dark']) {
            const button = el('button', `theme${state.settings.theme === theme ? ' theme--on' : ''}`);
            button.append(el('span', `theme__preview theme__preview--${theme}`), el('span', '', t(`settings.${theme}`)));
            button.addEventListener('click', async () => { await saveSetting('theme', theme); redraw(); });
            box.append(button);
        }

        const range = el('input', 'range');
        Object.assign(range, { type: 'range', min: 30, max: 100, value: state.settings.brightness });
        range.addEventListener('input', () => { state.settings.brightness = Number(range.value); emit('settings', 'brightness'); });
        range.addEventListener('change', () => saveSetting('brightness', Number(range.value)));

        const size = el('input', 'range');
        Object.assign(size, { type: 'range', min: 70, max: 130, value: state.settings.size || 100 });
        size.addEventListener('input', () => { state.settings.size = Number(size.value); emit('settings', 'size'); });
        size.addEventListener('change', () => saveSetting('size', Number(size.value)));

        return [
            box,
            group(t('settings.brightness'), row({ label: '', right: range })),
            group(t('settings.size'), row({ label: '', right: size })),
        ];
    });
}

function rootPage() {
    return page(() => t('settings.title'), (redraw) => {
        const initials = state.profile.name.split(' ').map((part) => part[0] || '').join('').slice(0, 2);
        const avatar = el('span', 'avatar', initials);
        const profile = row({ label: '' });
        profile.classList.add('profile');
        profile.replaceChildren(avatar, (() => {
            const text = el('span', 'row__label', state.profile.name);
            text.append(el('small', '', state.profile.number));
            return text;
        })());

        const flip = (key) => async () => { await saveSetting(key, !state.settings[key]); redraw(); };

        return [
            group(null, profile),
            group(null,
                row({ label: t('settings.wallpaper'), iconName: 'wallpaper', color: '#30b0c7', link: true, onClick: () => push(wallpaperPage()) }),
                row({ label: t('settings.appearance'), iconName: 'sun', color: '#0a84ff', link: true, onClick: () => push(appearancePage()) }),
                row({ label: t('settings.font'), iconName: 'font', color: '#ff9f0a', value: FONTS[state.settings.font], link: true,
                    onClick: () => push(choicePage('settings.font', 'font', FONTS, (item, value) => { item.style.fontFamily = FONTS[value]; })) }),
            ),
            group(null,
                row({ label: t('settings.ringtone'), iconName: 'bell', color: '#ff2d55', value: t(`ringtones.${state.settings.ringtone}`), link: true,
                    onClick: () => push(choicePage('settings.ringtone', 'ringtone', ringtoneNames(), null, preview)) }),
                row({ label: t('settings.silent'), iconName: 'silent', color: '#ff375f', right: toggleSwitch('silent'), onClick: flip('silent') }),
                row({ label: t('settings.dnd'), iconName: 'moon', color: '#5e5ce6', right: toggleSwitch('dnd'), onClick: flip('dnd') }),
            ),
            group(null,
                row({ label: t('settings.language'), iconName: 'globe', color: '#0a84ff', value: LANGUAGES[state.settings.language], link: true,
                    onClick: () => push(choicePage('settings.language', 'language', LANGUAGES)) }),
                row({ label: t('settings.number'), iconName: 'info', color: '#8e8e93', value: state.profile.number }),
                row({ label: t('settings.version'), iconName: 'info', color: '#8e8e93', value: VERSION }),
            ),
        ];
    }, true);
}

function ringtoneNames() {
    return Object.fromEntries(Object.keys(TONES).map((tone) => [tone, t(`ringtones.${tone}`)]));
}

// Builds the app inside its view
export function openSettings(view) {
    root = el('div', 'settings');
    stack = [rootPage()];
    root.append(stack[0]);
    view.append(root);
}

// Language or profile changed: redraw what is on screen
export function refreshSettings() {
    for (const node of stack) node.redraw();
}
