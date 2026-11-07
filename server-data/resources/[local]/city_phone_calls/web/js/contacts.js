// Contacts tab, a contact's page, the edit form, blocked numbers and sharing your own contact
import { state, call, t, h, button, formatNumber, initials, toast } from './lib.js';
import { dial } from './tabs.js';

let refresh = () => {};

export function setRefresh(fn) {
    refresh = fn;
}

function sheet(...children) {
    const node = document.getElementById('sheet');
    node.replaceChildren(...children.flat(Infinity).filter(Boolean));
    node.classList.add('sheet--open');
}

export function closeSheet() {
    document.getElementById('sheet').classList.remove('sheet--open');
}

function back(label = t('tabs.contacts'), onClick = closeSheet) {
    return h('div', 'head', null, button('link', `‹ ${label}`, onClick), h('span'));
}

export function editContact(contact) {
    const name = h('input', 'field');
    const number = h('input', 'field');

    Object.assign(name, { placeholder: t('contacts.name'), value: contact.name || '', maxLength: 30 });
    Object.assign(number, { placeholder: t('contacts.number'), value: contact.number || '', maxLength: 15 });
    number.addEventListener('input', () => { number.value = number.value.replace(/\D/g, ''); });

    const save = button('link', t('contacts.save'), async () => {
        const result = await call('saveContact', { contact: { id: contact.id, name: name.value, number: number.value, favorite: contact.favorite } });
        if (!result.ok) return toast(t(result.reason === 'full' ? 'contacts.full' : 'contacts.invalid'));

        closeSheet();
        await refresh();
    });

    sheet(
        h('div', 'head', null, button('link', t('contacts.cancel'), closeSheet), save),
        h('h1', 'title', contact.id ? t('contacts.edit') : t('contacts.new')),
        h('div', 'group', null, name, number),
    );
}

async function block(number, blocked) {
    if ((await call('block', { number, blocked })).ok) {
        toast(t(blocked ? 'contacts.blocked' : 'contacts.unblocked'));
        await refresh();
    }
}

export function openContact(contact) {
    const isBlocked = state.blocked.includes(contact.number);

    const favorite = async () => {
        await call('saveContact', { contact: { ...contact, favorite: !contact.favorite } });
        contact.favorite = !contact.favorite;
        await refresh();
        openContact(contact);
    };

    sheet(
        back(),
        h('div', 'card', null, h('span', 'avatar avatar--big', initials(contact.name)), h('h2', '', contact.name), h('span', 'item__side', formatNumber(contact.number))),
        h('div', 'actions', null,
            button('action', null, () => dial(contact.number), h('span', '', '☎'), h('span', '', t('contacts.call'))),
            button('action', null, favorite, h('span', '', contact.favorite ? '★' : '☆'), h('span', '', t('contacts.favorite'))),
            button('action', null, () => editContact(contact), h('span', '', '✎'), h('span', '', t('contacts.edit'))),
        ),
        h('div', 'group', null,
            button('row row--danger', t(isBlocked ? 'contacts.unblock' : 'contacts.block'), async () => { await block(contact.number, !isBlocked); closeSheet(); }),
            button('row row--danger', t('contacts.delete'), async () => {
                if ((await call('deleteContact', { id: contact.id })).ok) {
                    closeSheet();
                    await refresh();
                }
            }),
        ),
    );
}

function blockedPage() {
    sheet(
        back(),
        h('h1', 'title', t('contacts.blockedTitle')),
        state.blocked.length === 0
            ? h('p', 'empty', t('contacts.noneBlocked'))
            : h('div', 'group', null, state.blocked.map((number) => button('row', formatNumber(number), async () => { await block(number, false); blockedPage(); },
                h('span', 'row--link', t('contacts.unblock'))))),
    );
}

// Sharing: the people close by have no names, only how far they are
async function sharePage() {
    const result = await call('nearby');
    const people = result.ok ? result.result : [];

    sheet(
        back(),
        h('h1', 'title', t('share.title')),
        h('p', 'item__side', t('share.hint')),
        people.length === 0
            ? h('p', 'empty', t('share.nobody'))
            : h('div', 'group', null, people.map((person, index) => button('row', t('share.person', index + 1), async () => {
                const sent = await call('share', { target: person.id });
                toast(t(sent.ok ? 'share.sent' : 'share.failed'));
                if (sent.ok) closeSheet();
            }, h('span', 'item__side', `${person.distance} m`)))),
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
            rows.push(h('div', 'letter', letter));
        }
        rows.push(button('item', null, () => openContact(contact),
            h('span', 'avatar', initials(contact.name)),
            h('span', 'item__main', null, h('strong', '', contact.name)),
        ));
    }

    return [
        h('div', 'head', null, button('link', t('contacts.blockedTitle'), blockedPage), button('link link--big', '+', () => editContact({}))),
        h('h1', 'title', t('tabs.contacts')),
        search,
        button('item', null, sharePage,
            h('span', 'avatar', initials(t('contacts.me'))),
            h('span', 'item__main', null, h('strong', '', t('contacts.myCard')), h('small', '', formatNumber(state.myNumber))),
            h('span', 'link', t('share.button')),
        ),
        rows.length ? h('div', 'list', null, rows) : h('p', 'empty', t('contacts.empty')),
    ];
}
