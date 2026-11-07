// Cards: each card the player holds or manages; block it right away (stolen or lost), contactless on/off, and new
// limits within the card's ceilings (they take effect after the bank's delay)
import { state, bank, t, h, button, input, toast, openSheet, closeSheet, money, errorText, navBar, backButton } from './lib.js';

const LIMIT_KEYS = ['debitDay', 'creditDay', 'contactlessTx', 'contactlessDay'];

async function reload(render) {
    const reply = await bank('cards');
    state.cards = reply.ok ? reply.cards || [] : [];
    render();
}

function limitsSheet(card, render) {
    const fields = {};

    const rows = LIMIT_KEYS.filter((k) => card.ceilings?.[k] != null).map((k) => {
        const field = input('k-field', '', 9);
        field.value = card.limits?.[k] ?? '';
        field.inputMode = 'numeric';
        field.addEventListener('input', () => { field.value = field.value.replace(/\D/g, ''); });
        fields[k] = field;

        return h('div', 'limit', null,
            h('div', 'limit__label', null, h('span', '', t(`limits.${k}`)), h('span', 'muted', t('limits.max', money(card.ceilings[k])))),
            field,
        );
    });

    const save = async () => {
        const requested = {};
        for (const [k, field] of Object.entries(fields)) requested[k] = Number(field.value) || 0;

        const reply = await bank('cardLimits', card.id, requested);
        if (!reply.ok) return toast(errorText(reply.error));

        toast(t('limits.saved'));
        closeSheet();
        reload(render);
    };

    openSheet(
        navBar(backButton(t('tabs.cards'), closeSheet), t('limits.title'), button('k-link', t('save'), save)),
        h('p', 'muted small', t('limits.hint')),
        h('div', 'k-group', null, rows),
    );
}

function cardView(card, render) {
    const active = card.status === 'active';

    const contactless = h('span', `switch${card.contactless ? ' switch--on' : ''}`);
    contactless.addEventListener('click', async () => {
        if (!active) return;
        const reply = await bank('cardContactless', card.id, !card.contactless);
        if (!reply.ok) return toast(errorText(reply.error));
        reload(render);
    });

    const block = async () => {
        const reply = await bank('blockCard', card.id);
        toast(reply.ok ? t('cards.blocked') : errorText(reply.error));
        reload(render);
    };

    return h('div', 'card-block', null,
        h('div', `bankcard bankcard--${card.status}`, null,
            h('span', 'bankcard__brand', 'City Bank'),
            h('span', 'bankcard__number', `•••• •••• •••• ${card.last4}`),
            h('span', 'bankcard__bottom', null, h('span', '', card.holder), h('span', '', card.account)),
            !active ? h('span', 'bankcard__status', t(`cards.status.${card.status}`)) : null,
        ),
        active ? h('div', 'k-group', null,
            h('div', 'k-row', null, h('span', '', t('cards.contactless')), contactless),
            button('k-row', null, () => limitsSheet(card, render), h('span', '', t('cards.limits')),
                h('span', 'k-row__value', card.pending ? t('cards.pending') : t('cards.edit'))),
            button('k-row k-row--danger', t('cards.block'), () => openSheet(
                navBar(backButton(t('tabs.cards'), closeSheet), null, null),
                h('h1', 'k-large-title', t('cards.blockTitle')),
                h('p', 'muted', t('cards.blockText', card.last4)),
                button('k-button danger-button', t('cards.blockConfirm'), async () => { closeSheet(); await block(); }),
            )),
        ) : h('p', 'muted small', t('cards.branch')),
    );
}

export function cards(render) {
    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('tabs.cards')),
        state.cards.length ? state.cards.map((card) => cardView(card, render)) : h('div', 'k-empty', null, h('span', '', t('cards.none'))),
    ];
}

export { reload as reloadCards };
