import { el, icon, post, postLatest, toast, confirmModal } from './util.js';
import { slider, pad, stepper, swatches, group } from './controls.js';
import { FEATURES, FACE_GROUPS, OVERLAYS, EYE_COLORS, SHOTS, LIGHTS, STEPS, ERRORS } from './labels.js';
import { setupPoints, showPoints, movePoints } from './points.js';
import { renderIdentity, identityValues } from './identity.js';

const root = document.getElementById('creator');
const stepsNode = document.getElementById('steps');
const body = document.getElementById('step-body');
const kicker = document.getElementById('step-kicker');
const title = document.getElementById('step-title');
const hint = document.getElementById('step-hint');
const backButton = document.getElementById('back');
const nextButton = document.getElementById('next');
const undoButton = document.getElementById('undo');
const redoButton = document.getElementById('redo');
const randomButton = document.getElementById('random');

let s = null;
let featureControls = new Map();

const PORTRAIT = (pic) => `https://nui-img/char_creator_portraits/${pic}`;
const pct = (v) => `${Math.round(v * 100)}%`;

// ---------- history ----------

function snapshot() {
    return JSON.stringify(s.draft);
}

function commit() {
    const now = snapshot();
    if (now === s.saved) return;
    s.undo.push(s.saved);
    if (s.undo.length > 60) s.undo.shift();
    s.redo = [];
    s.saved = now;
    drawHistory();
}

function drawHistory() {
    undoButton.disabled = s.undo.length === 0;
    redoButton.disabled = s.redo.length === 0;
}

async function restore(json) {
    s.draft = JSON.parse(json);
    s.saved = json;
    const catalog = await post('creator:apply', s.draft);
    if (catalog) s.catalog = catalog;
    drawHistory();
    renderStep();
}

undoButton.append(icon('undo'));
redoButton.append(icon('redo'));
randomButton.append(icon('dice'));
undoButton.dataset.tip = 'Undo';
redoButton.dataset.tip = 'Redo';
randomButton.dataset.tip = 'Random face';

undoButton.addEventListener('click', () => {
    if (!s?.undo.length) return;
    s.redo.push(s.saved);
    restore(s.undo.pop());
});

redoButton.addEventListener('click', () => {
    if (!s?.redo.length) return;
    s.undo.push(s.saved);
    restore(s.redo.pop());
});

randomButton.addEventListener('click', () => {
    if (!s) return;
    const rand = (spread) => Math.round((Math.random() * 2 - 1) * spread * 100) / 100;
    const mothers = s.parents.filter((p) => p.id >= 21 && p.id <= 41);
    const fathers = s.parents.filter((p) => p.id <= 20);
    const h = s.draft.heritage;
    h.mother = mothers[Math.floor(Math.random() * mothers.length)].id;
    h.father = fathers[Math.floor(Math.random() * fathers.length)].id;
    h.skinMother = h.mother;
    h.skinFather = h.father;
    h.shapeMix = Math.round(Math.random() * 100) / 100;
    h.skinMix = Math.round(Math.random() * 100) / 100;
    Object.keys(s.draft.features).forEach((name) => { s.draft.features[name] = rand(0.55); });
    post('creator:apply', s.draft);
    commit();
    renderStep();
});

// ---------- updates ----------

function setFeature(name, value) {
    s.draft.features[name] = value;
    postLatest(`f:${name}`, 'creator:feature', { name, value });
    (featureControls.get(name) || []).forEach((sync) => sync());
}

function setHeritage() {
    postLatest('heritage', 'creator:heritage', s.draft.heritage);
}

function setOverlay(name) {
    postLatest(`o:${name}`, 'creator:overlay', { name, entry: s.draft.overlays[name] });
}

async function setHair() {
    const result = await post('creator:hair', s.draft.hair);
    return result?.textures ?? 1;
}

function trackFeature(name, sync) {
    if (!featureControls.has(name)) featureControls.set(name, []);
    featureControls.get(name).push(sync);
}

// ---------- steps ----------

