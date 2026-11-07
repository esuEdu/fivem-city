// The call screen over the app: incoming (answer / decline), calling (with the ringback tone) and in a call
// (timer, mute, add someone, end)
import {
    state, call, t, h, button, icon, input, avatar, toast, openSheet, closeSheet, navBar, nameFor, reasonText,
} from './lib.js';

let timer = null;
let muted = false;
let ringback = null;

function startRingback() {
    if (ringback) return;

    const context = new AudioContext();
    const play = () => {
        const osc = context.createOscillator();
        const gain = context.createGain();
        osc.frequency.value = 425;
        gain.gain.value = 0.08;
        osc.connect(gain).connect(context.destination);
        osc.start();
        osc.stop(context.currentTime + 1);
    };

    play();
    ringback = { context, interval: setInterval(play, 4000) };
}

function stopRingback() {
    if (!ringback) return;
    clearInterval(ringback.interval);
    ringback.context.close();
    ringback = null;
}

function clock(since) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000) - since);
    return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

function roundButton(label, iconName, onClick, extra = '') {
    return button(`call__button ${extra}`, null, onClick, h('span', `round ${extra.includes('--red') ? 'round--red' : ''} ${extra.includes('--green') ? 'round--green' : ''}`, null, icon(iconName)), label ? h('span', '', label) : null);
}

function addPerson() {
    const number = input('k-field', t('contacts.number'), 15);

    openSheet(
        navBar(button('k-link', t('contacts.cancel'), closeSheet), t('call.addTitle'), button('k-link', t('call.add'), async () => {
            const result = await call('add', { number: number.value.replace(/\D/g, '') });
            if (!result.ok) return toast(reasonText(result.reason));
            closeSheet();
        })),
        h('div', 'k-group', null, number),
    );
}

export function renderCall() {
    const node = document.getElementById('call');
    const current = state.call;

    clearInterval(timer);

    if (!current) {
        stopRingback();
        muted = false;
        node.classList.remove('call--open');
        return;
    }

    if (current.status === 'calling') startRingback();
    else stopRingback();

    const first = current.people[0];
    const who = first ? nameFor(first.number) : t('unknown');
    const status = h('div', 'call__status', t(`call.${current.status}`));
    const others = current.people.slice(1).map((person) => nameFor(person.number) + (person.ringing ? ` (${t('call.ringing')})` : ''));

    if (current.status === 'active' && current.since) {
        status.textContent = clock(current.since);
        timer = setInterval(() => { status.textContent = clock(current.since); }, 1000);
    }

    const buttons = current.status === 'incoming'
        ? h('div', 'call__incoming', null,
            roundButton(t('call.decline'), 'hangup', () => call('hangup'), 'call__button--red'),
            roundButton(t('call.accept'), 'phone', () => call('accept'), 'call__button--green'),
        )
        : h('div', 'call__buttons', null,
            roundButton(t('call.mute'), muted ? 'micOff' : 'mic', async () => {
                if ((await call('mute', { muted: !muted })).ok) {
                    muted = !muted;
                    renderCall();
                }
            }, muted ? 'call__button--on' : ''),
            h('span'),
            current.status === 'active' ? roundButton(t('call.add'), 'plus', addPerson) : h('span'),
            roundButton(null, 'hangup', () => call('hangup'), 'call__end call__button--red'),
        );

    node.replaceChildren(...[
        avatar(who === t('unknown') ? '?' : who, 'big'),
        h('div', 'call__who', who),
        status,
        others.length ? h('div', 'call__people', others.join(' · ')) : null,
        buttons,
    ].filter(Boolean));
    node.classList.add('call--open');
}
