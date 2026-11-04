import { state, el } from './state.js';
import { formatPrice } from './util.js';

// The "how many?" window used to buy from a shop and to split a stack

let current = null;

export function isDialogOpen() {
    return current !== null;
}

function amount() {
    const value = Number.parseInt(el.dialog.input.value, 10);
    return Math.min(current.max, Math.max(1, Number.isNaN(value) ? 1 : value));
}

function render() {
    const { item } = current;
    const count = amount();

    el.dialog.total.textContent = item.price !== undefined
        ? `${state.labels.total}: ${formatPrice({ ...item, price: item.price * count }, state.labels)}`
        : `${count} / ${item.count}`;
}

// The item card sits under the window and shows through it, so it's hidden while the window is open (see style.css)
function setOpen(open) {
    el.dialog.root.classList.toggle('hidden', !open);
    document.body.classList.toggle('dialog-open', open);
}

export function closeDialog() {
    current = null;
    setOpen(false);
}

function confirm() {
    if (!current) return;

    const { onConfirm } = current;
    const count = amount();
    closeDialog();
    onConfirm(count);
}

// options: { title, confirmLabel, item, max, onConfirm(count) }
export function openDialog({ title, confirmLabel, item, max, onConfirm }) {
    current = { item, max, onConfirm };

    el.dialog.title.textContent = title;
    el.dialog.label.textContent = item.label;
    el.dialog.image.src = `images/${item.image}`;
    el.dialog.max.textContent = `${state.labels.max} (${max})`;
    el.dialog.confirm.textContent = confirmLabel;
    el.dialog.cancel.textContent = state.labels.cancel;
    el.dialog.input.max = max;
    el.dialog.input.value = 1;

    render();
    setOpen(true);
    el.dialog.input.focus();
    el.dialog.input.select();
}

function step(delta) {
    el.dialog.input.value = Math.min(current.max, Math.max(1, amount() + delta));
    render();
}

el.dialog.input.addEventListener('input', render);
el.dialog.minus.addEventListener('click', () => step(-1));
el.dialog.plus.addEventListener('click', () => step(1));
el.dialog.max.addEventListener('click', () => step(current.max));
el.dialog.confirm.addEventListener('click', confirm);
el.dialog.cancel.addEventListener('click', closeDialog);

// A click on the dark background cancels
el.dialog.root.addEventListener('pointerdown', (event) => {
    if (event.target === el.dialog.root) closeDialog();
});

el.dialog.input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        event.preventDefault();
        confirm();
    }
});
