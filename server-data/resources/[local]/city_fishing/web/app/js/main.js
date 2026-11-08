import { L, setLabels, el, icon, run, toast, duration, row, group } from './ui.js';

const content = document.getElementById('content');
const nav = document.getElementById('nav');

const app = { tab: 'profile', branches: [], profile: null };

const TABS = ['profile', 'skills', 'collection', 'market', 'events', 'pots'];
const REGIONS = ['ocean', 'deep', 'alamo', 'river', 'lake', 'canal'];
const MODES = ['biggest', 'count', 'weight'];

function drawNav() {
    nav.replaceChildren(...TABS.map((tab) => el('button', { class: `kit-nav${app.tab === tab ? ' on' : ''}`, onclick: () => go(tab) },
        icon(tab === 'pots' ? 'pots' : tab),
        el('span', { text: L(`ui_tab_${tab}`) }),
    )));
}

function heading(text) {
    return el('div', { class: 'kit-heading', text });
}

function scoreText(mode, score) {
    if (mode === 'biggest') return `${score} cm`;
    if (mode === 'weight') return `${score} kg`;
    return String(score);
}

async function loadProfile() {
    const profile = await run('profile');
    if (profile) {
        app.profile = profile;
        document.getElementById('who').textContent = L('ui_level', profile.level);
    }
    return profile;
}

async function renderProfile() {
    const p = await loadProfile();
    if (!p) return el('div', { class: 'empty', text: L('failed') });

    const share = p.to ? (p.xp - p.from) / (p.to - p.from) : 1;
    const hero = el('div', { class: 'kit-card' },
        el('div', { class: 'hero' },
            el('div', { class: 'badge', text: String(p.level) }),
            el('div', { class: 'meta' },
                el('strong', { text: L('ui_level', p.level) }),
                el('small', { text: p.to ? L('ui_xp', p.xp, p.to) : L('ui_level_max') }),
            ),
            p.points > 0 ? el('button', { class: 'kit-btn accent', text: L('ui_points', p.points), onclick: () => go('skills') }) : null,
        ),
        el('div', { class: 'xp' }, el('div', { style: `width:${Math.max(0, Math.min(1, share)) * 100}%` })),
    );

    let licence = L('ui_licence_none');
    if (p.licence.expires) licence = p.licence.valid ? L('ui_licence_valid', duration(p.licence.expires - p.licence.now)) : L('ui_licence_expired');

    const biggest = p.biggest ? `${p.biggest.label} · ${p.biggest.size} cm` : L('ui_none');

    return el('div', { class: 'stack' },
        heading(L('ui_tab_profile')),
        hero,
        group(null, [row(el('span', { text: L('ui_licence') }), el('span', { class: `kit-value${p.licence.valid ? '' : ' kit-danger'}`, text: licence }))]),
        group(L('ui_stats'), [
            row(el('span', { text: L('ui_caught') }), el('span', { class: 'kit-value', text: String(p.caught) })),
            row(el('span', { text: L('ui_legendaries') }), el('span', { class: 'kit-value', text: String(p.legendaries) })),
            row(el('span', { text: L('ui_biggest') }), el('span', { class: 'kit-value', text: biggest })),
        ]),
    );
}

function pips(rank, max) {
    const node = el('div', { class: 'pips' });
    for (let i = 0; i < max; i++) node.append(el('i', { class: i < rank ? 'on' : '' }));
    return node;
}

function spentIn(branch, skills) {
    let total = 0;
    for (const node of branch.nodes) total += skills[node.id] || 0;
    if (skills[branch.capstone.id]) total += branch.capstone.cost;
    return total;
}

async function learn(id) {
    const skills = await run('learn', id);
    if (skills) {
        toast(L('ui_learned'));
        go('skills');
    }
}

