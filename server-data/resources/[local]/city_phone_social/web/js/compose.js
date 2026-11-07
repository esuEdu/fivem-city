// New post (a photo of yours and a caption) or new story (a photo, up for 24 hours)
import { call, t, h, button, toast, openSheet, closeSheet, navBar, backButton, lazyImage, photoGrid } from './lib.js';

let refresh = async () => {};

export function setRefresh(fn) {
    refresh = fn;
}

function captionStep(kind, photo) {
    const caption = document.createElement('textarea');
    caption.className = 'k-field caption';
    caption.maxLength = 300;
    caption.placeholder = t('compose.caption');

    let sending = false;

    const share = button('k-link', t('compose.share'), async () => {
        if (sending) return;
        sending = true;

        const result = await call('publish', { kind, photo, caption: caption.value });
        sending = false;

        if (!result.ok) return toast(t(result.reason === 'slow' ? 'error.slowPost' : 'error.invalid'));

        toast(t(kind === 'story' ? 'compose.storyShared' : 'compose.shared'));
        closeSheet();
        await refresh();
    });

    openSheet(
        navBar(backButton(t('back'), () => openCompose(kind)), t(kind === 'story' ? 'compose.newStory' : 'compose.newPost'), share),
        lazyImage('compose__image', () => call('myPhoto', { id: photo }).then((r) => (r.ok ? r.result : null))),
        kind === 'post' ? h('div', 'k-group', null, caption) : h('p', 'hint', t('compose.storyHint')),
    );
}

export function openCompose(kind = 'post') {
    openSheet(
        navBar(button('k-link', t('cancel'), closeSheet), t(kind === 'story' ? 'compose.newStory' : 'compose.newPost'), null),
        h('p', 'k-group__label', t('compose.pick')),
        photoGrid((id) => captionStep(kind, id)),
    );
}
