// Line icons for the phone and its apps (our own drawings, no brand logos). Constant markup only.
const line = (body) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">${body}</svg>`;
const solid = (body) => `<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">${body}</svg>`;

export const ICONS = {
    star: line('<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>'),
    starFilled: solid('<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>'),
    clock: line('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
    person: line('<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>'),
    keypad: solid('<circle cx="6" cy="5" r="1.8"/><circle cx="12" cy="5" r="1.8"/><circle cx="18" cy="5" r="1.8"/><circle cx="6" cy="11" r="1.8"/><circle cx="12" cy="11" r="1.8"/><circle cx="18" cy="11" r="1.8"/><circle cx="6" cy="17" r="1.8"/><circle cx="12" cy="17" r="1.8"/><circle cx="18" cy="17" r="1.8"/><circle cx="12" cy="22" r="1.4"/>'),
    phone: solid('<path d="M6.6 2.8c.6-.2 1.3.1 1.6.7l1.6 3.7c.3.6.1 1.3-.4 1.7L7.7 10.2a12.6 12.6 0 0 0 6.1 6.1l1.3-1.7c.4-.5 1.1-.7 1.7-.4l3.7 1.6c.6.3.9 1 .7 1.6l-.8 2.8c-.2.6-.7 1-1.4 1A17.2 17.2 0 0 1 2.8 5c0-.7.4-1.2 1-1.4z"/>'),
    hangup: solid('<path d="M2.3 13.6c-.4-.5-.4-1.2 0-1.7C5 9.2 8.4 7.8 12 7.8s7 1.4 9.7 4.1c.4.5.4 1.2 0 1.7l-1.8 1.9c-.4.4-1.1.5-1.6.2l-2.6-1.4c-.5-.3-.8-.8-.7-1.4l.2-1.4a10.3 10.3 0 0 0-6.4 0l.2 1.4c.1.6-.2 1.1-.7 1.4l-2.6 1.4c-.5.3-1.2.2-1.6-.2z"/>'),
    mic: line('<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>'),
    micOff: line('<path d="M15 9.3V6a3 3 0 0 0-5.7-1.3M9 9v2a3 3 0 0 0 5.1 2.1M5 11a7 7 0 0 0 11.4 5.4M19 11a7 7 0 0 1-.6 2.8M12 18v3M3 3l18 18"/>'),
    plus: line('<path d="M12 5v14M5 12h14"/>'),
    message: solid('<path d="M12 3C6.5 3 2 6.7 2 11.2c0 2.6 1.5 4.9 3.8 6.4-.2 1.4-.9 2.7-2 3.6 2.3-.1 4.2-1 5.6-2.2.8.2 1.7.3 2.6.3 5.5 0 10-3.7 10-8.1S17.5 3 12 3z"/>'),
    compose: line('<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>'),
    info: line('<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>'),
    back: line('<path d="M15 5l-7 7 7 7"/>'),
    chevron: line('<path d="m9 5 7 7-7 7"/>'),
    search: line('<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>'),
    pin: solid('<path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"/>'),
    live: line('<circle cx="12" cy="12" r="2.5"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4M5 5a10 10 0 0 0 0 14M19 5a10 10 0 0 1 0 14"/>'),
    group: line('<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.9-3.3 3.4-5 6.5-5s5.6 1.7 6.5 5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 15.3c1.8.6 3 2.2 3.5 4.7"/>'),
    send: line('<path d="M12 19V5M5 12l7-7 7 7"/>'),
    close: line('<path d="M6 6l12 12M18 6 6 18"/>'),
    check: line('<path d="m5 12.5 4.5 4.5L19 7.5"/>'),
    trash: line('<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>'),
    block: line('<circle cx="12" cy="12" r="9"/><path d="m5.6 5.6 12.8 12.8"/>'),
    share: line('<path d="M12 15V3M7 8l5-5 5 5"/><path d="M5 13v7h14v-7"/>'),
    edit: line('<path d="M4 20h4L19 9l-4-4L4 16z"/>'),
    backspace: line('<path d="M9 5h11v14H9l-6-7z"/><path d="m12 9 5 6M17 9l-5 6"/>'),
    eyeOff: line('<path d="M3 3l18 18M10.6 6.1A9.8 9.8 0 0 1 12 6c5 0 8.5 4 9.5 6a12 12 0 0 1-2.4 3.2M6.6 7.6C4.6 8.9 3.2 10.7 2.5 12c1 2 4.5 6 9.5 6 1.5 0 2.9-.4 4.1-1M9.9 10a3 3 0 0 0 4.1 4.1"/>'),
    flashlight: solid('<path d="M7 2h10v4l-2 4v12H9V10L7 6zm5 10a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z"/>'),
    resize: line('<path d="M4 10V4h6M4 4l7 7M20 14v6h-6M20 20l-7-7"/>'),
};

export function icon(name) {
    const template = document.createElement('template');
    template.innerHTML = ICONS[name] || ICONS.info;
    const svg = template.content.firstElementChild;
    svg.classList.add('k-icon');
    return svg;
}
