// The Builder tablet app: what is placed, and the button that opens the editor.
(() => {
    let labels = {};

    const t = (key, ...args) => {
        let text = labels[key] ?? key;
        for (const arg of args) text = text.replace('%s', String(arg));
        return text;
    };

    function row(label, value) {
        const node = document.createElement('div');
        node.className = 'kit-row';

        const name = document.createElement('span');
        name.className = 'key';
        name.textContent = label;
        node.append(name);

        if (value !== undefined) {
            const right = document.createElement('span');
            right.className = 'kit-value';
            right.textContent = value;
            node.append(right);
        }

        return node;
    }

    async function load() {
        const info = await window.CityOS.send('appInfo');
        if (!info) return;

        labels = info.labels || {};

        document.getElementById('title').textContent = t('app_title');
        document.getElementById('intro').textContent = t('app_intro');
        document.getElementById('start').textContent = t('app_start');
        document.getElementById('keysTitle').textContent = t('keys_title');

        document.getElementById('stats').replaceChildren(
            row(t('app_props'), `${info.props} / ${info.max}`),
            row(t('app_groups'), info.groups),
            row(t('app_hides'), info.hides),
        );

        document.getElementById('keys').replaceChildren(
            ...['key_fly', 'key_select', 'key_move', 'key_rotate', 'key_fine', 'key_actions', 'key_history'].map((key) => row(t(key))),
        );
    }

    document.getElementById('start').addEventListener('click', () => window.CityOS.send('appStart'));

    load();
})();
