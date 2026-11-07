// Favorites, Recents and Keypad tabs
import { openContact, editContact } from './contacts.js';
import {
    state, call, t, h, button, iconButton, icon, avatar, toast, navBar, formatNumber, nameFor, contactFor, reasonText,
} from './lib.js';

export async function dial(number, hidden = state.hidden) {
    const result = await call('dial', { number, hidden });
    if (!result.ok) toast(reasonText(result.reason));
}

function empty(iconName, text) {
    return h('div', 'k-empty', null, icon(iconName), h('span', '', text));
}

export function favorites() {
    const list = state.contacts.filter((contact) => contact.favorite);

    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('tabs.favorites')),
        list.length === 0 ? empty('star', t('favorites.empty')) : h('div', 'k-list', null, list.map((contact) => button('k-item', null, () => dial(contact.number),
            avatar(contact.name),
            h('span', 'k-item__main', null, h('span', 'k-item__title', contact.name), h('span', 'k-item__subtitle', t('mobile'))),
            iconButton('info', 'info', (event) => { event.stopPropagation(); openContact(contact); }),
        ))),
    ];
}

function ago(at) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000) - at);
    if (seconds < 3600) return t('time.minutes', Math.max(1, Math.floor(seconds / 60)));
    if (seconds < 86400) return t('time.hours', Math.floor(seconds / 3600));
    return t('time.days', Math.floor(seconds / 86400));
}

const DIRECTION_ICON = { out: 'phone', in: 'phone', missed: 'phone' };

export function recents(render) {
    const clear = state.recents.length ? button('k-link', t('recents.clear'), async () => {
        if ((await call('clearRecents')).ok) {
            state.recents = [];
            render();
        }
    }) : null;

    return [
        navBar(null, null, clear),
        h('h1', 'k-large-title', t('tabs.recents')),
        state.recents.length === 0 ? empty('clock', t('recents.empty')) : h('div', 'k-list', null, state.recents.map((entry) => {
            const missed = entry.direction === 'missed';

            return button(`k-item k-item--plain${missed ? ' k-item--missed' : ''}`, null, () => entry.number && dial(entry.number),
                h('span', 'direction', null, entry.direction === 'out' ? icon(DIRECTION_ICON.out) : null),
                h('span', 'k-item__main', null,
                    h('span', 'k-item__title', nameFor(entry.number)),
                    h('span', 'k-item__subtitle', t(`recents.${entry.direction}`)),
                ),
                h('span', 'distance', ago(entry.at)),
                entry.number ? iconButton('info', 'info', (event) => {
                    event.stopPropagation();
                    const contact = contactFor(entry.number);
                    if (contact) openContact(contact);
                    else editContact({ name: '', number: entry.number });
                }) : null,
            );
        })),
    ];
}

const KEYS = [
    ['1', ''], ['2', 'ABC'], ['3', 'DEF'], ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
    ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'], ['*', ''], ['0', '+'], ['#', ''],
];

export function keypad(render) {
    const digits = state.number;

    const press = (key) => {
        if (state.number.length >= 15) return;
        state.number += key;
        render();
    };

    const add = digits && !contactFor(digits)
        ? button('k-link', t('keypad.add'), () => editContact({ name: '', number: digits }))
        : null;

    return [h('div', 'keypad', null,
        h('div', 'keypad__number', formatNumber(digits)),
        h('div', 'keypad__add', null, add),
        h('div', 'keypad__grid', null, KEYS.map(([digit, letters]) => button('key', null, () => press(digit),
            h('span', 'key__digit', digit),
            letters ? h('span', 'key__letters', letters) : null,
        ))),
        h('div', 'keypad__actions', null,
            iconButton(`keypad__hide${state.hidden ? ' keypad__hide--on' : ''}`, 'eyeOff', () => {
                state.hidden = !state.hidden;
                render();
            }, t('keypad.hide')),
            iconButton('round round--green', 'phone', () => digits && dial(digits.replace(/\D/g, ''))),
            digits ? iconButton('keypad__back', 'backspace', () => {
                state.number = state.number.slice(0, -1);
                render();
            }) : h('span'),
        ),
        h('div', 'keypad__hint', state.hidden ? t('keypad.hidden') : ''),
    )];
}
