import { el, L, run, icon } from './ui.js';

// Name or server ID: which one the person searches use (kept while the MDT is open)
let searchBy = 'name';

// The Name / ID switch above a person search; onChange(by) runs the search again
export function searchSwitch(onChange) {
    const box = el('div', { class: 'switch-row' });
    const draw = () => box.replaceChildren(...['name', 'id'].map((by) => el('button', {
        class: `switch-opt${searchBy === by ? ' on' : ''}`, type: 'button', text: L(`ui_search_by_${by}`),
        onclick: () => {
            if (searchBy === by) return;
            searchBy = by;
            draw();
            onChange(by);
        },
    })));
    draw();

    return box;
}

// Asks the server: by name (A to Z, several) or by server ID (exactly that player, online only)
export async function findPeople(value) {
    const q = value.trim();
    if (searchBy === 'id' ? !/^\d{1,5}$/.test(q) : q.length < 2) return null;

    const response = await run('searchPeople', { q, by: searchBy });
    return response ? response.data : [];
}

export function searchPlaceholder() {
    return L(searchBy === 'id' ? 'ui_search_id' : 'ui_search_people');
}

// "Name · #12" for someone in the city right now
export function personLabel(person) {
    return person.id ? `${person.name} · #${person.id}` : person.name;
}

// A search field with the Name / ID switch that lists people as you type (first match on top, keep scrolling for
// the others); picking one calls onPick({ citizenid, name, online, id })
export function personPicker(onPick) {
    const input = el('input', { class: 'field', type: 'text', placeholder: searchPlaceholder() });
    const results = el('div', { class: 'picker-list hidden' });
    let timer = null;

    const lookup = () => {
        clearTimeout(timer);
        timer = setTimeout(async () => {
            const people = await findPeople(input.value);
            if (!people) return results.classList.add('hidden');

            results.replaceChildren(...(people.length
                ? people.map((person) => el('button', { class: 'picker-item', type: 'button', onclick: () => {
                    results.classList.add('hidden');
                    input.value = '';
                    onPick({ citizenid: person.citizenid, name: person.name, online: person.online, id: person.id });
                } }, el('span', { text: personLabel(person) }), el('small', { text: person.citizenid })))
                : [el('div', { class: 'picker-item muted', text: L('ui_no_results') })]));
            results.classList.remove('hidden');
        }, 250);
    };

    input.addEventListener('input', lookup);

    const switcher = searchSwitch(() => {
        input.placeholder = searchPlaceholder();
        input.value = '';
        results.classList.add('hidden');
        input.focus();
    });

    return el('div', { class: 'picker' }, switcher, el('label', { class: 'search' }, icon('search', 16, 2), input), results);
}

// The penal code as a list of crimes with − / + counts; `counts` is { crimeId: n } and is changed in place
export function crimeList(penal, counts, onChange) {
    const list = el('div', { class: 'crimes' });

    const draw = () => {
        list.replaceChildren(...penal.categories.map((category) => el('div', { class: 'crime-group' },
            el('div', { class: 'kit-head', text: L(`penal_${category}`) }),
            penal.crimes.filter((crime) => crime.category === category).map((crime) => {
                const count = counts[crime.id] || 0;
                const change = (delta) => {
                    const next = Math.max(0, Math.min(5, count + delta));
                    if (next) counts[crime.id] = next; else delete counts[crime.id];
                    draw();
                    onChange();
                };

                return el('div', { class: `crime${count ? ' on' : ''}` },
                    el('span', { class: 'grow' }, el('strong', { text: crime.title }),
                        el('small', { class: 'block muted', text: [crime.months ? L('ui_months', crime.months) : null, `$${crime.fine.toLocaleString('en-US')}`, crime.points ? L('ui_points_short', crime.points) : null].filter(Boolean).join(' · ') })),
                    el('div', { class: 'stepper small' },
                        el('button', { class: 'step', type: 'button', onclick: () => change(-1) }, '−'),
                        el('span', { class: 'count', text: String(count) }),
                        el('button', { class: 'step', type: 'button', onclick: () => change(1) }, '+')),
                );
            }))));
    };

    draw();
    return list;
}

// Totals of the picked crimes, worked out the same way the server does (the server's numbers are the real ones)
export function totals(penal, counts, maxMonths, maxFine) {
    let months = 0;
    let fine = 0;
    let points = 0;

    for (const crime of penal.crimes) {
        const count = counts[crime.id] || 0;
        months += crime.months * count;
        fine += crime.fine * count;
        points += crime.points * count;
    }

    return { months: Math.min(months, maxMonths), fine: Math.min(fine, maxFine), points };
}

export function chargeList(counts) {
    return Object.entries(counts).map(([id, count]) => ({ id, count }));
}
