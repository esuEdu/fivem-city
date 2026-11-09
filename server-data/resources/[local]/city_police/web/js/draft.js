import { app } from './main.js';

// Forms that survive closing the tablet: kept in this browser per character until saved or discarded. `open` says
// the form was on screen when the tablet closed, so the MDT goes back to it on the next start.
const key = (name) => `city_police:draft:${app.me.citizenid}:${name}`;

export function loadDraft(name) {
    try {
        const value = localStorage.getItem(key(name));
        return value ? JSON.parse(value) : null;
    } catch {
        return null;
    }
}

export function saveDraft(name, data) {
    try {
        localStorage.setItem(key(name), JSON.stringify(data));
    } catch {
        // storage full or blocked: the form still works, it just won't be there after closing
    }
}

export function clearDraft(name) {
    try {
        localStorage.removeItem(key(name));
    } catch {
        // nothing to clear
    }
}

// Marks a draft as left (another tab picked), so the next start doesn't jump back into it
export function leaveDraft(name) {
    const draft = loadDraft(name);
    if (draft) saveDraft(name, { ...draft, open: false });
}
