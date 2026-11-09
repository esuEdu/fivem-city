import { call, h, label, money, panel, kpi, table, chip, button, iconButton, field, input, select, whole, modal, report, toast, progress, actions, state } from '../util.js';

const PERMS = ['deposit', 'withdraw', 'transfer', 'cards', 'members'];

async function moveDialog(list, from, ctx) {
    const targets = list.filter((a) => a.perms.deposit && a.id !== from.id);
    if (targets.length === 0) return toast(label('error_no_target'), 'error');

    const to = select(targets.map((a) => ({ value: a.id, label: `${a.label} · ${a.number}` })), targets[0].id);
    const amount = input({ type: 'number', min: 1, placeholder: '0' });

    await modal(label('move_title', from.label), h('div', { className: 'form' },
        h('p', { className: 'muted', text: label('available', money(from.balance)) }),
        field(label('move_to'), to), field(label('amount'), amount)), [{
        text: label('move'),
        onClick: async (close) => {
            if (report(await call('move', from.id, Number(to.value), whole(amount)), 'done')) { close(); ctx.refresh(); }
        },
    }]);
}

async function goalDialog(account, ctx) {
    const amount = input({ type: 'number', min: 0, value: account.goal || '' });
    const until = input({ type: 'date' });

    await modal(label('goal_title'), h('div', { className: 'form' }, field(label('goal_amount'), amount), field(label('goal_date'), until)), [{
        text: label('save'),
        onClick: async (close) => {
            const time = until.value ? Math.floor(new Date(until.value).getTime() / 1000) : 0;
            if (report(await call('setGoal', account.id, whole(amount) || 0, time), 'done')) { close(); ctx.refresh(); }
        },
    }]);
}

async function renameDialog(account, ctx) {
    const name = input({ value: account.label, maxLength: 32 });

    await modal(label('rename'), h('div', { className: 'form' }, field(label('account_name'), name)), [{
        text: label('save'),
        onClick: async (close) => {
            if (report(await call('rename', account.id, name.value.trim()), 'done')) { close(); ctx.refresh(); }
        },
    }]);
}

async function memberDialog(account, member, reload) {
    const perms = new Set(String(member.perms).split(','));
    const boxes = PERMS.map((perm) => ({ perm, box: h('input', { type: 'checkbox', checked: perms.has(perm) }) }));
    const limit = input({ type: 'number', min: 0, value: member.daily_limit });

    await modal(member.name, h('div', { className: 'form' },
        h('div', { className: 'checks' }, boxes.map(({ perm, box }) => h('label', { className: 'check' }, box, label(`perm_${perm}`)))),
        field(label('member_limit'), limit)), [{
        text: label('save'),
        onClick: async (close) => {
            const chosen = Object.fromEntries(boxes.map(({ perm, box }) => [perm, box.checked]));
            if (report(await call('setMember', account.id, member.citizenid, chosen, whole(limit) ?? 0), 'done')) { close(); reload(); }
        },
    }]);
}

async function membersDialog(account) {
    const body = h('div', { className: 'stack' });

    const load = async () => {
        const reply = await call('members', account.id);
        if (!report(reply)) return;

        const rows = table([
            { title: label('col_name'), render: (m) => m.name, className: 'grow' },
            { title: label('col_permissions'), render: (m) => (m.status === 'pending' ? chip(label('pending'), 'warn') : String(m.perms).split(',').map((p) => label(`perm_${p}`)).join(', ')), className: 'muted' },
            { title: label('col_limit'), render: (m) => (account.type === 'job' ? '-' : money(m.daily_limit)), align: 'right' },
            {
                title: '', align: 'right',
                render: (m) => (m.status === 'pending'
                    ? actions(
                        iconButton('check', label('approve'), async () => { if (report(await call('decideMember', account.id, m.citizenid, true), 'done')) load(); }, 'good'),
                        iconButton('close', label('deny'), async () => { if (report(await call('decideMember', account.id, m.citizenid, false), 'done')) load(); }, 'bad'))
                    : actions(
                        account.type === 'job' ? null : iconButton('sliders', label('edit'), () => memberDialog(account, m, load)),
                        iconButton('trash', label('remove'), async () => { if (report(await call('removeMember', account.id, m.citizenid), 'done')) load(); }, 'bad'))),
            },
        ], reply.members, 'no_members');

        const viewerId = input({ type: 'number', placeholder: label('server_id') });

        body.replaceChildren(rows, account.type === 'job' ? h('div', { className: 'inline' }, viewerId,
            button(label('add_viewer'), async () => { if (report(await call('addViewer', account.id, whole(viewerId)), 'done')) load(); }, 'primary', false, 'plus')) : null);
    };

    await load();
    await modal(label('members_title', account.label), body);
}

