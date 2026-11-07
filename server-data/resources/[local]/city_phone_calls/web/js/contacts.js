// Contacts tab, a contact's page, the edit form, blocked numbers and sharing your own contact
import {
    state, call, t, h, button, icon, input, avatar, toast, openSheet, closeSheet, navBar, backButton, formatNumber,
} from './lib.js';
import { dial } from './tabs.js';

let refresh = () => {};

export { closeSheet };

export function setRefresh(fn) {
    refresh = fn;
}

export function editContact(contact) {
    const name = input('k-field', t('contacts.name'), 30);
    const number = input('k-field', t('contacts.number'), 15);

    name.value = contact.name || '';
    number.value = contact.number || '';
    number.addEventListener('input', () => { number.value = number.value.replace(/\D/g, ''); });

    const save = button('k-link', t('contacts.save'), async () => {
        const result = await call('saveContact', { contact: { id: contact.id, name: name.value, number: number.value, favorite: contact.favorite } });
        if (!result.ok) return toast(t(result.reason === 'full' ? 'contacts.full' : 'contacts.invalid'));

        closeSheet();
        await refresh();
    });

    openSheet(
        navBar(button('k-link', t('contacts.cancel'), closeSheet), contact.id ? t('contacts.edit') : t('contacts.new'), save),
        h('div', 'card', null, avatar(contact.name || '?', 'big')),
        h('div', 'k-group', null, name, number),
    );
}

async function block(number, blocked) {
    if ((await call('block', { number, blocked })).ok) {
        toast(t(blocked ? 'contacts.blocked' : 'contacts.unblocked'));
        await refresh();
    }
}

function action(iconName, label, onClick) {
    return button('action', null, onClick, icon(iconName), h('span', '', label));
}

// Sharing your contact: the people close by have no names, only how far they are
async function sharePage() {
    const result = await call('nearby');
    const people = result.ok ? result.result : [];

    openSheet(
        navBar(backButton(t('tabs.contacts'), closeSheet), t('share.title'), null),
        h('p', 'k-group__label', t('share.hint')),
        people.length === 0
            ? h('div', 'k-empty', null, icon('person'), h('span', '', t('share.nobody')))
            : h('div', 'k-group', null, people.map((person, index) => button('k-row', null, async () => {
                const sent = await call('share', { target: person.id });
                toast(t(sent.ok ? 'share.sent' : 'share.failed'));
                if (sent.ok) closeSheet();
            }, h('span', '', t('share.person', index + 1)), h('span', 'distance', `${person.distance} m`)))),
    );
}

export function openContact(contact) {
    const isBlocked = state.blocked.includes(contact.number);

    const favorite = async () => {
        await call('saveContact', { contact: { ...contact, favorite: !contact.favorite } });
        contact.favorite = !contact.favorite;
        await refresh();
        openContact(contact);
    };

    openSheet(
        navBar(backButton(t('tabs.contacts'), closeSheet), null, button('k-link', t('contacts.edit'), () => editContact(contact))),
        h('div', 'card', null, avatar(contact.name, 'big'), h('div', 'card__name', contact.name)),
        h('div', 'actions', null,
            action('phone', t('contacts.call'), () => dial(contact.number)),
            action('message', t('contacts.message'), () => call('message', { number: contact.number })),
            action(contact.favorite ? 'starFilled' : 'star', t('contacts.favorite'), favorite),
            action('share', t('share.button'), sharePage),
        ),
        h('div', 'k-group', null,
            h('div', 'k-row', null, h('span', '', t('mobile')), h('span', 'k-row__value', formatNumber(contact.number))),
        ),
        h('div', 'k-group', null,
            button('k-row k-row--danger', t(isBlocked ? 'contacts.unblock' : 'contacts.block'), async () => { await block(contact.number, !isBlocked); closeSheet(); }),
            button('k-row k-row--danger', t('contacts.delete'), async () => {
                if ((await call('deleteContact', { id: contact.id })).ok) {
                    closeSheet();
                    await refresh();
                }
            }),
        ),
    );
}

function blockedPage() {
    openSheet(
        navBar(backButton(t('tabs.contacts'), closeSheet), t('contacts.blockedTitle'), null),
        state.blocked.length === 0
            ? h('div', 'k-empty', null, icon('block'), h('span', '', t('contacts.noneBlocked')))
            : h('div', 'k-group', null, state.blocked.map((number) => h('div', 'k-row', null,
                h('span', '', formatNumber(number)),
                button('k-link', t('contacts.unblock'), async () => { await block(number, false); blockedPage(); }),
            ))),
    );
}

export function contacts(render, search) {
    const query = (search.value || '').toLowerCase();
    const list = state.contacts.filter((contact) => contact.name.toLowerCase().includes(query) || contact.number.includes(query));
    const rows = [];
    let letter = '';

    for (const contact of list) {
        const first = contact.name[0]?.toUpperCase() || '#';
        if (first !== letter) {
            letter = first;
            rows.push(h('div', 'k-section-letter', letter));
        }
        rows.push(button('k-item', null, () => openContact(contact),
            avatar(contact.name, 'small'),
            h('span', 'k-item__main', null, h('span', 'k-item__title', contact.name)),
        ));
    }

    return [
        navBar(button('k-link', t('contacts.blockedTitle'), blockedPage), null, button('k-link', null, () => editContact({}), icon('plus'))),
        h('h1', 'k-large-title', t('tabs.contacts')),
        h('label', 'k-search', null, icon('search'), search),
        button('k-item', null, sharePage,
            avatar(t('contacts.me')),
            h('span', 'k-item__main', null, h('span', 'k-item__title', t('contacts.myCard')), h('span', 'k-item__subtitle', formatNumber(state.myNumber))),
            h('span', 'k-link', null, icon('share')),
        ),
        rows.length ? h('div', 'k-list', null, rows) : h('div', 'k-empty', null, icon('person'), h('span', '', t('contacts.empty'))),
    ];
}
