// Favorites, Recents and Keypad tabs
import { state, call, t, h, button, formatNumber, nameFor, initials, toast, reasonText, contactFor } from './lib.js';
import { openContact, editContact } from './contacts.js';

export async function dial(number, hidden = state.hidden) {
    const result = await call('dial', { number, hidden });
    if (!result.ok) toast(reasonText(result.reason));
}

function title(text, right) {
    return [h('div', 'head', null, h('span'), right), h('h1', 'title', text)];
}

export function favorites() {
    const list = state.contacts.filter((contact) => contact.favorite);

    if (list.length === 0) return [...title(t('tabs.favorites')), h('p', 'empty', t('favorites.empty'))];

    return [
        ...title(t('tabs.favorites')),
        h('div', 'list', null, list.map((contact) => button('item', null, () => dial(contact.number),
            h('span', 'avatar', initials(contact.name)),
            h('span', 'item__main', null, h('strong', '', contact.name), h('small', '', formatNumber(contact.number))),
            button('link', 'i', (event) => { event.stopPropagation(); openContact(contact); }),
        ))),
    ];
}

function ago(at) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000) - at);
    if (seconds < 3600) return t('time.minutes', Math.max(1, Math.floor(seconds / 60)));
    if (seconds < 86400) return t('time.hours', Math.floor(seconds / 3600));
    return t('time.days', Math.floor(seconds / 86400));
}

export function recents(render) {
    const clear = button('link', t('recents.clear'), async () => {
        if ((await call('clearRecents')).ok) {
            state.recents = [];
            render();
        }
    });

    if (state.recents.length === 0) return [...title(t('tabs.recents')), h('p', 'empty', t('recents.empty'))];

    return [
        ...title(t('tabs.recents'), clear),
        h('div', 'list', null, state.recents.map((entry) => {
            const missed = entry.direction === 'missed';
            const kind = t(`recents.${entry.direction}`);

            return button(`item${missed ? ' item--missed' : ''}`, null, () => entry.number && dial(entry.number),
                h('span', 'item__main', null, h('strong', '', nameFor(entry.number)), h('small', '', kind)),
                h('span', 'item__side', ago(entry.at)),
                entry.number && button('link', 'i', (event) => {
                    event.stopPropagation();
                    const contact = contactFor(entry.number);
                    if (contact) openContact(contact);
                    else editContact({ name: '', number: entry.number });
                }),
            );
        })),
    ];
}

const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

export function keypad(render) {
    const display = h('div', 'keypad__number', formatNumber(state.number) === t('unknown') ? '' : formatNumber(state.number));

    const press = (key) => {
        if (state.number.length >= 15) return;
        state.number += key;
        render();
    };

    const back = button('link', '⌫', () => {
        state.number = state.number.slice(0, -1);
        render();
    });

    const hide = button(`pill${state.hidden ? ' pill--on' : ''}`, t('keypad.hide'), () => {
        state.hidden = !state.hidden;
        render();
    });

    const add = state.number && !contactFor(state.number)
        ? button('link', t('keypad.add'), () => editContact({ name: '', number: state.number }))
        : null;

    return [h('div', 'keypad', null,
        display,
        add || h('span', 'link', ' '),
        h('div', 'keypad__grid', null, KEYS.map((key) => button('key', key, () => press(key)))),
        h('div', 'keypad__actions', null,
            hide,
            button('round round--green', '☎', () => state.number && dial(state.number.replace(/\D/g, ''))),
            state.number ? back : h('span'),
        ),
    )];
}
