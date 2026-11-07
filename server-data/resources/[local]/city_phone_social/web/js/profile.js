// Profiles (yours and others'), following, editing your profile and making your account the first time
import {
    state, call, t, h, button, icon, input, toast, openSheet, closeSheet, navBar, backButton,
    image, lazyImage, avatar, forgetAvatar, photoGrid,
} from './lib.js';
import { openPost } from './post.js';

let refresh = async () => {};

export function setRefresh(fn) {
    refresh = fn;
}

function stat(value, label) {
    return h('div', 'stat', null, h('strong', '', String(value)), h('span', '', label));
}

export function grid(posts) {
    if (!posts.length) return h('div', 'k-empty', null, icon('photo'), h('span', '', t('profile.noPosts')));

    return h('div', 'grid', null, posts.map((post) => button('grid__tile', null, () => openPost(post),
        lazyImage('grid__image', () => image(post.id)),
    )));
}

// The profile header and grid, used for your own tab and for other people's sheets
export async function profileView(username) {
    const [profile, posts] = await Promise.all([call('profile', { username }), call('posts', { scope: 'user', username })]);
    if (!profile.ok) return [h('div', 'k-empty', null, icon('person'), h('span', '', t('profile.missing')))];

    const data = profile.result;
    const list = posts.ok && Array.isArray(posts.result) ? posts.result : [];

    const followButton = data.mine
        ? button('k-button profile__button profile__button--plain', t('profile.edit'), () => editProfile(data))
        : button(`k-button profile__button${data.followed ? ' profile__button--plain' : ''}`, t(data.followed ? 'profile.following' : 'profile.follow'), async () => {
            if (!(await call('follow', { username: data.username, follow: !data.followed })).ok) return toast(t('error.invalid'));
            await refresh();
            if (!data.mine) openProfile(data.username);
        });

    return [
        h('div', 'profile', null,
            avatar(data.username, data.name, 'big'),
            h('div', 'profile__stats', null,
                stat(data.posts, t('profile.posts')),
                stat(data.followers, t('profile.followers')),
                stat(data.following, t('profile.followingCount')),
            ),
        ),
        h('div', 'profile__name', data.name),
        data.bio ? h('p', 'profile__bio', data.bio) : null,
        followButton,
        grid(list),
    ];
}

export async function openProfile(username) {
    openSheet(navBar(backButton(t('back'), closeSheet), `@${username}`, null), h('div', 'k-empty', null, h('span', '', t('compose.loading'))));
    const view = await profileView(username);
    openSheet(navBar(backButton(t('back'), closeSheet), `@${username}`, null), view);
}

export function editProfile(data) {
    const form = { name: data.name, bio: data.bio || '', avatar: undefined };

    const draw = () => {
        const name = input('k-field', t('profile.name'), 30);
        name.value = form.name;
        name.addEventListener('input', () => { form.name = name.value; });

        const bio = document.createElement('textarea');
        bio.className = 'k-field bio';
        bio.maxLength = 150;
        bio.placeholder = t('profile.bio');
        bio.value = form.bio;
        bio.addEventListener('input', () => { form.bio = bio.value; });

        const save = button('k-link', t('save'), async () => {
            if (!form.name.trim()) return toast(t('error.name'));
            if (!(await call('editProfile', { name: form.name, bio: form.bio, avatar: form.avatar })).ok) return toast(t('error.invalid'));

            forgetAvatar(data.username);
            closeSheet();
            await refresh();
        });

        openSheet(
            navBar(button('k-link', t('cancel'), closeSheet), t('profile.edit'), save),
            h('div', 'k-group', null,
                button('k-row k-row--accent', t('profile.changePhoto'), () => openSheet(
                    navBar(backButton(t('back'), draw), t('compose.pick'), null),
                    photoGrid((id) => { form.avatar = id; draw(); }),
                )),
                button('k-row k-row--danger', t('profile.removePhoto'), () => { form.avatar = false; draw(); }),
            ),
            form.avatar !== undefined ? h('p', 'hint', t(form.avatar === false ? 'profile.photoRemoved' : 'profile.photoPicked')) : null,
            h('div', 'k-group', null, name, bio),
        );
    };

    draw();
}

// First time: pick @username and name
export function welcome(onDone) {
    const username = input('k-field', t('welcome.username'), 20);
    const name = input('k-field', t('welcome.name'), 30);
    username.addEventListener('input', () => { username.value = username.value.toLowerCase().replace(/[^a-z0-9._]/g, ''); });

    return [
        h('div', 'welcome', null,
            h('div', 'welcome__logo', 'InstaPic'),
            h('p', 'welcome__text', t('welcome.text')),
        ),
        h('div', 'k-group', null, username, name),
        h('p', 'hint', t('welcome.hint')),
        button('k-button welcome__button', t('welcome.create'), async () => {
            const result = await call('createAccount', { username: username.value, name: name.value });
            if (!result.ok) return toast(t(`error.${result.reason || 'invalid'}`));
            await onDone();
        }),
    ];
}
