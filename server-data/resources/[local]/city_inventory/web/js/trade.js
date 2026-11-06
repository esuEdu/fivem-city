import { state, el } from './state.js';
import { buildGrid, setItems } from './slots.js';
import { post } from './util.js';

// The trade panel: your offer (drag items in and out; cash is the money item) and the other player's (read-only)

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

}

export function setTrade(data) {
    const firstTime = !state.trade.open || state.offer.slots !== data.slots;

    Object.assign(state.trade, {
        open: true,
        partner: data.partner,
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

    render();
}

export function clearTrade() {
    state.trade.open = false;
    state.offer.items.clear();
    state.their.items.clear();
    el.trade.offerGrid.replaceChildren();
    el.trade.theirGrid.replaceChildren();
}

el.trade.accept.addEventListener('click', () => post('tradeAccept', { accepted: !state.trade.accepted }));
el.trade.cancel.addEventListener('click', () => post('tradeCancel'));