async function renderSkills() {
    const p = await loadProfile();
    if (!p) return el('div', { class: 'empty', text: L('failed') });

    const skills = p.skills || {};
    const hasCapstone = app.branches.some((branch) => skills[branch.capstone.id]);

    const columns = app.branches.map((branch) => {
        const nodes = branch.nodes.map((node, index) => {
            const rank = skills[node.id] || 0;
            const locked = index > 0 && !skills[branch.nodes[index - 1].id];
            const can = !locked && rank < node.values.length && p.points > 0;

            return el('div', { class: `node${locked ? ' locked' : ''}` },
                el('div', { class: 'top' },
                    el('strong', { text: L(`skill_${node.id}`) }),
                    pips(rank, node.values.length),
                ),
                el('p', { text: L(`skill_${node.id}_desc`) }),
                can ? el('button', { class: 'kit-btn', text: L('ui_learn'), onclick: () => learn(node.id) }) : null,
            );
        });

        const cap = branch.capstone;
        const owned = !!skills[cap.id];
        const capCan = !owned && !hasCapstone && spentIn(branch, skills) >= cap.needs && p.points >= cap.cost;

        nodes.push(el('div', { class: `node capstone${owned || capCan ? '' : ' locked'}` },
            el('div', { class: 'top' },
                el('strong', { text: L(`skill_${cap.id}`) }),
                el('span', { class: 'kit-pill', text: owned ? L('ui_learned') : L('ui_capstone') }),
            ),
            el('p', { text: L(`skill_${cap.id}_desc`) }),
            el('p', { text: L('ui_capstone_needs', cap.needs, cap.cost) }),
            capCan ? el('button', { class: 'kit-btn accent', text: L('ui_learn'), onclick: () => learn(cap.id) }) : null,
        ));

        return el('div', { class: 'branch' }, el('h3', { text: L(`branch_${branch.id}`) }), ...nodes);
    });

    return el('div', { class: 'stack' },
        heading(L('ui_tab_skills')),
        el('div', { class: 'kit-pill', text: L('ui_points', p.points) }),
        el('div', { class: 'branches' }, ...columns),
    );
}

async function renderCollection() {
    const data = await run('collection');
    if (!data) return el('div', { class: 'empty', text: L('failed') });

    const caught = data.list.filter((entry) => entry.count > 0).length;
    const cards = data.list.map((entry) => {
        const known = entry.count > 0;
        const regions = entry.regions.map((region) => L(`region_${region}`)).join(', ');

        return el('div', { class: `species${known ? '' : ' unknown'}${entry.legendary ? ' legendary' : ''}` },
            el('strong', { text: known ? entry.label : L('ui_unknown') }),
            el('small', { text: entry.legendary ? L('ui_legendary') : regions }),
            known ? el('small', { text: L('ui_count', entry.count) }) : null,
            known && entry.best > 0 ? el('small', { text: L('ui_best', entry.best) }) : null,
        );
    });

    return el('div', { class: 'stack' },
        heading(L('ui_tab_collection')),
        el('div', { class: 'kit-pill', text: L('ui_species', caught, data.total) }),
        el('div', { class: 'grid' }, ...cards),
    );
}

async function renderMarket() {
    const list = await run('market');
    if (!list) return el('div', { class: 'empty', text: L('failed') });

    const rows = list.map((entry) => {
        const full = entry.demand >= 0.995;
        const price = Math.floor(entry.price * entry.demand);

        return row(
            el('span', { text: entry.label }),
            el('span', { class: `trend ${full ? 'full' : 'low'}`, text: full ? L('ui_demand_full') : L('ui_demand_low', `${Math.round(entry.demand * 100)}%`) }),
            el('span', { class: 'kit-value', text: `$${price}` }),
        );
    });

    return el('div', { class: 'stack' }, heading(L('ui_tab_market')), group(null, rows, L('ui_market_note')));
}

function select(name, options) {
    return el('select', { class: 'kit-input', name }, ...options.map(([value, label]) => el('option', { value, text: label })));
}

function staffForm(data) {
    const form = el('div', { class: 'form' },
        el('label', { text: L('ui_name') }, el('input', { class: 'kit-input', name: 'label', maxlength: '60' })),
        el('label', { text: L('ui_minutes') }, el('input', { class: 'kit-input', name: 'minutes', type: 'number', min: '5', max: String(data.maxMinutes), value: '30' })),
        el('label', { text: L('ui_mode') }, select('mode', MODES.map((mode) => [mode, L(`mode_${mode}`)]))),
        el('label', { text: L('ui_region') }, select('region', REGIONS.map((region) => [region, L(`region_${region}`)]))),
        el('label', { text: L('ui_species_label') }, select('species', [['', L('ui_species_any')], ...data.species.map((entry) => [entry.name, entry.label])])),
    );

    const value = (name) => form.querySelector(`[name="${name}"]`).value;

    form.append(el('div', { class: 'actions' },
        el('button', { class: 'kit-btn', text: L('ui_start_frenzy'), onclick: async () => { if (await run('startFrenzy')) { toast(L('ui_started')); go('events'); } } }),
        el('button', { class: 'kit-btn accent', text: L('ui_start'), onclick: async () => {
            const done = await run('startTournament', {
                label: value('label'), minutes: Number(value('minutes')), mode: value('mode'), region: value('region'), species: value('species'),
            });
            if (done) { toast(L('ui_started')); go('events'); }
        } }),
    ));

    return group(L('ui_staff'), [form]);
}