function parentStrip(list, selected, onPick) {
    const strip = el('div', 'parents');
    list.forEach((parent) => {
        const item = el('button', 'parent');
        item.type = 'button';
        item.classList.toggle('is-active', parent.id === selected);

        const pic = el('div', 'parent__pic');
        const img = document.createElement('img');
        img.alt = '';
        img.src = PORTRAIT(parent.pic);
        // The texture dict can still be streaming in: try again a few times before falling back to the initial
        let retries = 0;
        img.onerror = () => {
            if (retries++ < 5) {
                // nui-img reads the path as dict/texture, so no cache-busting query: clear src to force a new load
                setTimeout(() => {
                    img.removeAttribute('src');
                    img.src = PORTRAIT(parent.pic);
                }, 400 * retries);
                return;
            }
            img.remove();
            pic.textContent = parent.name[0];
        };
        pic.append(img);

        item.append(pic, el('div', 'parent__name', parent.name));
        item.addEventListener('click', () => {
            strip.querySelectorAll('.parent').forEach((n) => n.classList.remove('is-active'));
            item.classList.add('is-active');
            onPick(parent);
        });
        strip.append(item);
    });

    requestAnimationFrame(() => strip.querySelector('.is-active')?.scrollIntoView({ inline: 'center', block: 'nearest' }));
    return strip;
}

function parentName(id) {
    return s.parents.find((p) => p.id === id)?.name || '';
}

function renderHeritage() {
    const h = s.draft.heritage;
    const mothers = s.parents.filter((p) => p.id >= 21 && p.id <= 41 || p.id === 45);
    const fathers = s.parents.filter((p) => p.id <= 20 || (p.id >= 42 && p.id <= 44));

    const sexGroup = group('Body');
    const seg = el('div', 'segmented');
    [['m', 'Male', 'male'], ['f', 'Female', 'female']].forEach(([sex, label, iconName]) => {
        const button = el('button', 'segment');
        button.type = 'button';
        button.append(icon(iconName), el('span', '', label));
        button.classList.toggle('is-active', s.draft.sex === sex);
        button.disabled = s.lockSex && s.draft.sex !== sex;
        button.addEventListener('click', async () => {
            if (s.draft.sex === sex || s.lockSex) return;
            const fresh = await post('creator:defaults', { sex });
            if (!fresh) return;
            s.draft = fresh;
            const catalog = await post('creator:apply', s.draft);
            if (catalog) s.catalog = catalog;
            commit();
            renderStep();
        });
        seg.append(button);
    });
    sexGroup.append(seg);

    const parentsGroup = group('Parents');
    const motherLabel = el('div', 'parent-label');
    const motherName = el('b', '', parentName(h.mother));
    motherLabel.append(el('span', '', 'Mother'), motherName);
    const fatherLabel = el('div', 'parent-label');
    const fatherName = el('b', '', parentName(h.father));
    fatherLabel.append(el('span', '', 'Father'), fatherName);

    const sameSkin = h.skinMother === h.mother && h.skinFather === h.father;

    parentsGroup.append(
        motherLabel,
        parentStrip(mothers, h.mother, (p) => {
            if (h.skinMother === h.mother) h.skinMother = p.id;
            h.mother = p.id;
            motherName.textContent = p.name;
            setHeritage();
            commit();
        }),
        fatherLabel,
        parentStrip(fathers, h.father, (p) => {
            if (h.skinFather === h.father) h.skinFather = p.id;
            h.father = p.id;
            fatherName.textContent = p.name;
            setHeritage();
            commit();
        }),
    );

    const blendGroup = group('Blend', () => {
        h.shapeMix = 0.5;
        h.skinMix = 0.5;
        setHeritage();
        commit();
        renderStep();
    });
    blendGroup.append(
        slider({
            label: 'Resemblance', min: 0, max: 1, value: h.shapeMix, ends: ['Mother', 'Father'], format: pct,
            onInput: (v) => { h.shapeMix = v; setHeritage(); }, onCommit: commit,
        }).node,
        slider({
            label: 'Skin tone', min: 0, max: 1, value: h.skinMix, ends: ['Mother', 'Father'], format: pct,
            onInput: (v) => { h.skinMix = v; setHeritage(); }, onCommit: commit,
        }).node,
    );

    const skinGroup = group('Skin tone from');
    const tabs = el('div', 'subtabs');
    const holder = el('div', 'group');
    holder.style.padding = '0';
    holder.style.border = 'none';
    holder.style.background = 'none';

    const drawSkin = (custom) => {
        holder.replaceChildren();
        if (!custom) {
            holder.append(el('p', 'muted', 'The skin comes from the same parents as the face.'));
            return;
        }
        holder.append(
            el('div', 'parent-label', 'First tone'),
            parentStrip(s.parents, h.skinMother, (p) => { h.skinMother = p.id; setHeritage(); commit(); }),
            el('div', 'parent-label', 'Second tone'),
            parentStrip(s.parents, h.skinFather, (p) => { h.skinFather = p.id; setHeritage(); commit(); }),
        );
    };

    [['Same parents', false], ['Pick other faces', true]].forEach(([label, custom]) => {
        const tab = el('button', 'subtab', label);
        tab.type = 'button';
        tab.classList.toggle('is-active', sameSkin !== custom);
        tab.addEventListener('click', () => {
            tabs.querySelectorAll('.subtab').forEach((t) => t.classList.toggle('is-active', t === tab));
            if (!custom) {
                h.skinMother = h.mother;
                h.skinFather = h.father;
                setHeritage();
                commit();
            }
            drawSkin(custom);
        });
        tabs.append(tab);
    });
    drawSkin(!sameSkin);
    skinGroup.append(tabs, holder);

    body.append(sexGroup, parentsGroup, blendGroup, skinGroup);
}

