// The game clock on the status bar and the lock screen. English uses 12 hours, Portuguese 24 hours.
import { t, language } from './i18n.js';
import { state, on } from './state.js';
import { $, icon } from './util.js';

export function formatTime({ hours, minutes }) {
    const mm = String(minutes).padStart(2, '0');

    if (language() === 'en') return `${hours % 12 || 12}:${mm}`;
    return `${String(hours).padStart(2, '0')}:${mm}`;
}

export function formatDate({ weekday, day, month }) {
    const days = t('time.days');
    const months = t('time.months');
    const dayName = Array.isArray(days) ? days[weekday] : '';
    const monthName = Array.isArray(months) ? months[month] : '';

    return language() === 'en' ? `${dayName}, ${monthName} ${day}` : `${dayName}, ${day} de ${monthName}`;
}

function render() {
    const time = formatTime(state.clock);
    $('status-time').textContent = time;
    $('lock-time').textContent = time;
    $('lock-date').textContent = formatDate(state.clock);
}

export function initClock() {
    const icons = $('status-icons');
    icons.append(icon('signal'), icon('wifi'), icon('battery'));

    on('clock', render);
    on('language', render);
    render();
}
