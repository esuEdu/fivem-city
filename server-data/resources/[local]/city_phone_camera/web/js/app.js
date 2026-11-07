// The Camera app page: pressing the shutter starts camera mode in the game (the phone steps aside)
import { applyContext } from 'https://cfx-nui-city_phone/web/kit/kit.js';

const TEXTS = {
    en: { hint: 'Press the shutter to open the camera. Photos go to the Photos app.', keys: 'In camera: E selfie, arrows filters, scroll zoom' },
    'pt-br': { hint: 'Aperte o botão para abrir a câmera. As fotos vão para o app Fotos.', keys: 'Na câmera: E selfie, setas filtros, scroll zoom' },
};

function setLanguage(language) {
    const texts = TEXTS[language] || TEXTS.en;
    document.getElementById('hint').textContent = texts.hint;
    document.getElementById('keys').textContent = texts.keys;
}

document.getElementById('shutter').addEventListener('click', () => {
    fetch('https://city_phone_camera/start', { method: 'POST', body: '{}' }).catch(() => null);
});

window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.type === 'city_phone:context') {
        applyContext(message);
        setLanguage(message.language);
    }
});

setLanguage('en');
