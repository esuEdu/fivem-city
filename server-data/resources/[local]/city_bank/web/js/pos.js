import { post, h, label, money, errorText, button } from './util.js';

// Customer side of the card machine: drag a card to the top (tap, contactless) or into the slot at the bottom
// (chip + PIN). Clicking a card and then a zone works too.
const root = () => document.getElementById('pos');

let pos = { charge: null, cards: [], mode: 'debit', selected: null };

function display(...lines) {
    return h('div', { className: 'pos__display' }, lines);
}

function render(note, kind = '') {
    const charge = pos.charge;

    const cardNodes = pos.cards.map((card) => h('button', {
        className: `pos__card ${pos.selected === card ? 'is-selected' : ''}`,
        type: 'button', draggable: true,
        onClick: () => { pos.selected = card; render(); },
        onDragstart: (event) => { pos.selected = card; event.dataTransfer.setData('text/plain', String(card.slot)); },
    }, h('span', { className: 'bank-card__chip' }), h('span', { className: 'mono', text: `•••• ${card.last4}` })));

    const zone = (method, text) => h('div', {
        className: `pos__zone pos__zone--${method}`,
        text,
        onDragover: (event) => event.preventDefault(),
        onDrop: (event) => { event.preventDefault(); use(method); },
        onClick: () => use(method),
    });

    root().replaceChildren(h('div', { className: 'pos__wrap' },
        h('div', { className: 'pos__machine' },
            zone('tap', label('pos_tap')),
            display(
                h('span', { className: 'pos__merchant', text: charge.merchant }),
                h('span', { className: 'pos__amount mono', text: money(charge.amount) }),
                note ? h('span', { className: `pos__note ${kind}`, text: note }) : h('span', { className: 'pos__note', text: label(`pos_mode_${pos.mode}`) })),
            h('div', { className: 'pos__modes' },
                ['debit', 'credit'].map((mode) => h('button', {
                    className: `pos__mode ${pos.mode === mode ? 'is-active' : ''}`, type: 'button', text: label(mode),
                    onClick: () => { pos.mode = mode; render(); },
                }))),
            zone('chip', label('pos_insert'))),
        h('div', { className: 'pos__side' },
            h('p', { className: 'eyebrow', text: label('pos_your_cards') }),
            pos.cards.length ? h('div', { className: 'pos__cards' }, cardNodes) : h('p', { className: 'muted', text: label('error_no_card') }),
            h('p', { className: 'muted', text: label('pos_hint') }),
            button(label('decline'), () => post('close'), 'danger'))));
}

function pinScreen(note) {
    let pin = '';
    const dots = h('div', { className: 'pin__dots' });
    const draw = () => dots.replaceChildren(...[0, 1, 2, 3].map((i) => h('span', { className: `pin__dot ${i < pin.length ? 'is-on' : ''}` })));

    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'C', '0', 'OK'].map((key) => h('button', {
        className: `pin__key ${key === 'OK' ? 'pin__key--ok' : ''}`, type: 'button', text: key,
        onClick: () => {
            if (key === 'C') pin = '';
            else if (key === 'OK') { if (pin.length === 4) pay('chip', pin); return; }
            else if (pin.length < 4) pin += key;
            draw();
        },
    }));

    draw();
    root().replaceChildren(h('div', { className: 'pos__wrap' }, h('div', { className: 'pos__machine' },
        display(
            h('span', { className: 'pos__amount mono', text: money(pos.charge.amount) }),
            h('span', { className: `pos__note ${note ? 'is-error' : ''}`, text: note || label('pos_enter_pin') })),
        dots,
        h('div', { className: 'pin__pad' }, keys),
        button(label('back'), () => render()))));
}

async function pay(method, pin) {
    const reply = await post('posPay', { slot: pos.selected.slot, method, mode: pos.mode, pin });

    if (reply && reply.ok) {
        root().replaceChildren(h('div', { className: 'pos__wrap' }, h('div', { className: 'pos__machine' },
            display(h('span', { className: 'pos__amount mono', text: money(pos.charge.amount) }), h('span', { className: 'pos__note is-success', text: label('pos_approved') })),
            button(label('close'), () => post('close'), 'primary'))));
        return;
    }

    const text = reply?.error === 'wrong_pin' ? label('wrong_pin', reply.triesLeft) : errorText(reply?.error);

    if (method === 'chip' && reply?.error === 'wrong_pin') return pinScreen(text);
    render(text, 'is-error');
}

function use(method) {
    if (!pos.selected) return render(label('pos_pick_card'), 'is-error');
    if (method === 'chip') return pinScreen();
    pay('tap');
}

export function openPos(message, show) {
    pos = { charge: message.charge, cards: message.cards || [], mode: 'debit', selected: null };
    show();
    render();
}
