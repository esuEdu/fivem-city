// Everything the screens share, and a tiny event bus between them
export const state = {
    open: false,
    profile: { name: '', number: '' },
    settings: {
        theme: 'dark', language: 'en', font: 'inter', wallpaper: 'aurora',
        brightness: 100, silent: false, dnd: false, size: 100, ringtone: 'classic',
    },
    clock: { hours: 12, minutes: 0, weekday: 0, day: 1, month: 0, year: 2026 },
    apps: [],
    notifications: [],
    flashlight: false,
};

const listeners = {};

export function on(event, fn) {
    (listeners[event] ||= []).push(fn);
}

export function emit(event, ...args) {
    for (const fn of listeners[event] || []) fn(...args);
}
