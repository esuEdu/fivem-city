import { post } from './util.js';

// On the empty screen: left drag moves the camera around the ped and up or down (to see past someone in the way),
// right drag turns the ped, the wheel zooms and a double click puts the camera back
export function stageControls(stage) {
    let drag = null;
    let pending = { x: 0, y: 0, turn: 0 };
    let flushing = false;

    // Moves pile up and go to the game once per frame
    function flush() {
        flushing = false;
        const { x, y, turn } = pending;
        pending = { x: 0, y: 0, turn: 0 };
        if (x || y) post('moveCamera', { degrees: x * 0.35, metres: -y * 0.004 });
        if (turn) post('rotate', { degrees: turn * 0.5 });
    }

    stage.addEventListener('contextmenu', (event) => event.preventDefault());
    stage.addEventListener('pointerdown', (event) => {
        drag = { x: event.clientX, y: event.clientY, turn: event.button === 2 };
        stage.setPointerCapture(event.pointerId);
    });
    stage.addEventListener('pointermove', (event) => {
        if (!drag) return;
        const dx = event.clientX - drag.x;
        const dy = event.clientY - drag.y;
        drag.x = event.clientX;
        drag.y = event.clientY;

        if (drag.turn) {
            pending.turn += dx;
        } else {
            pending.x += dx;
            pending.y += dy;
        }

        if (!flushing) {
            flushing = true;
            requestAnimationFrame(flush);
        }
    });
    stage.addEventListener('pointerup', () => { drag = null; });
    stage.addEventListener('dblclick', () => post('resetCamera'));
    stage.addEventListener('wheel', (event) => post('zoom', { delta: event.deltaY < 0 ? 0.15 : -0.15 }), { passive: true });
}
