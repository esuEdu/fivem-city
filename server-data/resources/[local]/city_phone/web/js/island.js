// The dynamic island: a black pill that grows for live activities (a call, a timer) and for a moment when a
// notification arrives with the phone open.
import { $, el, icon } from './util.js';

const BANNER_MS = 3500;
const activities = new Map();
let banner = null;
let bannerTimer = null;

function iconTile(name, color) {
    const tile = el('span', 'icon');
    tile.style.background = color || '#3a3a3c';
    tile.append(icon(name));
    return tile;
}

function content(data, color) {
    const box = $('island').querySelector('.island__content');
    const text = el('span', 'island__text');

    text.append(el('strong', '', data.title || data.text || ''));
    if (data.detail || (data.title && data.text)) text.append(el('span', '', data.detail || data.text));

    box.replaceChildren(iconTile(data.icon || 'bell', data.color || color), text);
}

function render() {
    const island = $('island');

    island.classList.remove('island--banner', 'island--activity');

    if (banner) {
        content(banner);
        island.classList.add('island--banner');
        return;
    }

    const activity = [...activities.values()].at(-1);

    if (activity) {
        content({ title: activity.text, detail: activity.detail, icon: activity.icon, color: activity.color });
        island.classList.add('island--activity');
    }
}

// A notification while the phone is open
export function showBanner(notification) {
    banner = { title: notification.title, text: notification.text, icon: notification.icon || notification.app || 'bell' };
    render();

    clearTimeout(bannerTimer);
    bannerTimer = setTimeout(() => {
        banner = null;
        render();
    }, BANNER_MS);
}

export function setActivity(id, data) {
    if (data) activities.set(id, data);
    else activities.delete(id);
    render();
}
