import { el, L, run, heading, empty } from './ui.js';
import { app, can, go } from './main.js';

export async function renderCerts() {
    app.editing = false;

    const response = await run('members');
    const members = response ? response.data : [];
    const canGrant = can('grantCert');

    const head = el('div', { class: 'table-head cert-cols', style: `--certs: ${app.certs.length}` },
        el('span', { text: L('ui_officer') }), ...app.certs.map((cert) => el('span', { class: 'center', text: cert.label })));

    const rows = members.map((member) => el('div', { class: 'table-row cert-cols', style: `--certs: ${app.certs.length}` },
        el('span', { class: 'person' }, el('span', { class: 'callsign', text: member.callsign || '—' }), el('strong', { text: member.name })),
        ...app.certs.map((cert) => {
            const on = member.certs.includes(cert.id);
            const self = member.citizenid === app.me.citizenid;

            return el('span', { class: 'center' }, el('button', {
                class: `cert-toggle${on ? ' on' : ''}`, disabled: !canGrant || self, 'aria-label': cert.label,
                onclick: async () => { if (await run('setCert', { citizenid: member.citizenid, cert: cert.id, on: !on }, L('ui_saved'))) go('certs'); },
            }, on ? '✓' : ''));
        }),
    ));

    return el('div', { class: 'stack' },
        heading(L('ui_tab_certs')),
        el('p', { class: 'muted', text: canGrant ? L('ui_certs_hint_grant') : L('ui_certs_hint') }),
        el('div', { class: 'card flush table-scroll' }, head, rows.length ? rows : empty(L('ui_no_members'))),
    );
}
