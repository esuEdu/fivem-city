import { state, el } from './state.js';
import { buildGrid, setItems } from './slots.js';
import { post } from './util.js';

// The trade panel: your offer (you can drag items in and out and set cash) and the other player's (read-only)

function render() {
    const { trade, labels } = state;

    el.trade.title.textContent = labels.trade;
    el.trade.partner.textContent = trade.partner;
    el.trade.cancel.textContent = labels.cancel;
    el.trade.offerTitle.textContent = labels.yourOffer;
    el.trade.theirTitle.textContent = labels.theirOffer;

    el.trade.accept.textContent = trade.accepted ? `${labels.accepted} ✓` : labels.accept;
    el.trade.accept.classList.toggle('button--done', trade.accepted);

    for (const [status, accepted] of [[el.trade.offerStatus, trade.accepted], [el.trade.theirStatus, trade.theirAccepted]]) {
        status.textContent = accepted ? labels.accepted : labels.waiting;
        status.classList.toggle('status--done', accepted);
    }

    // Don't overwrite what the player is typing
    if (document.activeElement !== el.trade.cash) el.trade.cash.value = trade.cash;
    el.trade.theirCash.textContent = trade.theirCash.toLocaleString();
}

export function setTrade(data) {
    const firstTime = !state.trade.open || state.offer.slots !== data.slots;

    Object.assign(state.trade, {
        open: true,
        partner: data.partner,
        cash: data.cash,
        theirCash: data.theirCash,
        accepted: data.accepted,
        theirAccepted: data.theirAccepted,
    });

    state.offer.slots = data.slots;
    state.their.slots = data.slots;
    setItems('offer', data.offer);
    setItems('their', data.their);

    // The offers are small, so both grids are simply rebuilt
    buildGrid('offer', el.trade.offerGrid);
    buildGrid('their', el.trade.theirGrid);
    if (firstTime) el.trade.cash.value = data.cash;

    render();
}

export function clearTrade() {
    state.trade.open = false;
    state.offer.items.clear();
    state.their.items.clear();
    el.trade.offerGrid.replaceChildren();
    el.trade.theirGrid.replaceChildren();
}

function sendCash() {
    const amount = Math.max(0, Number.parseInt(el.trade.cash.value, 10) || 0);
    if (amount !== state.trade.cash) post('tradeCash', { amount });
}

el.trade.cash.addEventListener('change', sendCash);
el.trade.cash.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') el.trade.cash.blur();
});

el.trade.accept.addEventListener('click', () => post('tradeAccept', { accepted: !state.trade.accepted }));
el.trade.cancel.addEventListener('click', () => post('tradeCancel'));
