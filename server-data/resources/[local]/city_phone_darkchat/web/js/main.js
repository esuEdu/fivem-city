// The DarkChat page: pick an alias, the rooms you are in, joining or creating a room by name (optional password),
// and a room's messages. It runs inside city_phone; data comes from our resource's callbacks.
import {
    state, call, t, h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, applyContext,
    loadTexts, setLanguage, time,
} from './lib.js';

function empty(text) {
    return h('div', 'k-empty', null, icon('block'), h('span', '', text));
}

function reasonText(reason) {
    return t(`error.${reason || 'invalid'}`);
}

// The alias form, first time or from the settings button
function aliasForm(onDone) {
    const field = input('k-field', t('alias.placeholder'), 16);
    field.value = state.alias || '';
    field.addEventListener('input', () => { field.value = field.value.replace(/[^A-Za-z0-9_-]/g, ''); });

    return [
        h('p', 'k-group__label', t('alias.label')),
        h('div', 'k-group', null, field),
        h('p', 'hint', t('alias.hint')),
        button('k-button wide', t('alias.save'), async () => {
            const result = await call('setAlias', { alias: field.value });
            if (!result.ok) return toast(reasonText(result.reason));
            await onDone();
        }),
    ];
}

function openAlias() {
    openSheet(navBar(backButton(t('back'), closeSheet), t('alias.title'), null), aliasForm(async () => {
        closeSheet();
        toast(t('alias.saved'));
        await refresh();
    }));
}

function openEnter() {
    const name = input('k-field', t('enter.name'), 24);
    const password = input('k-field', t('enter.password'), 32);
    password.type = 'password';
    name.addEventListener('input', () => { name.value = name.value.toLowerCase().replace(/[^a-z0-9_-]/g, ''); });

    const go = button('k-link', t('enter.go'), async () => {
        const result = await call('enter', { name: name.value, password: password.value });
        if (!result.ok) return toast(reasonText(result.reason));

        toast(t(result.result.created ? 'enter.created' : 'enter.joined'));
        closeSheet();
        await refresh();
        const room = state.rooms.find((item) => item.id === result.result.id);
        if (room) openRoom(room);
    });

    openSheet(
        navBar(button('k-link', t('cancel'), closeSheet), t('enter.title'), go),
        h('div', 'k-group', null, name, password),
        h('p', 'hint', t('enter.hint')),
    );
}

async function loadMessages() {
    const room = state.room;
    if (!room) return;

    const result = await call('messages', { id: room.id });
    if (!result.ok) return;

    const rows = Array.isArray(result.result) ? result.result.reverse() : [];

    room.list.replaceChildren(...(rows.length
        ? rows.map((message) => h('div', `line${message.mine ? ' line--mine' : ''}`, null,
            h('span', 'line__time', time(message.createdAt)),
            h('span', 'line__alias', `<${message.alias}>`),
            h('span', 'line__text', message.text),
        ))
        : [h('div', 'line line--system', t('room.empty'))]));

    room.list.scrollTop = room.list.scrollHeight;
}

function openRoom(room) {
    const list = h('div', 'terminal');
    const field = h('input', 'prompt__input');
    Object.assign(field, { placeholder: t('room.placeholder'), maxLength: 300 });

    state.room = { id: room.id, list };
    call('viewing', { id: room.id });

    const send = async () => {
        const text = field.value.trim();
        if (!text) return;

        const result = await call('send', { id: room.id, text });
        if (!result.ok) return toast(reasonText(result.reason));

        field.value = '';
        loadMessages();
    };

    field.addEventListener('keydown', (event) => { if (event.key === 'Enter') send(); });

    const close = async () => {
        state.room = null;
        call('viewing', {});
        closeSheet();
        await refresh();
    };

    const leave = button('k-link k-link--danger', t('room.leave'), async () => {
        if (!(await call('leave', { id: room.id })).ok) return toast(reasonText());
        toast(t('room.left'));
        await close();
    });

    openSheet(
        navBar(backButton(t('back'), close), `#${room.name}`, leave),
        list,
        h('div', 'prompt', null, h('span', 'prompt__sign', '>'), field, iconButton('prompt__send', 'send', send)),
    );

    loadMessages();
}

function render() {
    const content = document.getElementById('content');

    if (!state.alias) {
        content.replaceChildren(
            h('div', 'welcome', null, h('div', 'welcome__logo', 'DarkChat'), h('p', 'welcome__text', t('welcome.text'))),
            ...aliasForm(refresh),
        );
        return;
    }

    content.replaceChildren(
        navBar(button('k-link', `@${state.alias}`, openAlias), null, button('k-link', null, openEnter, icon('plus'))),
        h('h1', 'k-large-title logo', 'DarkChat'),
        state.rooms.length
            ? h('div', 'k-list', null, state.rooms.map((room) => button('k-item', null, () => openRoom(room),
                h('span', 'room__hash', '#'),
                h('span', 'k-item__main', null,
                    h('span', 'k-item__title', room.name),
                    h('span', 'k-item__subtitle', t('rooms.members', room.members)),
                ),
                room.locked ? h('span', 'room__lock', null, icon('block')) : null,
            )))
            : empty(t('rooms.empty')),
    );
}

async function refresh() {
    const result = await call('me');
    if (!result.ok) return;

    state.alias = result.result.alias || null;
    state.rooms = Array.isArray(result.result.rooms) ? result.result.rooms : [];
    render();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        setLanguage(message.language);
        render();
    }

    if (message.type === 'city_phone:message' && message.data?.action === 'message') {
        if (state.room && state.room.id === message.data.room) loadMessages();
    }
});

async function start() {
    await loadTexts();
    await refresh();
}

start();