async function newSharedDialog(ctx) {
    const name = input({ placeholder: label('shared_name'), maxLength: 32 });

    await modal(label('create_shared'), h('div', { className: 'form' }, field(label('account_name'), name)), [{
        text: label('create'),
        onClick: async (close) => { if (report(await call('createShared', name.value.trim()), 'done')) { close(); ctx.refresh(); } },
    }]);
}

async function joinDialog(ctx) {
    const number = input({ placeholder: 'LS 0000 0000', maxLength: 14 });

    await modal(label('join_shared'), h('div', { className: 'form' }, h('p', { className: 'muted', text: label('join_hint') }), field(label('account_number'), number)), [{
        text: label('send'),
        onClick: async (close) => { if (report(await call('requestJoin', number.value.trim()), 'join_sent')) { close(); ctx.refresh(); } },
    }]);
}

function rowActions(account, list, ctx) {
    const manage = account.perms.members && account.type !== 'personal';

    return actions(
        account.perms.withdraw ? iconButton('move', label('move'), () => moveDialog(list, account, ctx)) : null,
        manage && account.type !== 'job' ? iconButton('goal', label('goal'), () => goalDialog(account, ctx)) : null,
        manage ? iconButton('edit', label('rename'), () => renameDialog(account, ctx)) : null,
        manage && (account.type === 'shared' || account.type === 'job') ? iconButton('users', label('members'), () => membersDialog(account)) : null,
        account.role === 'member' ? iconButton('exit', label('leave'), async () => { if (report(await call('leaveShared'), 'done')) ctx.refresh(); }, 'bad') : null,
    );
}

export default async function render(container, ctx) {
    const data = await call('accounts');

    if (!report(data)) return;

    const total = data.accounts.reduce((sum, a) => sum + (a.role === 'owner' ? a.balance : 0), 0);
    const tools = [
        !data.hasSavings && state.features.savings !== false ? button(label('open_savings'), async () => { if (report(await call('createSavings'), 'done')) ctx.refresh(); }, 'primary', false, 'plus') : null,
        data.canShare && !data.pendingJoin ? button(label('create_shared'), () => newSharedDialog(ctx), 'ghost', false, 'plus') : null,
        data.canShare && !data.pendingJoin ? button(label('join_shared'), () => joinDialog(ctx), 'ghost', false, 'users') : null,
    ];

    container.append(
        h('div', { className: 'kpis' },
            kpi(label('total_owned'), money(total), label('accounts_count', data.accounts.length), 'accent'),
            ...data.accounts.slice(0, 3).map((a) => kpi(a.label, money(a.balance), label(`type_${a.type}`)))),

        data.pendingJoin ? h('p', { className: 'notice', text: label('join_pending', data.pendingJoin) }) : null,

        panel(label('nav_accounts'), table([
            { title: label('col_type'), render: (a) => chip(label(`type_${a.type}`)) },
            { title: label('col_name'), render: (a) => a.label, className: 'strong grow' },
            { title: label('account_number'), render: (a) => h('span', { className: 'num muted', text: a.number || '-' }) },
            { title: label('col_role'), render: (a) => label(`role_${a.role}`), className: 'muted' },
            { title: label('col_goal'), render: (a) => (a.goal ? progress(a.balance / a.goal, label('goal_short', Math.min(100, Math.floor((a.balance / a.goal) * 100)), money(a.goal))) : '-') },
            { title: label('col_status'), render: (a) => (a.frozen ? chip(label('status_frozen'), 'bad') : chip(label('status_active'), 'good')) },
            { title: label('col_balance'), render: (a) => h('span', { className: 'num strong', text: money(a.balance) }), align: 'right' },
            { title: '', render: (a) => rowActions(a, data.accounts, ctx), align: 'right' },
        ], data.accounts), tools),
    );
}
