// The Notes page: the list (pinned first, with search) and the editor, which saves when you go back
import {
    h, button, icon, toast, navBar, backButton, applyContext,
} from 'https://cfx-nui-city_phone/web/kit/kit.js';

const RESOURCE = 'city_phone_notes';
const TEXTS = {
    en: {
        title: 'Notes', pinned: 'Pinned', notes: 'Notes', search: 'Search', empty: 'No notes yet', back: 'Notes',
        untitled: 'New Note', titlePlaceholder: 'Title', bodyPlaceholder: 'Start typing...', full: 'You have too many notes',
        count: '%s notes', delete: 'Delete', pin: 'Pin', unpin: 'Unpin',
    },
    'pt-br': {
        title: 'Notas', pinned: 'Fixadas', notes: 'Notas', search: 'Buscar', empty: 'Nenhuma nota ainda', back: 'Notas',
        untitled: 'Nova Nota', titlePlaceholder: 'Título', bodyPlaceholder: 'Comece a escrever...', full: 'Você tem notas demais',
        count: '%s notas', delete: 'Apagar', pin: 'Fixar', unpin: 'Desafixar',
    },
};

const state = { notes: [], query: '', language: 'en', editing: null };

function t(key, value) {
    const text = (TEXTS[state.language] || TEXTS.en)[key] ?? TEXTS.en[key] ?? key;
    return text.replace('%s', value ?? '');
}

async function call(name, data = {}) {
    try {
        const response = await fetch(`https://${RESOURCE}/${name}`, { method: 'POST', body: JSON.stringify(data) });
        return await response.json();
    } catch {
        return { ok: false };
    }
}

function when(at) {
    const date = new Date(at * 1000);
    const today = new Date();
    const locale = state.language === 'pt-br' ? 'pt-BR' : 'en-US';

    if (date.toDateString() === today.toDateString()) return date.toLocaleTimeString(locale, { hour: '2-digit', minute: '2-digit' });
    return date.toLocaleDateString(locale, { day: 'numeric', month: 'short' });
}

function preview(note) {
    const firstLine = (note.body || '').split('\n').find((line) => line.trim()) || '';
    return firstLine.slice(0, 60);
}

function row(note) {
    return button('k-row note', null, () => openEditor(note),
        h('span', 'note__main', null,
            h('span', 'note__title', note.title || preview(note) || t('untitled')),
            h('span', 'note__sub', null, h('span', 'note__date', when(note.updated_at)), h('span', '', note.title ? preview(note) : '')),
        ),
        note.pinned ? h('span', 'note__pin', null, icon('pinFilled')) : null,
    );
}

function renderList() {
    const query = state.query.toLowerCase();
    const list = state.notes.filter((note) => `${note.title} ${note.body}`.toLowerCase().includes(query));
    const pinned = list.filter((note) => note.pinned);
    const others = list.filter((note) => !note.pinned);

    const search = h('input');
    Object.assign(search, { placeholder: t('search'), value: state.query });
    search.addEventListener('input', () => {
        state.query = search.value;
        renderList();
        document.querySelector('.k-search input')?.focus();
    });

    document.getElementById('content').replaceChildren(...[
        navBar(null, null, null),
        h('h1', 'k-large-title', t('title')),
        h('label', 'k-search', null, icon('search'), search),
        pinned.length ? h('div', 'k-group__label', t('pinned')) : null,
        pinned.length ? h('div', 'k-group', null, pinned.map(row)) : null,
        others.length && pinned.length ? h('div', 'k-group__label', t('notes')) : null,
        others.length ? h('div', 'k-group', null, others.map(row)) : null,
        list.length === 0 ? h('div', 'k-empty', null, icon('note'), h('span', '', t('empty'))) : null,
    ].filter(Boolean));

    document.getElementById('footer').replaceChildren(
        h('span', '', t('count', state.notes.length)),
        button('compose', null, () => openEditor({ title: '', body: '' }), icon('compose')),
    );
}

async function closeEditor() {
    const note = state.editing;
    const editor = document.getElementById('editor');
    state.editing = null;
    editor.classList.remove('editor--open');

    if (!note) return;

    const title = editor.querySelector('.editor__title').value.trim();
    const body = editor.querySelector('.editor__body').value;
    const changed = title !== (note.title || '') || body !== (note.body || '');

    if (changed) {
        const result = await call('save', { note: { id: note.id, title, body } });
        if (!result.ok && result.reason === 'full') toast(t('full'));
    }

    await refresh();
}

function openEditor(note) {
    state.editing = note;

    const title = h('input', 'editor__title');
    Object.assign(title, { placeholder: t('titlePlaceholder'), value: note.title || '', maxLength: 60 });

    const body = h('textarea', 'editor__body');
    Object.assign(body, { placeholder: t('bodyPlaceholder'), value: note.body || '', maxLength: 5000 });

    const actions = note.id ? h('span', 'editor__actions', null,
        button('k-link', null, async () => {
            await call('pin', { id: note.id, pinned: !note.pinned });
            note.pinned = !note.pinned;
            openEditor({ ...note, title: title.value, body: body.value });
        }, icon(note.pinned ? 'pinFilled' : 'pin')),
        button('k-link k-link--danger', null, async () => {
            await call('delete', { id: note.id });
            state.editing = null;
            document.getElementById('editor').classList.remove('editor--open');
            await refresh();
        }, icon('trash')),
    ) : null;

    const editor = document.getElementById('editor');
    editor.replaceChildren(navBar(backButton(t('back'), closeEditor), null, actions), title, body);
    editor.classList.add('editor--open');
    (note.id ? body : title).focus();
}

async function refresh() {
    const result = await call('list');
    if (result.ok) state.notes = result.result || [];
    renderList();
}

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.type !== 'city_phone:context') return;

    applyContext(message);
    state.language = message.language === 'pt-br' ? 'pt-br' : 'en';
    renderList();
});

refresh();
