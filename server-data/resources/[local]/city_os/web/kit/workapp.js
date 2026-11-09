// Work app shell for job and gang apps (Mechanic, EMS, gangs): the sidebar with tabs and badges, the content area, the
// toast and small DOM helpers, so every one looks like the Staff app and the MDT. Load after kit.js (needs CityOS):
//   <script src="https://cfx-nui-city_os/web/kit/workapp.js"></script>
// and build the app with WorkApp.shell({ ... }). Game data only ever goes on the page with textContent.
(() => {
    let labels = {};

    // 24x24 stroke icons; apps add their own with WorkApp.addIcons
    const ICONS = {
        dashboard: 'M4 13h6V4H4zM14 20h6v-9h-6zM4 20h6v-3H4zM14 7h6V4h-6z',
        players: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 6-6h2a6 6 0 0 1 6 6v1M17 3.5a4 4 0 0 1 0 7.5M22 21v-1a6 6 0 0 0-4-5.6',
        bell: 'M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20.5a2 2 0 0 0 4 0',
        phone: 'M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z',
        list: 'M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01',
        log: 'M5 4h14v16H5zM9 8h6M9 12h6M9 16h4',
        wrench: 'M15 4a5 5 0 0 0-4.6 6.9L3 18.3 5.7 21l7.4-7.4A5 5 0 0 0 20 9l-3 1-2-2 1-3z',
        tag: 'M3 12V4h8l10 10-8 8zM7.5 8h.01',
        check: 'M5 12.5l4.5 4.5L19 7.5',
        clock: 'M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18zM12 7v5l3 2',
        search: 'M11 4.5a6.5 6.5 0 1 1 0 13a6.5 6.5 0 1 1 0-13zM16 16l4.5 4.5',
        place: 'M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11zM12 8a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
        route: 'M4.5 11.2L19.5 4.5l-6.7 15-1.9-6.4z',
        user: 'M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21v-1a7 7 0 0 1 7-7h2a7 7 0 0 1 7 7v1',
        plus: 'M12 5v14M5 12h14',
        up: 'M12 19V5M6 11l6-6 6 6',
        down: 'M12 5v14M6 13l6 6 6-6',
        kick: 'M14 4h5v16h-5M10 8l4 4-4 4M14 12H3',
        vehicle: 'M5 16h14v-4l-2-5H7l-2 5zM5 16v2M19 16v2M8 13h.01M16 13h.01',
        money: 'M4 7h16v10H4zM12 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4zM7 10v4M17 10v4',
        star: 'M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z',
        shield: 'M12 3l7 3v5c0 4.6-3 8.3-7 9.5C8 19.3 5 15.6 5 11V6z',
        chevron: 'M9 5l7 7-7 7',
        close: 'M6 6l12 12M18 6L6 18',
    };

    function setLabels(next) {
        labels = next || {};
    }

    function L(key, ...args) {
        let text = labels[key] ?? key;
        for (const arg of args) text = text.replace(/%[sd]/, String(arg));
        return text;
    }

    function addIcons(more) {
        Object.assign(ICONS, more);
    }

    function icon(name, size = 20, stroke = 1.8) {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        for (const [key, value] of Object.entries({ width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': stroke, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true' })) {
            svg.setAttribute(key, value);
        }

        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', ICONS[name] || ICONS.chevron);
        svg.append(path);

        return svg;
    }

    // el('button', { class: 'kit-btn', text: 'Go', onclick: fn }, child, ...)
    function el(tag, props = {}, ...children) {
        const node = document.createElement(tag);

        for (const [key, value] of Object.entries(props)) {
            if (value === undefined || value === null || value === false) continue;
            if (key === 'class') node.className = value;
            else if (key === 'text') node.textContent = value;
            else if (key === 'style') node.style.cssText = value;
            else if (key.startsWith('on')) node.addEventListener(key.slice(2), value);
            else if (key === 'value') node.value = value;
            else node.setAttribute(key, value === true ? '' : value);
        }

        for (const child of children.flat()) {
            if (child === null || child === undefined || child === false) continue;
            node.append(typeof child === 'string' || typeof child === 'number' ? document.createTextNode(String(child)) : child);
        }

        return node;
    }

    let toastTimer = null;

    function toast(text, kind = 'ok') {
        let node = document.getElementById('wa-toast');
        if (!node) {
            node = el('div', { id: 'wa-toast' });
            document.body.append(node);
        }

        node.textContent = text;
        node.className = `show ${kind}`;
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => (node.className = ''), 3200);
    }

    // One action through the app's own client script ('run' NUI callback); failures show why (locale error_<reason>)
    async function run(action, args = {}, done) {
        const response = await window.CityOS.send('run', { action, args });

        if (!response || !response.ok) {
            toast(L(`error_${(response && response.reason) || 'failed'}`), 'bad');
            return null;
        }

        if (done) toast(done);
        return response;
    }

    // A button that asks once more ("Sure?") before something hard to undo
    function confirmButton(content, onConfirm, className = 'kit-btn soft-danger') {
        let armed = false;
        let timer = null;

        const button = el('button', { class: className }, content);
        const original = [...button.childNodes];

        button.addEventListener('click', () => {
            if (!armed) {
                armed = true;
                button.replaceChildren(L('ui_sure'));
                timer = setTimeout(() => {
                    armed = false;
                    button.replaceChildren(...original);
                }, 3000);
                return;
            }

            clearTimeout(timer);
            armed = false;
            button.replaceChildren(...original);
            onConfirm();
        });

        return button;
    }

    function heading(title, ...extra) {
        return el('div', { class: 'heading' }, el('h1', { text: title }), ...extra);
    }

    function pill(text, kind = '') {
        return el('span', { class: `pill ${kind}`, text });
    }

    // options [[value, label]], calls pick(value)
    function segmented(options, current, pick) {
        return el('div', { class: 'segmented' }, options.map(([value, label]) =>
            el('button', { class: value === current ? 'on' : '', text: label, onclick: () => pick(value) })));
    }

    function searchField(placeholder, oninput, value = '') {
        return el('label', { class: 'search' }, icon('search', 16, 2),
            el('input', { type: 'text', placeholder, value, 'aria-label': placeholder, oninput: (event) => oninput(event.target.value.trim().toLowerCase()) }));
    }

    function tile(iconName, kind, label, value, sub, subKind = '') {
        return el('div', { class: 'card tile' },
            el('div', { class: 'tile-head' }, el('span', { class: `tile-icon ${kind}` }, icon(iconName, 18, 2)), el('span', { text: label })),
            el('strong', { class: 'tile-value', text: value }),
            sub ? el('small', { class: `tile-sub ${subKind}`, text: sub }) : null,
        );
    }

    // days: [{ label, value, title? }], the last one is today
    function bars(days) {
        const max = Math.max(1, ...days.map((day) => day.value));

        return el('div', { class: 'bars', style: `--bars: ${days.length}` }, days.map((day, index) => el('div', { class: 'bar-day' },
            el('div', { class: 'bar-col' },
                el('span', { class: `bar${index === days.length - 1 ? ' today' : ''}`, style: `height: ${Math.round((day.value / max) * 130)}px`, title: day.title || String(day.value) })),
            el('small', { text: day.label }))));
    }

    function initials(name) {
        return (name || '?').trim().split(/\s+/).map((part) => part[0] || '').join('').slice(0, 2).toUpperCase();
    }

    function avatar(name, presence) {
        return el('span', { class: 'avatar' }, initials(name), presence !== undefined ? el('i', { class: `presence ${presence}` }) : null);
    }

    function money(amount) {
        return `$${Math.round(amount || 0).toLocaleString('en-US')}`;
    }

    function formatTime(unix) {
        if (!unix) return '—';
        return new Date(unix * 1000).toLocaleString('en-US', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
    }

    function ago(seconds) {
        seconds = Math.max(0, Math.floor(seconds));
        if (seconds < 60) return L('ui_just_now');
        if (seconds < 3600) return L('ui_minutes_ago', Math.floor(seconds / 60));
        if (seconds < 86400) return L('ui_hours_ago', Math.floor(seconds / 3600));
        return L('ui_days_ago', Math.floor(seconds / 86400));
    }

    function since(unix) {
        return ago(Date.now() / 1000 - unix);
    }

    // The app: sidebar (logo, title, subtitle lines, tabs, footer) and the content area.
    // options: { title, logo (icon name), subtitle: () => string[], tabs: [{ id, icon, label, visible?, badge?, render(args) }],
    //            footer?: () => Node }
    function shell(options) {
        const side = el('aside', { class: 'wa-side' });
        const nav = el('nav', { class: 'wa-nav' });
        const content = el('main', { class: 'wa-content' });
        const lines = el('div', { class: 'who' });
        const foot = el('div', { class: 'wa-foot-slot' });
        let current = null;
        let drawn = 0;

        side.append(el('div', { class: 'wa-brand' }, el('span', { class: 'wa-logo' }, icon(options.logo, 22, 2)), lines), nav, foot);
        document.body.prepend(el('div', { class: 'wa' }, side, content));
        foot.style.marginTop = 'auto';

        const visibleTabs = () => options.tabs.filter((tab) => !tab.visible || tab.visible());

        function drawSide() {
            lines.replaceChildren(el('strong', { text: options.title() }), ...(options.subtitle ? options.subtitle() : []).map((line) => el('small', { text: line })));
            nav.replaceChildren(...visibleTabs().map((tab) => {
                const count = tab.badge ? tab.badge() : 0;
                return el('button', { class: `wa-tab${current === tab.id ? ' on' : ''}`, onclick: () => app.go(tab.id) },
                    icon(tab.icon),
                    el('span', { class: 'label', text: tab.label() }),
                    count > 0 ? el('span', { class: 'badge', text: String(count) }) : null);
            }));
            foot.replaceChildren(...(options.footer ? [options.footer()].filter(Boolean) : []));
        }

        const app = {
            get tab() { return current; },
            // Each tab draws into the content area; args open it on one item (a call from a notification)
            async go(id, args) {
                const tab = visibleTabs().find((entry) => entry.id === id) || visibleTabs()[0];
                if (!tab) return;

                current = tab.id;
                drawSide();

                const ticket = ++drawn;
                if (!content.firstChild) content.replaceChildren(el('div', { class: 'loading', text: L('ui_loading') }));

                const view = await tab.render(args);
                if (ticket === drawn && view) content.replaceChildren(view);
            },
            refresh() {
                drawSide();
            },
            fail(text) {
                content.replaceChildren(el('div', { class: 'empty', text }));
            },
        };

        return app;
    }

    window.WorkApp = {
        ICONS, addIcons, icon, el, L, setLabels, toast, run, confirmButton, heading, pill, segmented, searchField, tile, bars,
        initials, avatar, money, formatTime, ago, since, shell,
    };
})();
