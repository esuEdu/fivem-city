import { call, h, label, select, button, panel, report } from '../util.js';
import { activityTable } from './dashboard.js';

const PAGE = 25;
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

    container.append(panel(label('page', view.page + 1), activityTable(reply.entries), [
        account,
        direction,
        button('‹', () => { view.page -= 1; ctx.refresh(); }, 'ghost', view.page === 0),
        button('›', () => { view.page += 1; ctx.refresh(); }, 'ghost', reply.entries.length < PAGE),
    ], 'visual--fill'));
}
