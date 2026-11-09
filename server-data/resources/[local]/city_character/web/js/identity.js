import { el } from './util.js';
import { ERRORS } from './labels.js';

const NAME = /^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ '-]*$/;

let fields = {};
let card = {};
let limits = {};
let allowed = new Map();

const SUGGESTIONS = 8;

function field(label, input) {
    const wrap = el('div', 'field');
    const error = el('span', 'field__error');
    wrap.append(el('label', '', label), input, error);
    return { wrap, input, error };
}

function input(type, placeholder, maxLength) {
    const node = document.createElement('input');
    node.type = type;
    node.placeholder = placeholder || '';
    if (maxLength) node.maxLength = maxLength;
    node.spellcheck = false;
    node.autocomplete = 'off';
    return node;
}

function tidy(value) {
    return value.trim().replace(/\s+/g, ' ');
}

// The list's own spelling for what was typed, whatever the case
function canonical(value) {
    return allowed.get(tidy(value).toLowerCase());
}

/**
 * A suggestion list of our own under the nationality field: FiveM's NUI doesn't draw a <datalist>
 * @param {HTMLInputElement} node
 * @param {string[]} names
 */
function attachSuggestions(node, names) {
    const box = el('div', 'suggest');
    let shown = [];
    let active = -1;

    const close = () => {
        box.classList.remove('is-open');
        active = -1;
    };

    const pick = (name) => {
        node.value = name;
        node.dispatchEvent(new Event('input'));
        close();
    };

    const highlight = () => {
        [...box.children].forEach((row, i) => row.classList.toggle('is-active', i === active));
        if (box.children[active]) box.children[active].scrollIntoView({ block: 'nearest' });
    };

    const update = () => {
        const query = tidy(node.value).toLowerCase();
        const starts = [];
        const contains = [];

        for (const name of names) {
            const lower = name.toLowerCase();
            if (lower === query) continue;
            if (lower.startsWith(query)) starts.push(name);
            else if (query && lower.includes(query)) contains.push(name);
        }

        shown = starts.concat(contains).slice(0, query ? SUGGESTIONS : names.length);
        active = -1;
        box.replaceChildren(...shown.map((name) => {
            const row = el('div', 'suggest__row', name);
            // mousedown, so the input doesn't lose focus (and close the list) before the pick
            row.addEventListener('mousedown', (event) => {
                event.preventDefault();
                pick(name);
            });
            return row;
        }));
        box.classList.toggle('is-open', shown.length > 0 && document.activeElement === node);
    };

    node.addEventListener('focus', update);
    node.addEventListener('input', update);
    node.addEventListener('blur', () => {
        const name = canonical(node.value);
        if (name && name !== node.value) pick(name);
        close();
    });
    node.addEventListener('keydown', (event) => {
        if (!box.classList.contains('is-open')) return;
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            const step = event.key === 'ArrowDown' ? 1 : -1;
            active = (active + step + shown.length) % shown.length;
            highlight();
        } else if (event.key === 'Enter' || event.key === 'Tab') {
            const name = shown[active] || (shown.length === 1 && shown[0]);
            if (name) {
                event.preventDefault();
                pick(name);
            }
        } else if (event.key === 'Escape') {
            close();
        }
    });

    return box;
}

function drawCard() {
    const first = tidy(fields.firstname.input.value);
    const last = tidy(fields.lastname.input.value);
    card.name.textContent = first || last ? `${first} ${last}`.trim() : 'Your name';
    card.born.textContent = fields.birthdate.input.value || '—';
    card.nation.textContent = fields.nationality.input.value || '—';
}

function check(key) {
    const value = tidy(fields[key].input.value);

    if (key === 'firstname' || key === 'lastname') {
        return value.length >= 2 && value.length <= 20 && NAME.test(value);
    }
    if (key === 'birthdate') {
        return /^\d{4}-\d{2}-\d{2}$/.test(value) && value >= limits.dateMin && value <= limits.dateMax;
    }
    if (key === 'nationality') {
        return allowed.size === 0 ? value.length > 1 : canonical(value) !== undefined;
    }
    return true;
}

export function renderIdentity(body, identity, nationalities, sex) {
    limits = { dateMin: identity.dateMin || '1900-01-01', dateMax: identity.dateMax || '2008-12-31' };
    allowed = new Map((nationalities || []).map((name) => [name.toLowerCase(), name]));
    const previous = Object.fromEntries(Object.entries(fields).map(([k, f]) => [k, f.input.value]));

    fields = {
        firstname: field('First name', input('text', 'Jordan', 20)),
        lastname: field('Last name', input('text', 'Hayes', 20)),
        birthdate: field('Date of birth', input('date')),
        nationality: field('Nationality', input('text', 'Start typing…', 40)),
    };

    fields.birthdate.input.min = limits.dateMin;
    fields.birthdate.input.max = limits.dateMax;

    if (allowed.size > 0) {
        fields.nationality.input.after(attachSuggestions(fields.nationality.input, [...allowed.values()]));
    }

    const idcard = el('div', 'idcard');
    const top = el('div', 'idcard__top');
    top.append(el('span', 'idcard__state', 'San Andreas'), el('span', '', 'Identity card'));
    card.name = el('div', 'idcard__name');
    const meta = el('div', 'idcard__meta');
    const born = el('div');
    card.born = el('b');
    born.append(el('span', '', 'Born'), card.born);
    const nation = el('div');
    card.nation = el('b');
    nation.append(el('span', '', 'Nationality'), card.nation);
    const sexBox = el('div');
    sexBox.append(el('span', '', 'Sex'), el('b', '', sex === 'f' ? 'F' : 'M'));
    meta.append(born, nation, sexBox);
    idcard.append(top, card.name, meta);

    const names = el('div', 'fields-row');
    names.append(fields.firstname.wrap, fields.lastname.wrap);

    const wrap = el('div', 'group');
    wrap.append(names, fields.birthdate.wrap, fields.nationality.wrap);
    body.append(idcard, wrap);

    for (const [key, f] of Object.entries(fields)) {
        if (previous[key]) f.input.value = previous[key];
        f.input.addEventListener('input', () => {
            f.wrap.classList.remove('is-invalid');
            f.error.textContent = '';
            drawCard();
        });
        f.input.addEventListener('keydown', (event) => event.stopPropagation());
    }

    drawCard();
    requestAnimationFrame(() => fields.firstname.input.focus());
}

/**
 * The identity typed so far, or null (with the errors shown) when something is off
 * @param {boolean} showErrors
 * @param {string} [forced] a field the server refused
 */
export function identityValues(showErrors, forced) {
    if (!fields.firstname) return null;
    let ok = true;

    for (const key of Object.keys(fields)) {
        const valid = key !== forced && check(key);
        if (!valid) {
            ok = false;
            if (showErrors) {
                fields[key].wrap.classList.add('is-invalid');
                fields[key].error.textContent = ERRORS[key];
            }
        }
    }

    if (!ok) return null;

    return {
        firstname: tidy(fields.firstname.input.value),
        lastname: tidy(fields.lastname.input.value),
        birthdate: fields.birthdate.input.value,
        nationality: canonical(fields.nationality.input.value) || tidy(fields.nationality.input.value),
    };
}
