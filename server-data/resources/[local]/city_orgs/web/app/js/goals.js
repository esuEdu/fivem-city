// Goals: the daily and weekly farm goals the leader sets, and the contribution ranking with what each member put
// in and took out shown side by side, so cycling items in and out is visible to everyone.
import { app, state } from './main.js';

const { el, L, run, heading, pill, icon, segmented, confirmButton } = window.WorkApp;

let period = 'weekly';
let editing = false;
let editMode = 'each';

function itemLabel(name) {
    const item = state.farmItems.find((entry) => entry.name === name);
    return item ? item.label : name;
}

function periodLabel() {
    return L(period === 'daily' ? 'ui_goal_daily_short' : 'ui_goal_weekly_short');
}

function goalSummary(goal) {
    if (!goal) return el('small', { class: 'muted', text: L('ui_no_goal') });
    if (goal.mode === 'total') return el('strong', { text: L('ui_goal_total', goal.amount) });

    return el('div', { class: 'goal-items' },
        Object.keys(goal.items).sort().map((name) => el('span', { class: 'chip', text: `${itemLabel(name)} x${goal.items[name]}` })));
}

function goalForm(goal) {
    const inputs = {};
    const fields = el('div', { class: 'goal-form' });
    const totalInput = el('input', { class: 'field', type: 'number', min: '1', placeholder: L('ui_amount_placeholder'), value: goal && goal.mode === 'total' ? String(goal.amount) : '' });

    const drawFields = () => {
        const rows = [];

        if (editMode === 'each') {
            for (const item of state.farmItems) {
                inputs[item.name] = inputs[item.name] || el('input', {
                    class: 'field', type: 'number', min: '0', placeholder: '0',
                    value: goal && goal.mode === 'each' && goal.items[item.name] ? String(goal.items[item.name]) : '',
                });
                rows.push(el('div', { class: 'item-field' }, el('span', { text: item.label }), inputs[item.name]));
            }
        } else {
            rows.push(el('div', { class: 'item-field' }, el('span', { text: L('ui_goal_mode_total') }), totalInput));
        }

        fields.replaceChildren(
            segmented([['each', L('ui_goal_mode_each')], ['total', L('ui_goal_mode_total')]], editMode, (value) => {
                editMode = value;
                drawFields();
            }),
            ...rows,
            el('div', { class: 'form-row' },
                el('button', {
                    class: 'kit-btn tint',
                    onclick: async () => {
                        const args = { period, mode: editMode };

                        if (editMode === 'total') {
                            args.amount = Number(totalInput.value);
                        } else {
                            args.items = {};
                            for (const item of state.farmItems) args.items[item.name] = Number(inputs[item.name].value) || 0;
                        }

                        if (await run('setGoal', args, L('ui_goal_saved'))) {
                            editing = false;
                            app.go('goals');
                        }
                    },
                }, L('ui_save')),
                el('button', { class: 'kit-btn', onclick: () => { editing = false; app.go('goals'); } }, L('ui_cancel'))),
        );
    };

    drawFields();

    return fields;
}

function goalCard(goal) {
    const actions = state.boss && !editing
        ? el('div', { class: 'row-actions' },
            el('button', { class: 'kit-btn tint small', onclick: () => { editing = true; editMode = goal ? goal.mode : 'each'; app.go('goals'); } },
                goal ? L('ui_edit_goal') : L('ui_set_goal')),
            goal ? confirmButton(L('ui_clear_goal'), async () => {
                if (await run('clearGoal', { period }, L('ui_goal_cleared'))) app.go('goals');
            }, 'kit-btn soft-danger small') : null)
        : null;

    return el('div', { class: 'card' },
        el('div', { class: 'card-head' },
            el('span', { class: 'tile-icon tint' }, icon('target', 18, 2)),
            el('div', { class: 'who' },
                el('strong', { text: L(period === 'daily' ? 'ui_goal_daily' : 'ui_goal_weekly') }),
                el('small', { class: 'muted', text: L('ui_goal_per_member', periodLabel()) })),
            el('span', { class: 'spacer' }), actions),
        editing ? goalForm(goal) : goalSummary(goal),
    );
}

function rankingRows(rows, hasGoal) {
    return rows.map((row, index) => el('div', { class: `table-row rank-cols${row.citizenid === state.citizenid ? ' me' : ''}` },
        el('span', { class: 'rank-pos', text: `#${index + 1}` }),
        el('div', { class: 'who' }, el('strong', { text: row.name }), row.citizenid === state.citizenid ? el('small', { text: L('ui_you') }) : null),
        el('span', { class: 'gain', text: `+${row.deposited}` }),
        el('span', { class: 'loss', text: `-${row.withdrawn}` }),
        el('strong', { class: 'value', text: String(row.net) }),
        hasGoal
            ? el('div', { class: 'progress-cell' },
                el('div', { class: 'progress-track', style: 'flex: 1' }, el('i', { style: `width: ${Math.round((row.percent || 0) * 100)}%` })),
                el('small', { text: `${Math.round((row.percent || 0) * 100)}%` }))
            : el('span'),
        hasGoal ? (row.complete ? pill(L('ui_done'), 'green') : el('span')) : el('span'),
    ));
}

export async function renderGoals() {
    const response = await run('goals');
    if (!response) return el('div', { class: 'empty', text: L('error_failed') });

    const data = response.data[period];
    const hasGoal = !!data.goal;

    return el('div', { class: 'stack' },
        heading(L('ui_tab_goals'), el('span', { class: 'spacer' }),
            segmented([['daily', L('ui_goal_daily')], ['weekly', L('ui_goal_weekly')]], period, (value) => {
                period = value;
                editing = false;
                app.go('goals');
            })),
        goalCard(data.goal),
        el('div', { class: 'banner' }, icon('target', 18, 2), el('span', { text: L('ui_goal_hint') })),
        el('div', { class: 'card flush' },
            el('div', { class: 'card-head padded' }, el('strong', { text: L('ui_ranking') })),
            el('div', { class: 'table-head rank-cols' },
                ['', 'ui_member', 'ui_put_in', 'ui_took_out', 'ui_net', hasGoal ? 'ui_progress' : '', ''].map((key) => el('span', { text: key ? L(key) : '' }))),
            data.rows.length ? rankingRows(data.rows, hasGoal) : el('div', { class: 'table-row muted', text: L('ui_nobody') })),
    );
}
