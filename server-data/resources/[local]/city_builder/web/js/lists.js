// The Placed, Groups and Hidden tabs.
import { t, post, el, button, confirmBox, infoBox, copyText } from './util.js';
import { setGroups as inspectorGroups } from './inspector.js';

let groups = [];

function empty(list, key) {
    list.append(el('div', 'empty', t(key)));
}

function renderPlaced(rows) {
    const list = document.getElementById('placed');
    list.replaceChildren();
    if (!rows.length) return empty(list, 'placed_empty');

    for (const row of rows) {
        const item = el('div', 'item');
        item.append(el('div', 'name', `#${row.id} ${row.model}`));
        if (row.group) item.append(el('div', 'meta', row.group));
        item.append(el('div', 'meta', t('metres', Math.round(row.distance))));
        item.addEventListener('click', () => post('goto', { id: row.id }));
        list.append(item);
    }
}

function renderHidden(rows) {
    const list = document.getElementById('hidden');
    list.replaceChildren();
    if (!rows.length) return empty(list, 'hidden_empty');

    for (const row of rows) {
        const item = el('div', 'item');
        item.append(el('div', 'name', row.label), el('div', 'meta', t('metres', Math.round(row.distance))));
        item.append(button(t('unhide'), 'small', async (event) => {
            event.stopPropagation();
            const result = await post('unhide', { id: row.id });
            if (result && result.list) renderHidden(result.list);
        }));
        item.addEventListener('click', () => post('goto', { id: row.id, hide: true }));
        list.append(item);
    }
}

async function groupAction(data) {
    const result = await post('group', data);
    if (result && result.groups) setGroups(result.groups);
    return result && result.ok;
}

async function exportGroup(group) {
    if (!(await confirmBox(t('export_confirm', group.name, group.count)))) return;

    const result = await post('group', { action: 'export', id: group.id });
    if (result && result.groups) setGroups(result.groups);
    if (!result || !result.ok || !result.export) return;

    const done = result.export;
    const copied = copyText(done.xml);

    infoBox([t('export_done', done.count, done.name), t('export_file', done.file), t(copied ? 'export_copied' : 'export_not_copied'), t('export_next')].join('\n\n'), [
        [t('export_copy'), () => copyText(done.xml)],
    ]);
}

function renderGroups() {
    const list = document.getElementById('groups');
    list.replaceChildren();
    if (!groups.length) return empty(list, 'group_empty');

    for (const group of groups) {
        const item = el('div', `item${group.enabled ? '' : ' off'}`);
        item.style.flexWrap = 'wrap';
        item.style.cursor = 'default';
        item.append(el('div', 'name', group.name), el('div', 'meta', t('group_props', group.count)));

        const actions = el('div', 'actions');
        actions.style.width = '100%';
        actions.style.marginTop = '4px';

        if (group.ungrouped) {
            actions.append(button(t('group_export'), 'small accent', () => exportGroup(group)));
            item.append(actions);
            list.append(item);
            continue;
        }

        actions.append(
            button(t('group_show'), group.enabled ? 'small on' : 'small', () => groupAction({ action: 'update', id: group.id, name: group.name, enabled: !group.enabled })),
            button(t('group_goto'), 'small', () => groupAction({ action: 'goto', id: group.id })),
            button(t('group_rename'), 'small', async () => {
                const values = await confirmBox(t('group_rename'), [{ value: group.name, placeholder: t('group_name') }]);
                if (values) groupAction({ action: 'update', id: group.id, name: values[0], enabled: group.enabled });
            }),
            button(t('group_move'), 'small', async () => {
                const values = await confirmBox(t('group_move_title', group.name), [
                    { type: 'number', step: '0.1', placeholder: 'X', value: 0 },
                    { type: 'number', step: '0.1', placeholder: 'Y', value: 0 },
                    { type: 'number', step: '0.1', placeholder: 'Z', value: 0 },
                ]);
                if (values) groupAction({ action: 'move', id: group.id, x: Number(values[0]) || 0, y: Number(values[1]) || 0, z: Number(values[2]) || 0 });
            }),
            button(t('group_export'), 'small accent', () => exportGroup(group)),
            button(t('group_delete'), 'small danger', async () => {
                if (await confirmBox(t('group_delete_confirm', group.name, group.count))) groupAction({ action: 'delete', id: group.id });
            }),
        );
        item.append(actions);
        list.append(item);
    }
}

export function setGroups(next) {
    groups = next || [];
    inspectorGroups(groups);
    renderGroups();
}

export async function refresh() {
    const result = await post('lists');
    if (!result) return;

    renderPlaced(result.placed || []);
    renderHidden(result.hides || []);
    setGroups(result.groups || []);
}

export function init() {
    const name = document.getElementById('groupName');
    const create = async () => {
        if (!name.value.trim()) return;
        if (await groupAction({ action: 'create', name: name.value })) name.value = '';
    };

    document.getElementById('groupCreate').addEventListener('click', create);
    name.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') create();
    });
}
