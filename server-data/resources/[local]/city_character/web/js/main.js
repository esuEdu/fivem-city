import { applyTheme, post, postLatest } from './util.js';
import { showSelect, hideSelect } from './select.js';
import { showCreator, hideCreator, onFacePoints } from './creator.js';

const stage = document.getElementById('stage');
let nationalities = [];

// Dragging the empty screen turns the ped; the wheel zooms the camera
let rotating = false;
let lastX = 0;
let pendingDegrees = 0;

stage.addEventListener('pointerdown', (event) => {
    rotating = true;
    lastX = event.clientX;
    stage.setPointerCapture(event.pointerId);
});

stage.addEventListener('pointermove', (event) => {
    if (!rotating) return;
    const first = pendingDegrees === 0;
    pendingDegrees += (event.clientX - lastX) * 0.45;
    lastX = event.clientX;
    if (!first) return;

    // Add up the movement of one frame and send it once
    requestAnimationFrame(() => {
        const degrees = Math.max(-90, Math.min(90, pendingDegrees));
        pendingDegrees = 0;
        post('creator:rotate', { degrees });
    });
});

const stopRotating = () => { rotating = false; };
stage.addEventListener('pointerup', stopRotating);
stage.addEventListener('pointercancel', stopRotating);

stage.addEventListener('wheel', (event) => {
    postLatest('zoom', 'creator:zoom', { delta: event.deltaY < 0 ? 0.12 : -0.12 });
}, { passive: true });

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
    case 'select':
        if (data.theme) applyTheme(data.theme);
        nationalities = data.nationalities || nationalities;
        hideCreator();
        stage.classList.remove('hidden');
        showSelect(data);
        break;
    case 'creator':
        hideSelect();
        stage.classList.remove('hidden');
        showCreator(data, nationalities);
        break;
    case 'facePoints':
        onFacePoints(data.points);
        break;
    case 'hide':
        hideSelect();
        hideCreator();
        stage.classList.add('hidden');
        break;
    default:
        break;
    }
});