function featureSlider(name) {
    const meta = FEATURES[name];
    const control = slider({
        label: meta.label, value: s.draft.features[name], ends: meta.ends,
        onInput: (v) => setFeature(name, v), onCommit: commit,
    });
    trackFeature(name, () => control.set(s.draft.features[name]));
    return control.node;
}

function renderFace() {
    FACE_GROUPS.forEach((section) => {
        const names = [...(section.pads || []).flat(), ...(section.sliders || [])];
        const node = group(section.title, () => {
            names.forEach((name) => setFeature(name, 0));
            commit();
        });

        (section.pads || []).forEach(([xName, yName]) => {
            const x = FEATURES[xName];
            const y = FEATURES[yName];
            const control = pad({
                x: s.draft.features[xName],
                y: s.draft.features[yName],
                labels: { left: x.ends[0], right: x.ends[1], top: y.ends[0], bottom: y.ends[1] },
                onInput: (vx, vy) => { setFeature(xName, vx); setFeature(yName, vy); },
                onCommit: commit,
            });
            const sync = () => control.set(s.draft.features[xName], s.draft.features[yName]);
            trackFeature(xName, sync);
            trackFeature(yName, sync);

            const row = el('div', 'padrow');
            const sliders = el('div', 'padrow__sliders');
            sliders.append(featureSlider(xName), featureSlider(yName));
            row.append(control.node, sliders);
            node.append(row);
        });

        (section.sliders || []).forEach((name) => node.append(featureSlider(name)));
        body.append(node);
    });
}

function overlayGroup(name, { palette, showColor = true } = {}) {
    const entry = s.draft.overlays[name];
    const info = s.catalog.overlays[name] || { max: 0 };

    const node = group(OVERLAYS[name], () => {
        entry.opacity = 0;
        setOverlay(name);
        commit();
        renderStep();
    });

    node.append(
        stepper({
            label: 'Style', value: entry.style, min: 0, max: info.max,
            onChange: (v) => {
                entry.style = v;
                if (entry.opacity === 0) entry.opacity = 1;
                setOverlay(name);
                commit();
                renderStep();
            },
        }).node,
        slider({
            label: 'Opacity', min: 0, max: 1, value: entry.opacity, format: pct,
            onInput: (v) => { entry.opacity = v; setOverlay(name); }, onCommit: commit,
        }).node,
    );

    if (showColor && info.colorType) {
        const colors = palette || (info.colorType === 1 ? s.catalog.hairColors : s.catalog.makeupColors);
        node.append(swatches({
            colors, value: entry.color,
            onChange: (i) => { entry.color = i; entry.secondColor = i; setOverlay(name); commit(); },
        }).node);
    }

    return node;
}

function renderSkin() {
    const eyes = group('Eye color');
    eyes.append(swatches({
        colors: EYE_COLORS.slice(0, s.eyeColors),
        value: s.draft.eyeColor,
        className: 'swatches--eyes',
        onChange: (i) => { s.draft.eyeColor = i; post('creator:eyes', { color: i }); commit(); },
    }).node);
    body.append(eyes);

    ['complexion', 'blemishes', 'moleAndFreckles', 'ageing', 'sunDamage', 'bodyBlemishes'].forEach((name) => {
        body.append(overlayGroup(name, { showColor: false }));
    });
}

