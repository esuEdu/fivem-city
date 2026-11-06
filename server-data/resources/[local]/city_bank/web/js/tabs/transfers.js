import { call, h, label, money, dateTime, section, button, pill, field, input, select, whole, report, empty } from '../util.js';

export default async function render(container, ctx) {
    const [accounts, scheduled] = await Promise.all([call('accounts'), call('scheduled')]);

    if (!report(accounts) || !report(scheduled)) return;

    const sendable = accounts.accounts.filter((a) => a.perms.transfer);
    const options = sendable.map((a) => ({ value: a.id, label: `${a.label} · ${money(a.balance)}` }));

    if (options.length === 0) {
        container.replaceChildren(empty('no_transfer_account'));
        return;
    }

    const from = select(options, options[0].value);
    const key = input({ placeholder: label('pix_key_hint'), maxLength: 20 });
    const amount = input({ type: 'number', min: 1, placeholder: '0' });
    const note = input({ placeholder: label('note'), maxLength: 60 });
    const receiver = h('p', { className: 'receiver muted', text: label('receiver_unknown') });

    const lookup = async () => {
        const reply = await call('lookup', key.value.trim());
        receiver.textContent = reply.ok ? label('receiver', reply.name, reply.number) : label('receiver_unknown');
        receiver.classList.toggle('muted', !reply.ok);
    };

    key.addEventListener('change', lookup);

    const send = section(label('send_money'),
        h('div', { className: 'form-grid' },
            field(label('from'), from), field(label('pix_key'), key), field(label('amount'), amount), field(label('note'), note)),
        receiver,
        h('div', { className: 'row__actions' },
            button(label('check_receiver'), lookup),
            button(label('send'), async () => {
                const reply = await call('send', Number(from.value), key.value.trim(), whole(amount), note.value.trim());
                if (report(reply, 'sent')) ctx.refresh();
            }, 'primary')));

    // Scheduled transfers
    const sFrom = select(options, options[0].value);
    const sKey = input({ placeholder: label('pix_key_hint'), maxLength: 20 });
    const sAmount = input({ type: 'number', min: 1, placeholder: '0' });
    const sFrequency = select(['daily', 'weekly', 'biweekly'].map((f) => ({ value: f, label: label(`freq_${f}`) })), 'weekly');
    const sNote = input({ placeholder: label('note'), maxLength: 60 });

    const list = scheduled.scheduled.length ? h('ul', { className: 'list' }, scheduled.scheduled.map((s) => h('li', { className: 'row' },
        h('div', { className: 'row__main' },
            h('span', { className: 'row__title', text: `${money(s.amount)} · ${label(`freq_${s.frequency}`)}` }),
            h('span', { className: 'row__sub', text: label('scheduled_next', s.to_number || '-', dateTime(s.next_run)) }),
            s.reference ? h('span', { className: 'row__sub', text: s.reference }) : null),
        h('div', { className: 'row__actions' },
            pill(label(`sched_${s.status}`), s.status === 'active' ? 'success' : 'warning'),
            button(label(s.status === 'active' ? 'pause' : 'resume'), async () => {
                if (report(await call('scheduleState', s.id, s.status === 'active' ? 'pause' : 'resume'), 'done')) ctx.refresh();
            }),
            button(label('delete'), async () => { if (report(await call('scheduleState', s.id, 'delete'), 'done')) ctx.refresh(); }, 'danger')),
    ))) : empty('no_scheduled');

    const schedule = section(label('scheduled'),
        list,
        h('div', { className: 'form-grid' },
            field(label('from'), sFrom), field(label('pix_key'), sKey), field(label('amount'), sAmount),
            field(label('frequency'), sFrequency), field(label('note'), sNote)),
        h('div', { className: 'row__actions' },
            button(label('schedule'), async () => {
                const reply = await call('schedule', Number(sFrom.value), sKey.value.trim(), whole(sAmount), sFrequency.value, sNote.value.trim());
                if (report(reply, 'scheduled_saved')) ctx.refresh();
            }, 'primary')));

    container.replaceChildren(h('div', { className: 'grid grid--two' }, send, schedule));
}
