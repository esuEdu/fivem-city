// A post in the feed (photo, like, comments, caption), one post on its own page, and its comments
import {
    state, call, t, h, button, iconButton, icon, toast, openSheet, closeSheet, navBar, backButton, ago, image, lazyImage, avatar,
} from './lib.js';
import { openProfile } from './profile.js';

let refresh = async () => {};

export function setRefresh(fn) {
    refresh = fn;
}

function userLink(post) {
    return button('post__user', null, () => openProfile(post.username),
        avatar(post.username, post.name, 'small'),
        h('span', 'post__username', post.username),
    );
}

async function remove(post) {
    if (!(await call('deletePost', { id: post.id })).ok) return toast(t('error.invalid'));
    toast(t(post.mine ? 'post.deleted' : 'post.removed'));
    closeSheet();
    await refresh();
}

export function postCard(post) {
    const likeIcon = h('span', 'post__like', null, icon(post.liked ? 'heartFilled' : 'heart'));
    const likes = h('span', 'post__likes', t('post.likes', post.likes));

    const toggleLike = async () => {
        const liked = !post.liked;
        if (!(await call('like', { id: post.id, liked })).ok) return;

        post.liked = liked;
        post.likes += liked ? 1 : -1;
        likeIcon.replaceChildren(icon(liked ? 'heartFilled' : 'heart'));
        likeIcon.classList.toggle('post__like--on', liked);
        likes.textContent = t('post.likes', post.likes);
    };

    likeIcon.classList.toggle('post__like--on', post.liked);

    const photo = lazyImage('post__image', () => image(post.id));
    photo.addEventListener('dblclick', () => { if (!post.liked) toggleLike(); });

    const canDelete = post.mine || state.staff;

    return h('article', 'post', null,
        h('div', 'post__head', null,
            userLink(post),
            canDelete ? iconButton('post__more', post.mine ? 'trash' : 'block', () => remove(post), t(post.mine ? 'post.delete' : 'post.staffRemove')) : null,
        ),
        photo,
        h('div', 'post__actions', null,
            button('post__action', null, toggleLike, likeIcon),
            button('post__action', null, () => openComments(post), icon('message')),
        ),
        likes,
        post.caption ? h('p', 'post__caption', null, h('strong', '', `${post.username} `), document.createTextNode(post.caption)) : null,
        post.comments > 0 ? button('post__more-comments', t('post.comments', post.comments), () => openComments(post)) : null,
        h('span', 'post__time', ago(post.createdAt)),
    );
}

export function openPost(post) {
    openSheet(
        navBar(backButton(t('back'), closeSheet), t('post.title'), null),
        postCard(post),
    );
}

export async function openComments(post) {
    const list = h('div', 'comments');
    const field = h('input', 'comments__input');
    Object.assign(field, { placeholder: t('comments.placeholder'), maxLength: 200 });

    const load = async () => {
        const result = await call('comments', { id: post.id });
        const rows = result.ok && Array.isArray(result.result) ? result.result : [];

        list.replaceChildren(...(rows.length ? rows.reverse().map((comment) => h('div', 'comment', null,
            avatar(comment.username, comment.username, 'small'),
            h('div', 'comment__body', null,
                h('p', 'comment__text', null, h('strong', '', `${comment.username} `), document.createTextNode(comment.text)),
                h('span', 'comment__time', ago(comment.createdAt)),
            ),
            comment.canDelete || state.staff ? iconButton('comment__delete', 'trash', async () => {
                if (!(await call('deleteComment', { id: comment.id })).ok) return toast(t('error.invalid'));
                post.comments = Math.max(0, post.comments - 1);
                load();
            }) : null,
        )) : [h('div', 'k-empty', null, icon('message'), h('span', '', t('comments.empty')))]));
    };

    const send = async () => {
        const text = field.value.trim();
        if (!text) return;

        const result = await call('comment', { id: post.id, text });
        if (!result.ok) return toast(t(result.reason === 'slow' ? 'error.slow' : 'error.invalid'));

        field.value = '';
        post.comments += 1;
        load();
    };

    field.addEventListener('keydown', (event) => { if (event.key === 'Enter') send(); });

    openSheet(
        navBar(backButton(t('back'), async () => { closeSheet(); await refresh(); }), t('comments.title'), null),
        list,
        h('div', 'comments__bar', null, field, iconButton('comments__send', 'send', send)),
    );

    load();
}
