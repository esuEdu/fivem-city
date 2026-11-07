// The city services (police, EMS, mechanic): fixed contacts that can't be edited or deleted. Calling one opens a
// form for the call (what kind, what happened, anonymous) that goes to the service with your location.
import {
    state, call, t, h, button, icon, avatar, toast, openSheet, closeSheet, navBar, backButton, formatNumber,
} from './lib.js';

const LOOK = {
    police: { icon: 'shield', color: 'linear-gradient(180deg, #3d6bc4, #1f3b73)' },
    ems: { icon: 'medical', color: 'linear-gradient(180deg, #ff6b6b, #d70015)' },
    mechanic: { icon: 'wrench', color: 'linear-gradient(180deg, #ffc94d, #e09600)' },
};

export function serviceFor(number) {
    return number ? state.services.find((service) => service.number === number) : null;
}

export function serviceName(service) {
    return t(`service.${service.id}`);
}

function serviceAvatar(service, size = '') {
    const look = LOOK[service.id] || { icon: 'phone' };
    const node = avatar(service.id, size, look.icon);
    if (look.color) node.style.background = look.color;
    return node;
}

function checkRow(label, on, onClick) {
    const mark = h('span', `k-check${on ? ' k-check--on' : ''}`, null, icon('check'));
    const row = button('k-row', null, onClick, h('span', '', label), mark);
    row.mark = mark;
    return row;
}

// The call form. Nothing is sent until the player picks what kind of call it is.
export function reportSheet(service) {
    let kind = null;
    let anonymous = false;
    let sending = false;

    const text = document.createElement('textarea');
    text.className = 'k-field report__text';
    text.maxLength = 200;
    text.placeholder = t('report.placeholder');

    const kinds = service.types.map((type) => {
        const row = checkRow(t(`type.${type}`), false, () => {
            kind = type;
            kinds.forEach((other) => other.mark.classList.toggle('k-check--on', other === row));
        });
        return row;
    });

    const anonymousRow = checkRow(t('report.anonymous'), false, () => {
        anonymous = !anonymous;
        anonymousRow.mark.classList.toggle('k-check--on', anonymous);
    });

    const send = button('k-link', t('report.send'), async () => {
        if (sending) return;
        if (!kind) return toast(t('report.pickType'));

        sending = true;
        const result = await call('report', { service: service.id, kind, text: text.value, anonymous });
        sending = false;

        if (!result.ok) return toast(t(`report.reason.${result.reason || 'invalid'}`));

        closeSheet();
        toast(t('report.sent'));
    });

    openSheet(
        navBar(button('k-link', t('contacts.cancel'), closeSheet), t('report.title', service.number), send),
        h('div', 'card', null, serviceAvatar(service, 'big'), h('div', 'card__name', serviceName(service))),
        h('p', 'k-group__label', t('report.kind')),
        h('div', 'k-group', null, kinds),
        h('p', 'k-group__label', t('report.what')),
        h('div', 'k-group', null, text),
        h('div', 'k-group', null, anonymousRow),
        h('p', 'report__hint', t(anonymous ? 'report.hintAnonymous' : 'report.hint')),
    );
}

function openService(service) {
    openSheet(
        navBar(backButton(t('tabs.contacts'), closeSheet), null, null),
        h('div', 'card', null, serviceAvatar(service, 'big'), h('div', 'card__name', serviceName(service))),
        h('div', 'actions', null,
            button('action', null, () => reportSheet(service), icon('phone'), h('span', '', t('contacts.call'))),
        ),
        h('div', 'k-group', null,
            h('div', 'k-row', null, h('span', '', t('service.label')), h('span', 'k-row__value', formatNumber(service.number))),
        ),
    );
}

// Shown above the contacts list
export function serviceRows() {
    if (!state.services.length) return [];

    return [
        h('p', 'k-group__label services__label', t('service.title')),
        h('div', 'k-list', null, state.services.map((service) => button('k-item', null, () => openService(service),
            serviceAvatar(service, 'small'),
            h('span', 'k-item__main', null, h('span', 'k-item__title', serviceName(service))),
            h('span', 'distance', service.number),
        ))),
    ];
}
