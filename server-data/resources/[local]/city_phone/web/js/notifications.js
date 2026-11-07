// Notifications: a banner in the island (phone open) or a card in the corner (phone closed), then kept on the lock
// screen until cleared. Do Not Disturb keeps them without the banner.
import { t } from './i18n.js';
import { showBanner } from './island.js';
import { state, on, emit } from './state.js';
import { $, el, icon, post } from './util.js';

const MAX = 30;
const TOAST_MS = 4500;
const APP_COLORS = { phone: '#34c759', mail: '#0a84ff', police: '#1f3b73', mechanic: '#f2a900', races: '#ff9f0a' };

function since(notification) {
    const minutes = Math.floor((Date.now() - notification.at) / 60000);
    return minutes < 1 ? t('notifications.now') : `${minutes}m`;
}

function tile(notification) {
    const box = el('span', 'icon');
    box.style.background = APP_COLORS[notification.app] || '#3a3a3c';
    box.append(icon(notification.app || 'bell'));
    return box;
}

function card(notification, withAction) {
    const node = el('div', 'card');
    const body = el('div', 'card__body');
    const head = el('div', 'card__head');

    head.append(el('span', '', notification.title), el('small', '', since(notification)));
    body.append(head);
    if (notification.text) body.append(el('span', '', notification.text));

    if (withAction && notification.hasAction) {
        const button = el('button', 'card__button', notification.actionLabel || t('notifications.action'));
        button.addEventListener('click', (event) => {
            event.stopPropagation();
            post('notificationAction', { id: notification.id });
            remove(notification.id);
        });
        body.append(button);
    }

    node.append(tile(notification), body);
    return node;
}

function remove(id) {
    state.notifications = state.notifications.filter((item) => item.id !== id);
    renderList();
}

export function renderList() {
    const list = $('lock-list');
    const items = state.notifications.map((notification) => card(notification, true));

    if (items.length > 0) {
        const clear = el('button', 'lock__clear', t('notifications.clear'));
        clear.addEventListener('click', (event) => {
            event.stopPropagation();
            for (const item of state.notifications) post('notificationDismissed', { id: item.id });
            state.notifications = [];
            renderList();
        });
        items.unshift(clear);
    }

    list.replaceChildren(...items);
}

function toast(notification) {
    const node = card(notification, false);
    node.classList.add('toast');
    $('toasts').prepend(node);

    setTimeout(() => {
        node.classList.add('toast--out');
        setTimeout(() => node.remove(), 400);
    }, TOAST_MS);
}

export function addNotification(notification, quiet) {
    notification.at = Date.now();
    state.notifications.unshift(notification);

    for (const old of state.notifications.splice(MAX)) post('notificationDismissed', { id: old.id });

    renderList();
    emit('notification', notification);

    if (quiet) return;
    if (state.open) showBanner(notification);
    else toast(notification);
}

export function initNotifications() {
    on('language', renderList);
    on('opened', renderList);
}
