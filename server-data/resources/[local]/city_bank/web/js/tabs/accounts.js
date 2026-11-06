import { call, h, label, money, date, section, button, pill, field, input, select, whole, modal, report, toast } from '../util.js';

const PERMS = ['deposit', 'withdraw', 'transfer', 'cards', 'members'];

function goalBar(account) {
    if (!account.goal) return null;

    const pct = Math.min(100, Math.floor((account.balance / account.goal) * 100));

    return h('div', { className: 'goal' },
        h('div', { className: 'goal__bar' }, h('div', { className: 'goal__fill', style: `width: ${pct}%` })),
        h('span', { className: 'row__sub', text: label('goal_progress', money(account.balance), money(account.goal), pct) }),
        account.goalDate ? h('span', { className: 'row__sub', text: label('goal_until', date(account.goalDate)) }) : null);
}

async function moveDialog(list, from, ctx) {
    const targets = list.filter((a) => a.perms.deposit && a.id !== from.id);
    if (targets.length === 0) return toast(label('error_no_target'), 'error');

    const to = select(targets.map((a) => ({ value: a.id, label: `${a.label} · ${a.number}` })), targets[0].id);
    const amount = input({ type: 'number', min: 1, placeholder: '0' });

    await modal(label('move_title', from.label), [field(label('move_to'), to), field(label('amount'), amount)], [{
        text: label('move'),
        onClick: async (close) => {
            if (report(await call('move', from.id, Number(to.value), whole(amount)), 'done')) { close(); ctx.refresh(); }
        },
    }]);
}

async function goalDialog(account, ctx) {
    const amount = input({ type: 'number', min: 0, value: account.goal || '' });
    const until = input({ type: 'date' });

    await modal(label('goal_title'), [field(label('goal_amount'), amount), field(label('goal_date'), until)], [{
        text: label('save'),
        onClick: async (close) => {
            const time = until.value ? Math.floor(new Date(until.value).getTime() / 1000) : 0;
            if (report(await call('setGoal', account.id, whole(amount) || 0, time), 'done')) { close(); ctx.refresh(); }
        },
    }]);
}

async function renameDialog(account, ctx) {
    const name = input({ value: account.label, maxLength: 32 });

    await modal(label('rename'), [field(label('account_name'), name)], [{
        text: label('save'),
        onClick: async (close) => {
            if (report(await call('rename', account.id, name.value.trim()), 'done')) { close(); ctx.refresh(); }
        },
    }]);
}

function memberRow(account, member, refreshMembers) {
    const perms = new Set(String(member.perms).split(','));
    const checks = PERMS.map((perm) => {
        const box = h('input', { type: 'checkbox', checked: perms.has(perm), disabled: account.type === 'job' });
        return { perm, box, node: h('label', { className: 'check' }, box, label(`perm_${perm}`)) };
    });
    const limit = input({ type: 'number', min: 0, value: member.daily_limit });

    if (member.status === 'pending') {
        return h('div', { className: 'row' },
            h('div', { className: 'row__main' }, h('span', { className: 'row__title', text: member.name }), pill(label('pending'), 'warning')),
            h('div', { className: 'row__actions' },
                button(label('approve'), async () => { if (report(await call('decideMember', account.id, member.citizenid, true), 'done')) refreshMembers(); }, 'primary'),
                button(label('deny'), async () => { if (report(await call('decideMember', account.id, member.citizenid, false), 'done')) refreshMembers(); })));
    }

    return h('div', { className: 'member' },
        h('span', { className: 'row__title', text: member.name }),
        account.type === 'job' ? h('span', { className: 'row__sub', text: label('viewer') }) : h('div', { className: 'checks' }, checks.map((c) => c.node)),
        account.type === 'job' ? null : field(label('member_limit'), limit),
        h('div', { className: 'row__actions' },
            account.type === 'job' ? null : button(label('save'), async () => {
                const chosen = Object.fromEntries(checks.map((c) => [c.perm, c.box.checked]));
                report(await call('setMember', account.id, member.citizenid, chosen, whole(limit) ?? 0), 'done');
            }, 'primary'),
            button(label('remove'), async () => { if (report(await call('removeMember', account.id, member.citizenid), 'done')) refreshMembers(); }, 'danger')));
}

async function membersDialog(account) {
    const body = h('div', { className: 'stack' });

    const load = async () => {
        const reply = await call('members', account.id);
        if (!report(reply)) return;

        body.replaceChildren(h('div', { className: 'stack' },
            reply.members.length ? reply.members.map((m) => memberRow(account, m, load)) : h('p', { className: 'muted', text: label('no_members') }),
            account.type === 'job' ? h('div', { className: 'inline' },
                ...(() => {
                    const id = input({ type: 'number', placeholder: label('server_id') });
                    return [id, button(label('add_viewer'), async () => { if (report(await call('addViewer', account.id, whole(id)), 'done')) load(); }, 'primary')];
                })()) : null));
    };

    await load();
    await modal(label('members_title', account.label), body);
}

function accountCard(account, list, ctx) {
    const actions = [];

    if (account.perms.withdraw) actions.push(button(label('move'), () => moveDialog(list, account, ctx)));
    if (account.perms.members && account.type !== 'personal') actions.push(button(label('goal'), () => goalDialog(account, ctx)));
    if (account.perms.members && account.type !== 'personal') actions.push(button(label('rename'), () => renameDialog(account, ctx)));
    if (account.perms.members && (account.type === 'shared' || account.type === 'job')) actions.push(button(label('members'), () => membersDialog(account)));
    if (account.role === 'member') {
        actions.push(button(label('leave'), async () => { if (report(await call('leaveShared'), 'done')) ctx.refresh(); }, 'danger'));
    }

    return h('article', { className: 'account-card' },
        h('div', { className: 'account-card__head' },
            h('div', {},
                h('p', { className: 'eyebrow', text: label(`type_${account.type}`) }),
                h('p', { className: 'account-card__name', text: account.label })),
            h('div', { className: 'pills' },
                pill(label(`role_${account.role}`)),
                account.frozen ? pill(label('status_frozen'), 'danger') : null)),
        h('p', { className: 'account-card__balance mono', text: money(account.balance) }),
        h('p', { className: 'row__sub mono', text: account.number }),
        goalBar(account),
        h('div', { className: 'row__actions' }, actions));
}

export default async function render(container, ctx) {
    const data = await call('accounts');

    if (!report(data)) return;

    const top = [];

    if (!data.hasSavings) top.push(button(label('open_savings'), async () => { if (report(await call('createSavings'), 'done')) ctx.refresh(); }, 'primary'));

    if (data.canShare && !data.pendingJoin) {
        const name = input({ placeholder: label('shared_name'), maxLength: 32 });
        const number = input({ placeholder: 'LS 0000 0000', maxLength: 14 });

        top.push(h('div', { className: 'inline' }, name,
            button(label('create_shared'), async () => { if (report(await call('createShared', name.value.trim()), 'done')) ctx.refresh(); }, 'primary')));
        top.push(h('div', { className: 'inline' }, number,
            button(label('join_shared'), async () => { if (report(await call('requestJoin', number.value.trim()), 'join_sent')) ctx.refresh(); })));
    }

    if (data.pendingJoin) top.push(h('p', { className: 'notice', text: label('join_pending', data.pendingJoin) }));

    container.replaceChildren(h('div', { className: 'stack' },
        top.length ? section(label('new_account'), h('div', { className: 'toolbar' }, top)) : null,
        h('div', { className: 'accounts-grid' }, data.accounts.map((account) => accountCard(account, data.accounts, ctx))),
    ));
}
