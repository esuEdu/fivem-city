// One article (like, comments, edit/delete when allowed) and the editor journalists write in
import {
    state, call, t, h, button, iconButton, icon, input, toast, openSheet, closeSheet, navBar, backButton, CATEGORIES, ago,
} from './lib.js';

let refresh = async () => {};

export function setRefresh(fn) {
    refresh = fn;
}

function reasonText(reason) {
    return t(`error.${reason || 'invalid'}`);
}

async function loadComments(article, list) {
    const result = await call('comments', { id: article.id });
    const rows = result.ok && Array.isArray(result.result) ? result.result : [];

    list.replaceChildren(...(rows.length ? rows.map((comment) => h('div', 'comment', null,
        h('div', 'comment__head', null,
            h('strong', '', comment.name),
            h('span', 'comment__time', ago(comment.createdAt)),
            comment.canDelete ? iconButton('comment__delete', 'trash', async () => {
                if (!(await call('deleteComment', { id: comment.id })).ok) return toast(reasonText());
                loadComments(article, list);
            }) : null,
        ),
        h('p', 'comment__text', comment.text),
    )) : [h('p', 'comments__empty', t('comments.empty'))]));
}

export async function openArticle(id) {
    const result = await call('article', { id });
    if (!result.ok) return toast(t('error.gone'));

    const article = result.result;

    const likeIcon = h('span', `like${article.liked ? ' like--on' : ''}`, null, icon(article.liked ? 'heartFilled' : 'heart'));
    const likeCount = h('span', '', String(article.likes));

    const like = button('article__like', null, async () => {
        const liked = !article.liked;
        if (!(await call('like', { id: article.id, liked })).ok) return;
        article.liked = liked;
        article.likes += liked ? 1 : -1;
        likeIcon.replaceChildren(icon(liked ? 'heartFilled' : 'heart'));
        likeIcon.classList.toggle('like--on', liked);
        likeCount.textContent = String(article.likes);
    }, likeIcon, likeCount);

    const list = h('div', 'comments');
    const field = h('input', 'comments__input');
    Object.assign(field, { placeholder: t('comments.placeholder'), maxLength: 300 });

    const send = async () => {
        const text = field.value.trim();
        if (!text) return;
        const sent = await call('comment', { id: article.id, text });
        if (!sent.ok) return toast(reasonText(sent.reason));
        field.value = '';
        loadComments(article, list);
    };

    field.addEventListener('keydown', (event) => { if (event.key === 'Enter') send(); });

    const tools = [
        article.canEdit ? button('k-row k-row--accent', t('article.edit'), () => openEditor(article)) : null,
        article.canDelete ? button('k-row k-row--danger', t('article.delete'), async () => {
            if (!(await call('delete', { id: article.id })).ok) return toast(reasonText());
            toast(t('article.deleted'));
            closeSheet();
            await refresh();
        }) : null,
    ].filter(Boolean);

    openSheet(
        navBar(backButton(t('back'), closeSheet), null, null),
        article.breaking ? h('span', 'tag tag--breaking', t('breaking')) : null,
        h('span', 'tag', t(`category.${article.category}`)),
        h('h1', 'article__title', article.title),
        h('div', 'article__meta', t('article.by', article.author, ago(article.createdAt))),
        article.updatedAt ? h('div', 'article__meta', t('article.updated', ago(article.updatedAt))) : null,
        h('div', 'article__body', article.body),
        like,
        tools.length ? h('div', 'k-group', null, tools) : null,
        h('p', 'k-group__label', t('comments.title')),
        h('div', 'comments__bar', null, field, iconButton('comments__send', 'send', send)),
        list,
    );

    loadComments(article, list);
}

// Writing a new article (no id) or editing yours
export function openEditor(article = {}) {
    const editing = article.id !== undefined;
    const form = { title: article.title || '', body: article.body || '', category: article.category || null, breaking: false };

    const draw = () => {
        const title = input('k-field', t('editor.title'), 80);
        title.value = form.title;
        title.addEventListener('input', () => { form.title = title.value; });

        const body = document.createElement('textarea');
        body.className = 'k-field editor__body';
        body.maxLength = 3000;
        body.placeholder = t('editor.body');
        body.value = form.body;
        body.addEventListener('input', () => { form.body = body.value; });

        const chips = CATEGORIES.map((category) => button(`chip${form.category === category ? ' chip--on' : ''}`, t(`category.${category}`), () => {
            form.category = category;
            draw();
        }));

        const breakingMark = h('span', `k-check${form.breaking ? ' k-check--on' : ''}`, null, icon('check'));

        const publish = button('k-link', t(editing ? 'editor.save' : 'editor.publish'), async () => {
            if (!form.title.trim() || !form.body.trim()) return toast(t('editor.needText'));
            if (!form.category) return toast(t('editor.needCategory'));

            const data = { title: form.title, body: form.body, category: form.category, breaking: form.breaking };
            const result = editing ? await call('edit', { id: article.id, article: data }) : await call('publish', { article: data });
            if (!result.ok) return toast(reasonText(result.reason));

            toast(t(editing ? 'editor.saved' : 'editor.published'));
            closeSheet();
            await refresh();
        });

        openSheet(
            navBar(button('k-link', t('cancel'), closeSheet), t(editing ? 'editor.editTitle' : 'editor.newTitle'), publish),
            h('div', 'k-group', null, title),
            h('p', 'k-group__label', t('editor.category')),
            h('div', 'chips chips--wrap', null, chips),
            h('div', 'k-group', null, body),
            editing ? null : h('div', 'k-group', null, button('k-row', null, () => {
                form.breaking = !form.breaking;
                draw();
            }, h('span', '', t('editor.breaking')), breakingMark)),
            editing ? null : h('p', 'hint', t('editor.breakingHint')),
        );
    };

    draw();
}
