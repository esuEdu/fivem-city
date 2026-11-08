import { el, icon, post, money, initials, confirmModal } from './util.js';

const root = document.getElementById('select');
const slotsNode = document.getElementById('slots');
const details = document.getElementById('details');
const playButton = document.getElementById('play');
const deleteButton = document.getElementById('delete');

let state = { characters: [], slots: 0, canDelete: false, selected: null };

function fact(label, value) {
    const row = el('div', 'fact');
    row.append(el('span', '', label), el('span', '', value || '—'));
    return row;
}

function lastPlayed(unix) {
    if (!unix) return 'Never';
    const days = Math.floor((Date.now() / 1000 - unix) / 86400);
    if (days <= 0) return 'Today';
    if (days === 1) return 'Yesterday';
    return `${days} days ago`;
}

function renderDetails() {
    details.replaceChildren();
    const character = state.characters.find((c) => c.citizenid === state.selected);

    if (!character) {
        const empty = el('div', 'details__empty');
        empty.append(el('p', 'kicker', 'Empty slot'), el('h3', '', 'A new story'), el('p', 'muted', 'Create someone new: shape their face, pick their style and give them a name.'));
        details.append(empty);
        return;
    }

    details.append(el('p', 'kicker', character.job + (character.grade ? ` · ${character.grade}` : '')));
    details.append(el('h2', 'details__name', `${character.firstname} ${character.lastname}`));
    details.append(el('p', 'details__id', character.citizenid));

    const moneyRow = el('div', 'details__money');
    const cash = el('div', 'money');
    cash.append(el('div', 'money__label', 'Cash'), el('div', 'money__value', money(character.cash)));
    const bank = el('div', 'money');
    bank.append(el('div', 'money__label', 'Bank'), el('div', 'money__value money__value--accent', money(character.bank)));
    moneyRow.append(cash, bank);
    details.append(moneyRow);

    const facts = el('div', 'facts');
    facts.append(
        fact('Born', character.birthdate),
        fact('Nationality', character.nationality),
        fact('Phone', character.phone),
        fact('Last played', lastPlayed(character.lastPlayed)),
    );
    details.append(facts);
}

function select(citizenid) {
    state.selected = citizenid;
    slotsNode.querySelectorAll('.slot').forEach((node) => {
        node.classList.toggle('is-active', node.dataset.id === (citizenid || 'new'));
    });

    const character = state.characters.find((c) => c.citizenid === citizenid);
    playButton.textContent = character ? (character.hasLook ? 'Play' : 'Finish look') : 'Create character';
    deleteButton.classList.toggle('hidden', !character || !state.canDelete);

    renderDetails();
    post('select:preview', { citizenid: citizenid || null });
}

function renderSlots() {
    slotsNode.replaceChildren();

    state.characters.forEach((character, index) => {
        const slot = el('div', 'slot');
        slot.dataset.id = character.citizenid;
        slot.style.animationDelay = `${index * 60}ms`;

        const main = el('div', 'slot__main');
        main.append(
            el('div', 'slot__name', `${character.firstname} ${character.lastname}`),
            el('div', 'slot__meta', character.job + (character.grade ? ` · ${character.grade}` : '')),
        );

        slot.append(el('div', 'avatar', initials(character.firstname, character.lastname)), main);
        if (!character.hasLook) slot.append(el('span', 'badge', 'No look yet'));

        slot.addEventListener('click', () => select(character.citizenid));
        slot.addEventListener('dblclick', () => play());
        slotsNode.append(slot);
    });

    const free = state.slots - state.characters.length;
    if (free > 0) {
        const slot = el('div', 'slot slot--empty');
        slot.dataset.id = 'new';
        slot.style.animationDelay = `${state.characters.length * 60}ms`;
        const avatar = el('div', 'avatar');
        avatar.append(icon('plus'));
        const main = el('div', 'slot__main');
        main.append(el('div', 'slot__name', 'New character'), el('div', 'slot__meta', `${free} free slot${free > 1 ? 's' : ''}`));
        slot.append(avatar, main);
        slot.addEventListener('click', () => select(null));
        slot.addEventListener('dblclick', () => play());
        slotsNode.append(slot);
    }
}

function play() {
    if (state.selected) {
        post('select:play', { citizenid: state.selected });
    } else if (state.characters.length < state.slots) {
        post('select:create');
    }
}

playButton.addEventListener('click', play);

deleteButton.addEventListener('click', async () => {
    const character = state.characters.find((c) => c.citizenid === state.selected);
    if (!character) return;

    const sure = await confirmModal(
        'Delete character?',
        `${character.firstname} ${character.lastname} and everything they own will be gone for good.`,
        'Delete',
    );
    if (sure) post('select:delete', { citizenid: character.citizenid });
});

export function showSelect(data) {
    state = {
        characters: data.characters || [],
        slots: data.slots || 0,
        canDelete: data.canDelete,
        selected: null,
    };

    root.classList.remove('hidden');
    renderSlots();

    const first = state.characters[0];
    state.selected = first ? first.citizenid : null;
    slotsNode.querySelectorAll('.slot').forEach((node) => {
        node.classList.toggle('is-active', node.dataset.id === (state.selected || 'new'));
    });
    playButton.textContent = first ? (first.hasLook ? 'Play' : 'Finish look') : 'Create character';
    deleteButton.classList.toggle('hidden', !first || !state.canDelete);
    renderDetails();
}

export function hideSelect() {
    root.classList.add('hidden');
}
