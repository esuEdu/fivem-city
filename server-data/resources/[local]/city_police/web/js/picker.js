import { el, L, run, icon } from './ui.js';

// A search field that lists people as you type; picking one calls onPick({ citizenid, name })
export function personPicker(onPick, placeholder = L('ui_find_person')) {
    const input = el('input', { class: 'field', type: 'text', placeholder });
    const results = el('div', { class: 'picker-list hidden' });
    let timer = null;

    input.addEventListener('input', () => {
        clearTimeout(timer);
        const value = input.value.trim();
        if (value.length < 2) return results.classList.add('hidden');

        timer = setTimeout(async () => {
            const response = await run('searchPeople', { q: value });
            const people = response ? response.data : [];

            results.replaceChildren(...(people.length
                ? people.map((person) => el('button', { class: 'picker-item', type: 'button', onclick: () => {
                    results.classList.add('hidden');
                    input.value = '';
                    onPick({ citizenid: person.citizenid, name: person.name, online: person.online });
                } }, el('span', { text: person.name }), el('small', { text: person.citizenid })))
                : [el('div', { class: 'picker-item muted', text: L('ui_no_results') })]));
            results.classList.remove('hidden');
        }, 300);
    });

    return el('div', { class: 'picker' }, el('label', { class: 'search' }, icon('search', 16, 2), input), results);
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
