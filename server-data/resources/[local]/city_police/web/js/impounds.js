import { el, L, run, icon, formatTime, money, empty, labeled, confirmButton } from './ui.js';
import { app, can, go } from './main.js';

export async function renderImpounds() {
    app.editing = false;

    const response = await run('impounds');
    const data = response ? response.data : { vehicles: [], locker: [] };
    const now = Date.now() / 1000;

    const reason = el('input', { class: 'field', type: 'text', maxlength: 160 });
    const fee = el('input', { class: 'field', type: 'number', min: 0, max: app.impound.maxFee, value: app.impound.fee });
    const hours = el('input', { class: 'field', type: 'number', min: 0, max: app.impound.maxHours, value: 0 });

    const impoundCard = el('div', { class: 'card form' },
        el('strong', { text: L('ui_impound_here') }),
        el('small', { class: 'muted', text: L('ui_impound_hint') }),
        el('div', { class: 'form-grid' }, labeled(L('ui_reason'), reason), labeled(L('ui_fee'), fee), labeled(L('ui_hold_hours'), hours)),
        el('div', { class: 'button-row' }, el('span', { class: 'spacer' }),
            el('button', { class: 'kit-btn accent', onclick: async () => {
                const result = await run('impound', { reason: reason.value, fee: Number(fee.value), hours: Number(hours.value) }, L('ui_done'));
                if (result) go('impounds');
            } }, L('ui_impound'))),
    );

    const vehicles = el('div', { class: 'card flush' },
        el('div', { class: 'table-head impound-cols' },
            el('span', { text: L('ui_plate') }), el('span', { text: L('ui_reason') }), el('span', { text: L('ui_fee') }), el('span', { text: L('ui_held_until') }), el('span', {})),
        data.vehicles.length ? data.vehicles.map((row) => el('div', { class: 'table-row impound-cols' },
            el('button', { class: 'link plate', text: row.plate, onclick: () => go('vehicles', { plate: row.plate }) }),
            el('span', { class: 'who' }, el('strong', { text: row.reason }), el('small', { text: `${row.model || ''} · ${row.officer} · ${formatTime(row.created)}` })),
            el('span', { text: money(row.fee) }),
            el('span', { class: row.hold_until > now ? 'gold' : 'good', text: row.hold_until > now ? formatTime(row.hold_until) : L('ui_free_to_go') }),
            can('release') ? confirmButton(L('ui_release'), async () => { if (await run('release', { id: row.id }, L('ui_done'))) go('impounds'); }, 'kit-btn') : el('span', {}),
        )) : empty(L('ui_no_impounds')),
    );

    const locker = el('div', { class: 'card flush' },
        el('div', { class: 'card-head padded' }, icon('lock', 18), el('strong', { text: L('ui_evidence_locker') }), el('span', { class: 'pill', text: String(data.locker.length) })),
        data.locker.length ? data.locker.map((item) => el('div', { class: 'info-row' },
            el('strong', { text: item.label }), el('span', { class: 'muted grow', text: item.description || '' }), el('span', { class: 'value', text: `x${item.count}` }))) : empty(L('ui_locker_empty')),
    );

    return el('div', { class: 'stack' },
        el('div', { class: 'heading' }, el('h1', { text: L('ui_tab_impounds') }), el('span', { class: 'pill', text: String(data.vehicles.length) })),
        impoundCard,
        vehicles,
        locker,
    );
}
