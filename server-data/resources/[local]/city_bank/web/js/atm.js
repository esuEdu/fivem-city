import { post, h, label, money, errorText, button, input, whole } from './util.js';

// ATM / cash desk: choose a card from the inventory -> PIN keypad -> balance (eye), withdraw, deposit
const QUICK = [100, 500, 1000, 5000];

const root = () => document.getElementById('atm');

let atm = { cards: [], teller: false, card: null, onBack: null };

function screen(title, ...children) {
    root().replaceChildren(h('div', { className: 'atm__machine' },
        h('header', { className: 'atm__header' },
            h('span', { className: 'atm__brand', text: label(atm.teller ? 'cash_desk' : 'atm_title') }),
            atm.teller && atm.onBack ? button(label('back'), async () => { await post('tellerBack'); atm.onBack(); }) : null,
            button(label('close'), () => post('close'))),
        h('div', { className: 'atm__screen' }, h('h2', { className: 'atm__title', text: title }), children)));
}

function message(text, kind = '') {
    return h('p', { className: `atm__message ${kind}`, text });
}

function chooseCard(note) {
    screen(label('atm_choose'),
        note ? message(note, 'is-error') : null,
        h('div', { className: 'atm__cards' }, atm.cards.map((card) => h('button', {
            className: 'atm__card', type: 'button',
            onClick: () => pinPad(card),
        }, h('span', { className: 'bank-card__chip' }), h('span', { className: 'mono', text: `•••• ${card.last4}` }), h('span', { className: 'row__sub', text: card.label })))),
        atm.cards.length === 0 ? message(label('error_no_card'), 'is-error') : null);
}

function pinPad(card, note) {
    let pin = '';
    const dots = h('div', { className: 'pin__dots' });
    const draw = () => dots.replaceChildren(...[0, 1, 2, 3].map((i) => h('span', { className: `pin__dot ${i < pin.length ? 'is-on' : ''}` })));

    const submit = async () => {
        const reply = await post('atmAuth', { slot: card.slot, pin });
        if (reply && reply.ok) { atm.card = { ...card, holder: reply.holder }; return menu(); }

        const text = reply?.error === 'wrong_pin' ? label('wrong_pin', reply.triesLeft) : errorText(reply?.error);
        if (reply?.error === 'card_locked' || reply?.error === 'card_blocked') return chooseCard(text);
        pinPad(card, text);
    };

    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', 'OK'].map((key) => h('button', {
        className: `pin__key ${key === 'OK' ? 'pin__key--ok' : ''}`, type: 'button', text: key,
        onClick: () => {
            if (key === 'C') pin = '';
            else if (key === 'OK') { if (pin.length === 4) submit(); return; }
            else if (pin.length < 4) pin += key;
            draw();
        },
    }));

    draw();
    screen(label('atm_pin', card.last4), note ? message(note, 'is-error') : null, dots, h('div', { className: 'pin__pad' }, keys));
}

function amountScreen(kind, note) {
    const custom = input({ type: 'number', min: 1, placeholder: label('amount') });
    const go = async (amount) => {
        const reply = await post('atmMove', { kind, amount });
        if (reply && reply.ok) return menu(label(kind === 'deposit' ? 'atm_deposited' : 'atm_withdrawn', money(amount)));
        amountScreen(kind, errorText(reply?.error));
    };

    screen(label(kind === 'deposit' ? 'deposit' : 'withdraw'),
        note ? message(note, 'is-error') : null,
        kind === 'withdraw' ? h('div', { className: 'atm__quick' }, QUICK.map((value) => button(money(value), () => go(value)))) : null,
        h('div', { className: 'inline' }, custom, button(label('confirm'), () => { const value = whole(custom); if (value) go(value); }, 'primary')),
        button(label('back'), () => menu()));
}

function menu(note) {
    const balance = h('span', { className: 'atm__balance mono', text: '••••••' });

    // The eye asks the server; only the account's owner or members get the balance back
    const eye = button(label('show_balance'), async () => {
        const reply = await post('atmPeek');
        balance.textContent = reply && reply.ok ? money(reply.balance) : label('fingerprint_invalid');
        balance.classList.toggle('is-error', !(reply && reply.ok));
    });

    screen(label('atm_card', atm.card.last4),
        note ? message(note, 'is-success') : null,
        h('div', { className: 'atm__balance-row' }, balance, eye),
        h('div', { className: 'atm__menu' },
            button(label('withdraw'), () => amountScreen('withdraw'), 'primary'),
            button(label('deposit'), () => amountScreen('deposit')),
            button(label('finish'), () => post('close'))));
}

export function openAtm(message, show, onBack) {
    atm = { cards: message.cards || [], teller: Boolean(message.teller), card: null, onBack: onBack || null };
    show();
    chooseCard();
}