function renderHair() {
    const hair = s.draft.hair;
    const hairGroup = group('Haircut');

    const textureStepper = stepper({
        label: 'Variant', value: hair.texture, min: 0, max: 0,
        onChange: (v) => { hair.texture = v; setHair(); commit(); },
    });

    const styleStepper = stepper({
        label: 'Style', value: hair.style, min: 0, max: Math.max(0, s.catalog.hairCount - 1),
        onChange: async (v) => {
            hair.style = v;
            hair.texture = 0;
            textureStepper.set(0);
            const textures = await setHair();
            textureStepper.setRange(0, Math.max(0, textures - 1));
            commit();
        },
    });

    hairGroup.append(styleStepper.node, textureStepper.node);
    setHair().then((textures) => textureStepper.setRange(0, Math.max(0, textures - 1)));

    const colorGroup = group('Hair color');
    const tabs = el('div', 'subtabs');
    const holder = el('div');
    const drawColors = (key) => {
        holder.replaceChildren(swatches({
            colors: s.catalog.hairColors, value: hair[key],
            onChange: (i) => { hair[key] = i; setHair(); commit(); },
        }).node);
    };
    [['Color', 'color'], ['Highlights', 'highlight']].forEach(([label, key], index) => {
        const tab = el('button', 'subtab', label);
        tab.type = 'button';
        tab.classList.toggle('is-active', index === 0);
        tab.addEventListener('click', () => {
            tabs.querySelectorAll('.subtab').forEach((t) => t.classList.toggle('is-active', t === tab));
            drawColors(key);
        });
        tabs.append(tab);
    });
    drawColors('color');
    colorGroup.append(tabs, holder);

    body.append(hairGroup, colorGroup, overlayGroup('eyebrows'));
    if (s.draft.sex === 'm') body.append(overlayGroup('beard'), overlayGroup('chestHair'));
}

function renderMakeup() {
    body.append(overlayGroup('makeUp'), overlayGroup('blush'), overlayGroup('lipstick'));
}

function renderClothes() {
    const looks = group('Starter looks');
    const grid = el('div', 'outfits');
    (s.catalog.outfits || []).forEach((outfit) => {
        const card = el('button', 'outfit');
        card.type = 'button';
        card.classList.toggle('is-active', s.draft.outfit === outfit.id);
        card.append(icon(outfit.icon), el('span', '', outfit.label));
        card.addEventListener('click', async () => {
            // A starter look is a whole new outfit: clear every piece first, so a tie or hat picked before doesn't stay on
            s.catalog.pieces.forEach((piece) => {
                const store = piece.kind === 'component' ? s.draft.components : s.draft.props;
                store[String(piece.id)] = { drawable: piece.kind === 'prop' ? -1 : 0, texture: 0 };
            });
            for (const [id, piece] of Object.entries(outfit.components || {})) {
                s.draft.components[id] = { drawable: piece[0], texture: piece[1] };
            }
            for (const [id, piece] of Object.entries(outfit.props || {})) {
                s.draft.props[id] = { drawable: piece[0], texture: piece[1] };
            }
            s.draft.outfit = outfit.id;
            await post('creator:apply', s.draft);
            commit();
            renderStep();
        });
        grid.append(card);
    });
    looks.append(grid);
    body.append(looks);

    const pieces = group('Pieces');
    s.catalog.pieces.forEach((piece) => {
        const store = piece.kind === 'component' ? s.draft.components : s.draft.props;
        const key = String(piece.id);
        if (!store[key]) store[key] = { drawable: piece.kind === 'prop' ? -1 : 0, texture: 0 };
        const entry = store[key];
        const minDrawable = piece.kind === 'prop' ? -1 : 0;

        const wrap = el('div', 'slider');
        const textureStepper = stepper({
            label: 'Color', value: entry.texture, min: 0, max: 0,
            onChange: (v) => { entry.texture = v; send(); commit(); },
        });

        const send = async () => {
            const result = await post('creator:piece', { kind: piece.kind, id: piece.id, drawable: entry.drawable, texture: entry.texture });
            const textures = result?.textures ?? 1;
            textureStepper.setRange(0, Math.max(0, textures - 1));
            textureStepper.node.classList.toggle('hidden', textures <= 1);
        };

        const drawableStepper = stepper({
            label: piece.label, value: entry.drawable, min: minDrawable, max: piece.count - 1,
            format: (v, lo, hi) => (v < 0 ? 'None' : `${v + 1} / ${hi + 1}`),
            onChange: (v) => {
                entry.drawable = v;
                entry.texture = 0;
                textureStepper.set(0);
                s.draft.outfit = null;
                send();
                commit();
            },
        });

        wrap.append(drawableStepper.node, textureStepper.node);
        textureStepper.node.classList.add('hidden');
        send();
        pieces.append(wrap);
    });
    body.append(pieces);
}

const RENDER = {
    heritage: renderHeritage,
    face: renderFace,
    skin: renderSkin,
    hair: renderHair,
    makeup: renderMakeup,
    clothes: renderClothes,
    identity: () => renderIdentity(body, s.identity, s.nationalities, s.draft.sex),
};

// ---------- layout ----------

function stepId() {
    return s.steps[s.step];
}

