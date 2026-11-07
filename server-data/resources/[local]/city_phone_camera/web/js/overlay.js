// Camera mode overlay: the filter and zoom, the keys, a flash when a photo is taken and short messages
const TEXTS = {
    en: {
        back: 'Back camera', selfie: 'Selfie', zoom: 'Zoom %s%', shoot: 'Photo', switch: 'Selfie', filter: 'Filter',
        zoomKey: 'Zoom', hud: 'HUD', exit: 'Exit', saved: 'Saved to Photos (%s left)', full: 'Photos are full: delete some in Photos',
        busy: 'Wait a moment', failed: "Couldn't take the photo", no_phone: 'You need a phone',
        original: 'Original', bw: 'Black & White', vintage: 'Vintage', warm: 'Warm', cold: 'Cold', noir: 'Noir',
    },
    'pt-br': {
        back: 'Câmera traseira', selfie: 'Selfie', zoom: 'Zoom %s%', shoot: 'Foto', switch: 'Selfie', filter: 'Filtro',
        zoomKey: 'Zoom', hud: 'HUD', exit: 'Sair', saved: 'Salva em Fotos (restam %s)', full: 'Fotos cheias: apague algumas em Fotos',
        busy: 'Espere um pouco', failed: 'Não foi possível tirar a foto', no_phone: 'Você precisa de um celular',
        original: 'Original', bw: 'Preto e Branco', vintage: 'Vintage', warm: 'Quente', cold: 'Frio', noir: 'Noir',
    },
};

let language = 'en';
let messageTimer = null;

const $ = (id) => document.getElementById(id);

function t(key, value) {
    const text = (TEXTS[language] || TEXTS.en)[key] ?? TEXTS.en[key] ?? key;
    return text.replace('%s', value ?? '');
}

function key(label, text) {
    const node = document.createElement('span');
    node.className = 'key';
    const kbd = document.createElement('kbd');
    kbd.textContent = label;
    node.append(kbd, document.createTextNode(text));
    return node;
}

function render(state) {
    $('camera').classList.toggle('camera--on', state.visible === true);
    if (!state.visible) return;

    $('filter').textContent = t(state.filter);
    $('mode').textContent = t(state.selfie ? 'selfie' : 'back');
    $('zoom').textContent = t('zoom', state.zoom);
    $('zoom').style.display = state.selfie ? 'none' : '';

    $('keys').replaceChildren(...[
        key('LMB', t('shoot')),
        key('E', t('switch')),
        key('← →', t('filter')),
        state.selfie ? null : key('Scroll', t('zoomKey')),
        key('H', t('hud')),
        key('⌫', t('exit')),
    ].filter(Boolean));
}

function message(text) {
    const node = $('message');
    node.textContent = text;
    node.classList.add('message--on');
    clearTimeout(messageTimer);
    messageTimer = setTimeout(() => node.classList.remove('message--on'), 2200);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.language) language = data.language === 'pt-br' ? 'pt-br' : 'en';

    if (data.action === 'state') render(data);

    if (data.action === 'flash') {
        const flash = $('flash');
        flash.classList.remove('flash--on');
        void flash.offsetWidth;
        flash.classList.add('flash--on');
    }

    if (data.action === 'saved') message(t('saved', data.left));
    if (data.action === 'error') message(t(data.reason || 'failed'));
});
