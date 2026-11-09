import { el } from './util.js';
import { ERRORS } from './labels.js';

const NAME = /^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ '-]*$/;

let fields = {};
let card = {};
let limits = {};
let allowed = new Set();

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
        return allowed.size === 0 ? value.length > 1 : allowed.has(value);
    }
    return true;
}

export function renderIdentity(body, identity, nationalities, sex) {
    limits = { dateMin: identity.dateMin || '1900-01-01', dateMax: identity.dateMax || '2008-12-31' };
    allowed = new Set(nationalities || []);
    const previous = Object.fromEntries(Object.entries(fields).map(([k, f]) => [k, f.input.value]));

    fields = {
        firstname: field('First name', input('text', 'Jordan', 20)),
        lastname: field('Last name', input('text', 'Hayes', 20)),
        birthdate: field('Date of birth', input('date')),
        nationality: field('Nationality', input('text', 'Start typing…', 40)),
    };

    fields.birthdate.input.min = limits.dateMin;
    fields.birthdate.input.max = limits.dateMax;

    const list = document.createElement('datalist');
    list.id = 'nationalities';
    (nationalities || []).forEach((name) => {
        const option = document.createElement('option');
        option.value = name;
        list.append(option);
    });
    fields.nationality.input.setAttribute('list', 'nationalities');

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
    wrap.append(names, fields.birthdate.wrap, fields.nationality.wrap, list);
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
        nationality: tidy(fields.nationality.input.value),
    };
}