async function renderEvents() {
    const data = await run('events');
    if (!data) return el('div', { class: 'empty', text: L('failed') });

    const blocks = [heading(L('ui_tab_events'))];

    const frenzy = data.frenzy;
    blocks.push(group(L('ui_frenzy'), [row(el('span', {
        text: frenzy ? L('ui_frenzy_text', frenzy.label, duration(frenzy.endsAt - data.now)) : L('ui_no_frenzy'),
    }))]));

    const running = data.running;
    if (running) {
        const what = `${L(`mode_${running.mode}`)} · ${L(`region_${running.region}`)}${running.species ? ` · ${running.species}` : ''}`;
        const ranking = running.ranking.length
            ? running.ranking.map((entry, index) => row(el('span', { class: 'rank', text: `#${index + 1}` }), el('span', { text: entry.name }), el('span', { class: 'kit-value', text: scoreText(running.mode, entry.score) })))
            : [row(el('span', { class: 'kit-value', text: L('ui_nobody') }))];

        blocks.push(group(L('ui_tournament'), [
            row(el('strong', { text: running.label }), el('span', { class: 'kit-value', text: L('ui_ends_in', duration(running.endsAt - data.now)) })),
            row(el('span', { text: what }),
                running.joined
                    ? el('span', { class: 'kit-pill', text: L('ui_joined') })
                    : el('button', { class: 'kit-btn accent', text: L('ui_join'), onclick: async () => { if (await run('join')) go('events'); } })),
        ], L('ui_prizes', ...data.prizes)));
        blocks.push(group(L('ui_ranking'), ranking));
    } else {
        blocks.push(group(L('ui_tournament'), [row(el('span', { text: L('ui_no_tournament') }))]));
    }

    if (data.schedule.length) {
        blocks.push(group(L('ui_schedule'), data.schedule.map((entry) => row(
            el('span', { text: entry.label }),
            el('span', { class: 'kit-value', text: `${L(`day_${entry.wday}`)} ${String(entry.hour).padStart(2, '0')}:00 · ${L(`mode_${entry.mode}`)}` }),
        ))));
    }

    if (data.last && data.last.ranking.length) {
        blocks.push(group(`${L('ui_last')} · ${data.last.label}`, data.last.ranking.slice(0, 3).map((entry, index) => row(
            el('span', { class: 'rank', text: `#${index + 1}` }), el('span', { text: entry.name }), el('span', { class: 'kit-value', text: scoreText(data.last.mode, entry.score) }),
        ))));
    }

    if (data.staff) blocks.push(staffForm(data));

    return el('div', { class: 'stack' }, ...blocks);
}

async function renderPots() {
    const list = await run('pots');
    if (!list) return el('div', { class: 'empty', text: L('failed') });

    const rows = list.length ? list.map((pot, index) => row(
        el('span', { text: `#${index + 1}` }),
        el('span', { class: 'kit-value', text: pot.secondsLeft > 0 ? L('ui_ready_in', duration(pot.secondsLeft)) : L('ui_ready') }),
        el('button', { class: 'kit-btn', onclick: () => window.CityOS.send('route', { x: pot.x, y: pot.y }) }, icon('route', 16), el('span', { text: ` ${L('ui_route')}` })),
    )) : [row(el('span', { class: 'kit-value', text: L('ui_pots_none') }))];

    return el('div', { class: 'stack' }, heading(L('ui_tab_pots')), group(null, rows));
}

const RENDER = {
    profile: renderProfile,
    skills: renderSkills,
    collection: renderCollection,
    market: renderMarket,
    events: renderEvents,
    pots: renderPots,
};

async function go(tab) {
    app.tab = tab;
    drawNav();

    if (!content.firstChild) content.replaceChildren(el('div', { class: 'loading', text: L('ui_loading') }));

    const view = await RENDER[tab]();
    if (app.tab === tab) content.replaceChildren(view);
}

async function start() {
    const setup = await window.CityOS.send('setup');
    setLabels(setup && setup.labels);
    app.branches = (setup && setup.branches) || [];

    document.getElementById('title').textContent = L('ui_title');
    go('profile');
}

start();
