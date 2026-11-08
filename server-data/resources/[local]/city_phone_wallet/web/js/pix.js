// Pix: pick the account to send from, type a phone or account number (the receiver's masked name is shown before
// confirming), the amount and an optional note. Limits are the bank's, checked on the server.
import { state, bank, t, h, button, input, toast, money, errorText, navBar } from './lib.js';

let checked = null; // { key, name, number } after a successful lookup

export function pix(render) {
    const from = h('select', 'k-field select');
    for (const account of state.accounts.filter((a) => a.perms?.transfer)) {
        from.append(new Option(`${account.label || t(`type.${account.type}`)} · ${money(account.balance)}`, account.id, false, state.account?.id === account.id));
    }

    const key = input('k-field', t('pix.key'), 20);
    const amount = input('k-field', t('pix.amount'), 9);
    const note = input('k-field', t('pix.note'), 60);
    amount.inputMode = 'numeric';
    amount.addEventListener('input', () => { amount.value = amount.value.replace(/\D/g, ''); });
    key.addEventListener('input', () => { checked = null; receiver.textContent = ''; });

    const receiver = h('div', 'receiver');

    const lookup = async () => {
        const reply = await bank('lookup', key.value.trim());
        if (!reply.ok) {
            checked = null;
            receiver.textContent = errorText(reply.error);
            receiver.className = 'receiver receiver--bad';
            return;
        }
        checked = { key: key.value.trim(), name: reply.name, number: reply.number };
        receiver.textContent = t('pix.to', reply.name, reply.number);
        receiver.className = 'receiver receiver--ok';
    };
    key.addEventListener('change', lookup);

    const send = async () => {
        if (!checked) await lookup();
        if (!checked) return;

        const value = Number(amount.value);
        if (!value) return toast(errorText('bad_amount'));

        const reply = await bank('send', Number(from.value), checked.key, value, note.value || null);
        if (!reply.ok) return toast(errorText(reply.error));

        toast(t('pix.sent', money(value), reply.name || checked.name));
        checked = null;
        state.tab = 'home';
        document.dispatchEvent(new CustomEvent('wallet:refresh'));
    };

    return [
        navBar(null, null, null),
        h('h1', 'k-large-title', t('tabs.pix')),
        h('div', 'k-group__label', t('pix.from')),
        h('div', 'k-group', null, from),
        h('div', 'k-group__label', t('pix.toLabel')),
        h('div', 'k-group', null, key),
        receiver,
        h('div', 'k-group', null, amount, note),
        button('k-button pix-send', t('pix.send'), send),
        h('p', 'muted small', t('pix.hint')),
    ];
}
