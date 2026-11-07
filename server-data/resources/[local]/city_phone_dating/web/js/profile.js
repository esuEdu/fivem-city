// Your profile: making it the first time, editing it (3 photo slots, name, bio, who you want to see), deleting it
import {
    state, call, t, h, button, icon, input, toast, openSheet, closeSheet, navBar, backButton, lazyImage, photo, forgetPhotos, photoGrid,
} from './lib.js';

const MAX_PHOTOS = 3;
const INTERESTS = ['women', 'men', 'everyone'];

// slots[i]: { keep: true } (already saved), { id } (one of your photos, new), or null (empty)
export function profileForm(onDone) {
    const me = state.me;
    const form = {
        name: me?.name || '',
        bio: me?.bio || '',
        interest: me?.interest || 'everyone',
        slots: Array.from({ length: MAX_PHOTOS }, (_, index) => (me?.photos?.includes(index + 1) ? { keep: true } : null)),
        removed: new Set(),
    };

    const content = document.createElement('div');

    const draw = () => {
        const tiles = form.slots.map((slot, index) => {
            let picture = h('span', 'slot__empty', null, icon('plus'));
            if (slot?.keep) picture = lazyImage('slot__image', () => photo(me.id, index + 1));
            if (slot?.id) picture = lazyImage('slot__image', () => call('myPhoto', { id: slot.id }).then((r) => (r.ok ? r.result : null)));

            const tile = button('slot', null, () => openSheet(
                navBar(backButton(t('back'), closeSheet), t('profile.pick'), null),
                photoGrid((id) => {
                    form.slots[index] = { id };
                    form.removed.delete(index + 1);
                    closeSheet();
                    draw();
                }),
            ), picture);

            if (slot) {
                tile.append(button('slot__remove', null, (event) => {
                    event.stopPropagation();
                    if (slot.keep) form.removed.add(index + 1);
                    form.slots[index] = null;
                    draw();
                }, icon('close')));
            }

            return tile;
        });

        const name = input('k-field', t('profile.name'), 30);
        name.value = form.name;
        name.addEventListener('input', () => { form.name = name.value; });

        const bio = document.createElement('textarea');
        bio.className = 'k-field bio';
        bio.maxLength = 300;
        bio.placeholder = t('profile.bio');
        bio.value = form.bio;
        bio.addEventListener('input', () => { form.bio = bio.value; });

        const interests = INTERESTS.map((value) => button(`chip${form.interest === value ? ' chip--on' : ''}`, t(`interest.${value}`), () => {
            form.interest = value;
            draw();
        }));

        content.replaceChildren(
            h('p', 'k-group__label', t('profile.photos')),
            h('div', 'slots', null, tiles),
            h('div', 'k-group', null, name, bio),
            h('p', 'k-group__label', t('profile.show')),
            h('div', 'chips', null, interests),
            h('p', 'hint', t('profile.ageHint')),
            button('k-button save', t(me ? 'profile.save' : 'profile.create'), save),
            me ? button('k-link k-link--danger delete', t('profile.delete'), remove) : null,
        );
    };

    const save = async () => {
        if (!form.name.trim()) return toast(t('error.name'));

        const photos = form.slots.map((slot, index) => {
            if (slot?.id) return slot.id;
            if (slot?.keep) return 'keep';
            return form.removed.has(index + 1) ? false : 'keep';
        });

        if (!form.slots.some(Boolean)) return toast(t('error.photo'));

        const result = await call('save', { profile: { name: form.name, bio: form.bio, interest: form.interest, photos } });
        if (!result.ok) return toast(t(`error.${result.reason || 'invalid'}`));

        if (me) forgetPhotos(me.id);
        toast(t('profile.saved'));
        await onDone();
    };

    // Deleting takes matches and chats too, so it needs a second tap
    let armed = false;
    const remove = async () => {
        if (!armed) {
            armed = true;
            setTimeout(() => { armed = false; }, 4000);
            return toast(t('profile.deleteConfirm'));
        }

        if (!(await call('deleteProfile')).ok) return toast(t('error.invalid'));
        if (me) forgetPhotos(me.id);
        await onDone();
    };

    draw();
    return content;
}

export function welcome(onDone) {
    return [
        h('div', 'welcome', null,
            h('div', 'welcome__logo', null, icon('heartFilled')),
            h('h1', 'welcome__title', 'Matchy'),
            h('p', 'welcome__text', t('welcome.text')),
        ),
        profileForm(onDone),
    ];
}
