// The stories bar at the top of the feed and the full-screen viewer (5 seconds each, tap for the next)
import { state, call, t, h, button, icon, toast, ago, image, avatar } from './lib.js';
import { openCompose } from './compose.js';

const STORY_MS = 5000;

let viewer = null;
let timer = null;

function closeViewer() {
    clearTimeout(timer);
    viewer?.remove();
    viewer = null;
}

function show(people, personIndex, storyIndex) {
    const person = people[personIndex];
    if (!person) return closeViewer();

    const story = person.stories[storyIndex];
    if (!story) return show(people, personIndex + 1, 0);

    clearTimeout(timer);

    const img = document.createElement('img');
    img.className = 'story__image';
    image(story.id).then((data) => { if (data) img.src = data; });

    const bars = h('div', 'story__bars', null, person.stories.map((_, index) => h('span', `story__bar${index < storyIndex ? ' story__bar--done' : ''}${index === storyIndex ? ' story__bar--now' : ''}`)));

    const remove = person.mine || state.staff ? button('story__delete', null, async (event) => {
        event.stopPropagation();
        if (!(await call('deletePost', { id: story.id })).ok) return toast(t('error.invalid'));
        person.stories.splice(storyIndex, 1);
        show(people, personIndex, storyIndex);
    }, icon('trash')) : null;

    if (!viewer) {
        viewer = h('div', 'story');
        document.body.append(viewer);
    }

    viewer.replaceChildren(
        img,
        bars,
        h('div', 'story__head', null,
            avatar(person.username, person.name, 'small'),
            h('span', 'story__user', person.username),
            h('span', 'story__time', ago(story.createdAt)),
            remove,
            button('story__close', null, (event) => { event.stopPropagation(); closeViewer(); }, icon('close')),
        ),
    );

    viewer.onclick = (event) => {
        // Left third goes back, the rest goes forward
        if (event.clientX < viewer.clientWidth / 3) show(people, storyIndex > 0 ? personIndex : Math.max(0, personIndex - 1), Math.max(0, storyIndex - 1));
        else show(people, personIndex, storyIndex + 1);
    };

    timer = setTimeout(() => show(people, personIndex, storyIndex + 1), STORY_MS);
}

export function storiesBar() {
    const people = state.stories;
    const mine = people.find((person) => person.mine);

    const add = button('stories__item', null, () => (mine ? show(people, people.indexOf(mine), 0) : openCompose('story')),
        h('span', `stories__ring${mine ? '' : ' stories__ring--none'}`, null, avatar(state.me.username, state.me.name)),
        h('span', 'stories__name', t('stories.yours')),
    );

    const plus = button('stories__add', null, (event) => { event.stopPropagation(); openCompose('story'); }, icon('plus'));
    add.append(plus);

    return h('div', 'stories', null,
        add,
        people.filter((person) => !person.mine).map((person) => button('stories__item', null, () => show(people, people.indexOf(person), 0),
            h('span', 'stories__ring', null, avatar(person.username, person.name)),
            h('span', 'stories__name', person.username),
        )),
    );
}
