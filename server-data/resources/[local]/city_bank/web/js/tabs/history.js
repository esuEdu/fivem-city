import { call, h, label, select, button, section, report } from '../util.js';
import { activityList } from './dashboard.js';

const view = { account: null, page: 0, direction: '' };

export default async function render(container, ctx) {
    const accounts = await call('accounts');

    if (!report(accounts)) return;

    const list = accounts.accounts;

    if (!view.account || !list.some((a) => a.id === view.account)) view.account = list[0]?.id ?? null;

    const reply = await call('history', view.account, view.page, view.direction || null);

    if (!report(reply)) return;

    const account = select(list.map((a) => ({ value: String(a.id), label: `${a.label} · ${a.number}` })), String(view.account));
    const direction = select([
        { value: '', label: label('filter_all') },
        { value: 'in', label: label('filter_in') },
        { value: 'out', label: label('filter_out') },
    ], view.direction);

    account.addEventListener('change', () => { view.account = Number(account.value); view.page = 0; ctx.refresh(); });
    direction.addEventListener('change', () => { view.direction = direction.value; view.page = 0; ctx.refresh(); });

    container.replaceChildren(
        h('div', { className: 'toolbar' }, account, direction),
        section(label('page', view.page + 1), activityList(reply.entries)),
        h('div', { className: 'row__actions' },
            button(label('previous'), () => { view.page -= 1; ctx.refresh(); }, 'ghost', view.page === 0),
            button(label('next'), () => { view.page += 1; ctx.refresh(); }, 'ghost', reply.entries.length < 25)),
    );
}
