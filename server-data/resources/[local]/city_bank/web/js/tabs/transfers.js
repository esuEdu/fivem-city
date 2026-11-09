import { call, h, label, money, dateTime, panel, kpi, table, chip, button, iconButton, field, input, select, whole, modal, report, empty, actions, state } from '../util.js';

function receiverBox() {
    return h('div', { className: 'receiver', text: label('receiver_unknown') });
}

async function lookup(key, box) {
    const reply = await call('lookup', key.trim());
    box.textContent = reply.ok ? label('receiver', reply.name, reply.number) : label('receiver_unknown');
    box.classList.toggle('is-found', Boolean(reply.ok));
}

async function scheduleDialog(options, ctx) {
    const from = select(options, options[0].value);
    const key = input({ placeholder: label('pix_key_hint'), maxLength: 20 });
    const amount = input({ type: 'number', min: 1, placeholder: '0' });
    const frequency = select(['daily', 'weekly', 'biweekly'].map((f) => ({ value: f, label: label(`freq_${f}`) })), 'weekly');
    const note = input({ placeholder: label('note'), maxLength: 60 });
    const box = receiverBox();

    key.addEventListener('change', () => lookup(key.value, box));

    await modal(label('new_schedule'), h('div', { className: 'form' },
        h('div', { className: 'form__grid' },
            field(label('from'), from), field(label('pix_key'), key), field(label('amount'), amount), field(label('frequency'), frequency)),
        field(label('note'), note), box), [{
        text: label('schedule'),
        onClick: async (close) => {
            const reply = await call('schedule', Number(from.value), key.value.trim(), whole(amount), frequency.value, note.value.trim());
            if (report(reply, 'scheduled_saved')) { close(); ctx.refresh(); }
        },
    }]);
}

export default async function render(container, ctx) {
    const [accounts, scheduled] = await Promise.all([call('accounts'), call('scheduled')]);

    if (!report(accounts) || !report(scheduled)) return;

    const sendable = accounts.accounts.filter((a) => a.perms.transfer);

    if (sendable.length === 0) {
        container.append(empty('no_transfer_account'));
        return;
    }

    const options = sendable.map((a) => ({ value: a.id, label: `${a.label} · ${money(a.balance)}` }));
    const from = select(options, options[0].value);
    const key = input({ placeholder: label('pix_key_hint'), maxLength: 20 });
    const amount = input({ type: 'number', min: 1, placeholder: '0' });
    const note = input({ placeholder: label('note'), maxLength: 60 });
    const box = receiverBox();

    key.addEventListener('change', () => lookup(key.value, box));

    const scheduling = state.features.scheduled !== false;
    const active = scheduled.scheduled.filter((s) => s.status === 'active');
    const weekly = active.reduce((sum, s) => sum + s.amount * (s.frequency === 'daily' ? 7 : s.frequency === 'weekly' ? 1 : 0.5), 0);

    container.append(
        h('div', { className: 'kpis' },
            kpi(label('limit_per_tx'), money(scheduled.limits.perTx), label('limit_per_day_is', money(scheduled.limits.perDay)), 'accent'),
            kpi(label('night_limit'), money(scheduled.limits.night), label('night_hours', scheduled.limits.nightFrom, scheduled.limits.nightTo)),
            scheduling ? kpi(label('scheduled_active'), String(active.length), label('per_week_is', money(Math.round(weekly)))) : null),

        h('div', { className: 'grid grid--two' },
            panel(label('send_money'), h('div', { className: 'form' },
                h('div', { className: 'form__grid' }, field(label('from'), from), field(label('pix_key'), key), field(label('amount'), amount), field(label('note'), note)),
                box,
                h('div', { className: 'form__actions' },
                    button(label('check_receiver'), () => lookup(key.value, box), 'ghost', false, 'search'),
                    button(label('send'), async () => {
                        const reply = await call('send', Number(from.value), key.value.trim(), whole(amount), note.value.trim());
                        if (report(reply, 'sent')) ctx.refresh();
                    }, 'primary', false, 'send')))),

            scheduling ? panel(label('scheduled'), table([
                { title: label('col_amount'), render: (s) => h('span', { className: 'num strong', text: money(s.amount) }) },
                { title: label('frequency'), render: (s) => label(`freq_${s.frequency}`) },
                { title: label('col_to'), render: (s) => h('span', { className: 'num muted', text: s.to_number || '-' }) },
                { title: label('col_next'), render: (s) => dateTime(s.next_run), className: 'muted nowrap' },
                { title: label('col_status'), render: (s) => chip(label(`sched_${s.status}`), s.status === 'active' ? 'good' : 'warn') },
                {
                    title: '', align: 'right',
                    render: (s) => actions(
                        iconButton(s.status === 'active' ? 'pause' : 'play', label(s.status === 'active' ? 'pause' : 'resume'), async () => {
                            if (report(await call('scheduleState', s.id, s.status === 'active' ? 'pause' : 'resume'), 'done')) ctx.refresh();
                        }),
                        iconButton('trash', label('delete'), async () => { if (report(await call('scheduleState', s.id, 'delete'), 'done')) ctx.refresh(); }, 'bad')),
                },
            ], scheduled.scheduled, 'no_scheduled'), button(label('new_schedule'), () => scheduleDialog(options, ctx), 'primary', false, 'plus')) : null),
    );
}
