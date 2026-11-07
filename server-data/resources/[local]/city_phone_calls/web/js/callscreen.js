// The call screen over the app: incoming (answer / decline), calling (with the ringback tone) and in a call
// (timer, mute, add someone, end)
import { state, call, t, h, button, nameFor, toast, reasonText } from './lib.js';

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

function who(current) {
    const first = current.people[0];
    return first ? nameFor(first.number) : t('unknown');
}

function clock(since) {
    const seconds = Math.max(0, Math.floor(Date.now() / 1000) - since);
    return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

function roundButton(label, symbol, onClick, on = false) {
    return button(`call__button${on ? ' call__button--on' : ''}`, null, onClick, h('span', 'round', symbol), h('span', '', label));
}

async function addPerson() {
    const input = h('input', 'search');
    Object.assign(input, { placeholder: t('contacts.number'), maxLength: 15 });

    const sheet = document.getElementById('sheet');
    sheet.replaceChildren(
        h('div', 'head', null, button('link', t('contacts.cancel'), () => sheet.classList.remove('sheet--open')), button('link', t('call.add'), async () => {
            const result = await call('add', { number: input.value.replace(/\D/g, '') });
            if (!result.ok) return toast(reasonText(result.reason));
            sheet.classList.remove('sheet--open');
        })),
        h('h1', 'title', t('call.addTitle')),
        input,
    );
    sheet.classList.add('sheet--open');
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

    const status = h('div', 'call__status', t(`call.${current.status}`));
    const others = current.people.slice(1).map((person) => nameFor(person.number) + (person.ringing ? ` (${t('call.ringing')})` : ''));

    if (current.status === 'active' && current.since) {
        status.textContent = clock(current.since);
        timer = setInterval(() => { status.textContent = clock(current.since); }, 1000);
    }

    const buttons = current.status === 'incoming'
        ? h('div', 'call__incoming', null,
            roundButton(t('call.decline'), '✕', () => call('hangup')),
            roundButton(t('call.accept'), '☎', () => call('accept')),
        )
        : h('div', 'call__buttons', null,
            roundButton(t('call.mute'), muted ? '\u{1F507}' : '\u{1F3A4}', async () => {
                if ((await call('mute', { muted: !muted })).ok) {
                    muted = !muted;
                    renderCall();
                }
            }, muted),
            h('span'),
            current.status === 'active' ? roundButton(t('call.add'), '+', addPerson) : h('span'),
            button('call__end round round--red', '✕', () => call('hangup')),
        );

    // The incoming buttons: decline red, accept green
    if (current.status === 'incoming') {
        buttons.children[0].querySelector('.round').classList.add('round--red');
        buttons.children[1].querySelector('.round').classList.add('round--green');
    }

    node.replaceChildren(...[
        h('div', 'call__who', who(current)),
        status,
        others.length ? h('div', 'call__people', others.join(' · ')) : null,
        buttons,
    ].filter(Boolean));
    node.classList.add('call--open');
}
