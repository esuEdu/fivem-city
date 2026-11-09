import { L, setLabels, el, icon, run, toast, duration, row, group } from './ui.js';

const content = document.getElementById('content');
const nav = document.getElementById('nav');

const app = { tab: 'profile', branches: [], profile: null };

const ALL_TABS = ['profile', 'skills', 'market', 'orders'];
let TABS = ALL_TABS;

function drawNav() {
    nav.replaceChildren(...TABS.map((tab) => el('button', { class: `kit-nav${app.tab === tab ? ' on' : ''}`, onclick: () => go(tab) },
        icon(tab),
        el('span', { text: L(`ui_tab_${tab}`) }),
    )));
}

function heading(text) {
    return el('div', { class: 'kit-heading', text });
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
            app.skillsOn && p.points > 0 ? el('button', { class: 'kit-btn accent', text: L('ui_points', p.points), onclick: () => go('skills') }) : null,
        ),
        el('div', { class: 'xp' }, el('div', { style: `width:${Math.max(0, Math.min(1, share)) * 100}%` })),
    );

    let licence = L('ui_licence_none');
    if (p.licence.expires) licence = p.licence.valid ? L('ui_licence_valid', duration(p.licence.expires - p.licence.now)) : L('ui_licence_expired');

    const tiers = p.tiers.map((level, index) => row(
        el('span', { text: L('ui_tier', index + 1) }),
        el('span', { class: `kit-value${p.level >= level ? '' : ' kit-danger'}`, text: p.level >= level ? L('ui_unlocked') : L('ui_unlocks_at', level) }),
    ));

    const blocks = [
        heading(L('ui_tab_profile')),
        hero,
        group(null, [row(el('span', { text: L('ui_licence') }), el('span', { class: `kit-value${p.licence.valid ? '' : ' kit-danger'}`, text: licence }))]),
        group(L('ui_tiers'), tiers),
        group(L('ui_stats'), [
            row(el('span', { text: L('ui_mined') }), el('span', { class: 'kit-value', text: String(p.mined) })),
            row(el('span', { text: L('ui_geodes') }), el('span', { class: 'kit-value', text: String(p.geodes) })),
            row(el('span', { text: L('ui_panned') }), el('span', { class: 'kit-value', text: String(p.panned) })),
        ]),
    ];

    if (p.skills && p.skills.tracking) {
        blocks.push(el('button', { class: 'kit-btn accent', onclick: () => { window.CityOS.send('track'); toast(L('ui_tracking')); } },
            icon('track', 16), el('span', { text: ` ${L('ui_track')}` })));
    }

    return el('div', { class: 'stack' }, ...blocks);
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

async function renderMarket() {
    const list = await run('market');
    if (!list) return el('div', { class: 'empty', text: L('failed') });

    const rows = list.map((entry) => {
        const full = entry.demand >= 0.995;
        const price = Math.floor(entry.price * entry.demand);

        return row(
            el('span', { text: entry.ingot ? `${entry.label} · ${L('ui_stamped')}` : entry.label }),
            el('span', { class: `trend ${full ? 'full' : 'low'}`, text: full ? L('ui_demand_full') : L('ui_demand_low', `${Math.round(entry.demand * 100)}%`) }),
            el('span', { class: 'kit-value', text: `$${price}` }),
        );
    });

    return el('div', { class: 'stack' }, heading(L('ui_tab_market')), group(null, rows, L('ui_market_note')));
}

async function renderOrders() {
    const list = await run('orders');
    if (!list) return el('div', { class: 'empty', text: L('failed') });

    const rows = list.length ? list.map((order) => row(
        el('span', { text: `${order.count}x ${order.label}` }),
        el('span', { class: 'kit-pill', text: L(`ui_place_${order.place}`) }),
        el('span', { class: 'kit-value', text: order.secondsLeft > 0 ? L('ui_ready_in', duration(order.secondsLeft)) : L('ui_ready') }),
    )) : [row(el('span', { class: 'kit-value', text: L('ui_no_orders') }))];

    return el('div', { class: 'stack' }, heading(L('ui_tab_orders')), group(null, rows));
}

const RENDER = {
    profile: renderProfile,
    skills: renderSkills,
    market: renderMarket,
    orders: renderOrders,
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
    // Tabs switched off in Config.Features; the server refuses their callbacks too
    const features = (setup && setup.features) || {};
    TABS = ALL_TABS.filter((tab) => !(tab in features) || features[tab]);
    app.skillsOn = features.skills !== false;

    document.getElementById('title').textContent = L('ui_title');
    go('profile');
}

start();
