// The rating prompt: stars, tags and a comment for the staff member who closed the player's report.

const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'city_staff';
const WORDS = ['', 'rating_1', 'rating_2', 'rating_3', 'rating_4', 'rating_5'];

const $ = (id) => document.getElementById(id);
let labels = {};
let stars = 0;
let tags = new Set();
let closeTimer = null;

const L = (key, ...args) => {
    let text = labels[key] ?? key;
    for (const arg of args) text = text.replace('%s', String(arg));
    return text;
};

function post(event, data = {}) {
    return fetch(`https://${RESOURCE}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((response) => response.json()).catch(() => null);
}

function applyTheme(theme) {
    for (const [key, value] of Object.entries(theme || {})) {
        document.documentElement.style.setProperty(`--${key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`, value);
    }
}

function initials(name) {
    return name.replace(/\(.*\)/, '').trim().split(/\s+/).map((part) => part[0] || '').join('').slice(0, 2).toUpperCase();
}

function drawStars() {
    $('rating-stars').querySelectorAll('button').forEach((button, i) => button.classList.toggle('on', i < stars));
    $('rating-word').textContent = stars ? L(WORDS[stars]) : '';
    $('rating-send').disabled = stars === 0;
}

function open(report) {
    clearTimeout(closeTimer);
    stars = 0;
    tags = new Set();

    $('rating-initials').textContent = initials(report.staff);
    $('rating-title').textContent = L('rating_title');
    $('rating-text').textContent = L('rating_text', report.staff.replace(/\s*\(.*\)$/, ''), report.id, report.message);
    $('rating-comment-label').textContent = L('rating_comment');
    $('rating-comment').placeholder = L('rating_comment_placeholder');
    $('rating-comment').value = '';
    $('rating-skip').textContent = L('rating_skip');
    $('rating-send').textContent = L('rating_send');

    $('rating-stars').replaceChildren(...[1, 2, 3, 4, 5].map((n) => {
        const button = document.createElement('button');
        button.textContent = '★';
        button.setAttribute('aria-label', L('rating_stars', n));
        button.addEventListener('click', () => {
            stars = n;
            drawStars();
        });
        return button;
    }));

    $('rating-tags').replaceChildren(...(report.tags || []).map((tag) => {
        const button = document.createElement('button');
        button.textContent = tag;
        button.addEventListener('click', () => {
            if (tags.has(tag)) tags.delete(tag);
            else tags.add(tag);
            button.classList.toggle('on', tags.has(tag));
        });
        return button;
    }));

    drawStars();
    $('ask').classList.remove('hidden');
    $('thanks').classList.add('hidden');
    $('rating').classList.remove('hidden');
}

function finish(sent) {
    $('thanks-title').textContent = L(sent ? 'rating_thanks' : 'rating_skipped');
    $('thanks-text').textContent = L('rating_thanks_text');
    $('ask').classList.add('hidden');
    $('thanks').classList.toggle('hidden', !sent);

    if (!sent) return post('closeRating');
    closeTimer = setTimeout(() => post('closeRating'), 1800);
}

$('rating-send').addEventListener('click', async () => {
    if (!stars) return;
    $('rating-send').disabled = true;
    await post('rate', { stars, tags: [...tags], comment: $('rating-comment').value });
    finish(true);
});

$('rating-skip').addEventListener('click', () => finish(false));

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !$('rating').classList.contains('hidden')) finish(false);
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data) return;

    if (data.action === 'askRating') {
        labels = data.labels || {};
        applyTheme(data.theme);
        open(data.report);
    } else if (data.action === 'hideRating') {
        $('rating').classList.add('hidden');
    }
});