function renderSteps() {
    stepsNode.replaceChildren();
    s.steps.forEach((id, index) => {
        const button = el('button', 'step');
        button.type = 'button';
        button.classList.toggle('is-active', index === s.step);
        button.classList.toggle('is-done', index < s.step);
        button.append(el('span', 'step__num', String(index + 1)), el('span', '', STEPS[id].title));
        button.addEventListener('click', () => goTo(index));
        stepsNode.append(button);
    });
}

function renderStep() {
    const id = stepId();
    const meta = STEPS[id];
    featureControls = new Map();

    kicker.textContent = meta.kicker === 'Step' ? `Step ${s.step + 1} of ${s.steps.length}` : meta.kicker;
    title.textContent = meta.title;
    hint.textContent = meta.hint;

    body.replaceChildren();
    RENDER[id]();
    body.scrollTop = 0;

    const last = s.step === s.steps.length - 1;
    nextButton.textContent = last ? (s.mode === 'new' ? 'Create character' : 'Save look') : 'Next';
    backButton.textContent = s.step === 0 ? 'Cancel' : 'Back';
    backButton.classList.toggle('hidden', s.step === 0 && s.mode !== 'new');
    randomButton.disabled = id !== 'face' && id !== 'heritage';

    showPoints(id === 'face' && s.shot === 'face');
    renderSteps();
}

function setShot(id) {
    s.shot = id;
    document.querySelectorAll('#shots .tool').forEach((n) => n.classList.toggle('is-active', n.dataset.id === id));
    post('creator:shot', { name: id });
    showPoints(stepId() === 'face' && id === 'face');
}

function goTo(index) {
    if (index < 0 || index >= s.steps.length) return;
    s.step = index;
    const wanted = STEPS[stepId()].shot;
    if (wanted && wanted !== s.shot) setShot(wanted);
    renderStep();
}

function setupToolbar() {
    const shots = document.getElementById('shots');
    shots.replaceChildren();
    SHOTS.forEach((shot) => {
        const button = el('button', 'tool');
        button.type = 'button';
        button.dataset.id = shot.id;
        button.dataset.tip = shot.label;
        button.append(icon(shot.id));
        button.addEventListener('click', () => setShot(shot.id));
        shots.append(button);
    });

    const lights = document.getElementById('lights');
    lights.replaceChildren();
    LIGHTS.forEach((light, index) => {
        const button = el('button', 'tool');
        button.type = 'button';
        button.dataset.tip = light.label;
        const dot = el('span', 'tool__light');
        dot.style.background = light.color;
        button.append(dot);
        button.classList.toggle('is-active', index === 0);
        button.addEventListener('click', () => {
            lights.querySelectorAll('.tool').forEach((n) => n.classList.toggle('is-active', n === button));
            post('creator:lights', { name: light.id });
        });
        lights.append(button);
    });
}

nextButton.addEventListener('click', async () => {
    if (!s) return;
    if (s.step < s.steps.length - 1) {
        goTo(s.step + 1);
        return;
    }

    let identity = null;
    if (s.mode === 'new') {
        identity = identityValues(true);
        if (!identity) return;
    }

    nextButton.disabled = true;
    const result = await post('creator:finish', { draft: s.draft, identity });
    nextButton.disabled = false;

    if (!result?.ok) {
        const err = result?.error;
        if (err && ['firstname', 'lastname', 'birthdate', 'nationality'].includes(err)) {
            identityValues(true, err);
        }
        toast(ERRORS[err] || ERRORS.create);
    }
});

backButton.addEventListener('click', async () => {
    if (!s) return;
    if (s.step > 0) {
        goTo(s.step - 1);
        return;
    }

    if (s.mode !== 'new') return;
    const sure = await confirmModal('Leave the creator?', 'Your changes to this character will be lost.', 'Leave');
    if (sure) post('creator:cancel');
});

export function showCreator(data, nationalities) {
    s = {
        mode: data.mode,
        lockSex: data.lockSex,
        draft: data.draft,
        catalog: data.catalog,
        parents: data.parents || [],
        eyeColors: data.eyeColors || 13,
        identity: data.identity || {},
        nationalities: nationalities || [],
        steps: ['heritage', 'face', 'skin', 'hair', 'makeup', 'clothes'],
        step: 0,
        shot: 'body',
        undo: [],
        redo: [],
        saved: null,
    };
    if (s.mode === 'new') s.steps.push('identity');
    s.saved = snapshot();

    setupPoints(data.facePoints, {
        get: (name) => s.draft.features[name] ?? 0,
        set: setFeature,
        commit,
    });

    root.classList.remove('hidden');
    setupToolbar();
    drawHistory();
    goTo(0);
}

export function hideCreator() {
    root.classList.add('hidden');
    showPoints(false);
    s = null;
}

export function onFacePoints(points) {
    movePoints(points);
}
