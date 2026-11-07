// City OS UI kit for app pages running inside the tablet. Exposes window.CityOS:
//   CityOS.send(event, data)  -> POST to this app's own resource (its RegisterNUICallback), returns the JSON reply
//   CityOS.on(type, fn)       -> 'message' (from SendAppMessage), 'open' (args of a tapped notification), 'theme'
//   CityOS.home()             -> back to the tablet's home screen
(() => {
    const TABLET = 'https://cfx-nui-city_os';
    const resource = location.hostname.replace(/^cfx-nui-/, '');
    const handlers = {};

    function emit(type, data) {
        for (const fn of handlers[type] || []) fn(data);
    }

    function applyTheme(theme) {
        const root = document.documentElement;
        root.classList.toggle('light', theme.appearance === 'light');
        root.classList.toggle('dark', theme.appearance !== 'light');
        root.dataset.textSize = theme.textSize || 'default';

        for (const [key, value] of Object.entries(theme.colors || {})) {
            root.style.setProperty(`--${key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`, value);
        }
    }

    window.addEventListener('message', (event) => {
        if (event.origin !== TABLET || !event.data || typeof event.data.type !== 'string') return;

        const { type, data } = event.data;
        if (type === 'theme') applyTheme(data);
        emit(type, data);
    });

    window.CityOS = {
        resource,
        on(type, fn) {
            (handlers[type] = handlers[type] || []).push(fn);
        },
        async send(event, data = {}) {
            try {
                const response = await fetch(`https://${resource}/${event}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify(data),
                });
                return await response.json();
            } catch {
                return null;
            }
        },
        home() {
            window.parent.postMessage({ cityOS: 'home' }, TABLET);
        },
    };

    document.documentElement.classList.add('dark');
    document.addEventListener('keydown', (event) => {
        // Esc goes home from any app (the tablet page can't see keys pressed inside the app)
        if (event.key === 'Escape') window.CityOS.home();
    });
    window.parent.postMessage({ cityOS: 'ready' }, TABLET);
})();
