const app = document.getElementById('app');
const incidentList = document.getElementById('incidentList');
const emptyState = document.getElementById('emptyState');
const detailContent = document.getElementById('detailContent');
const statusFilter = document.getElementById('statusFilter');
const threatFilter = document.getElementById('threatFilter');
const patrolList = document.getElementById('patrolList');
const signalList = document.getElementById('signalList');

let records = [];
let selectedId = null;
let patrols = [];
let signals = [];

function nui(eventName, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((response) => response.json());
}

function formatTime(timestamp) {
    if (!timestamp) return 'Unknown';
    const date = new Date(timestamp * 1000);
    return date.toLocaleString();
}

function formatOptionalTime(timestamp) {
    return timestamp ? formatTime(timestamp) : 'None';
}

function formatCoords(coords) {
    if (!coords) return 'Unknown';
    return `${Number(coords.x || 0).toFixed(2)}, ${Number(coords.y || 0).toFixed(2)}, ${Number(coords.z || 0).toFixed(2)}`;
}

function titleCase(value) {
    return String(value || 'unknown')
        .replace(/_/g, ' ')
        .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function getThreat(record) {
    return record && record.assessment ? record.assessment.finalThreat || 'unknown' : 'unknown';
}

function getSelectedRecord() {
    return records.find((record) => Number(record.id) === Number(selectedId)) || null;
}

function filteredRecords() {
    const status = statusFilter.value;
    const threat = threatFilter.value;

    return records.filter((record) => {
        const statusOk = status === 'all' || record.status === status;
        const threatOk = threat === 'all' || getThreat(record) === threat;
        return statusOk && threatOk;
    });
}

function renderList() {
    const filtered = filteredRecords();
    incidentList.innerHTML = '';

    if (!filtered.length) {
        const empty = document.createElement('div');
        empty.className = 'row-meta';
        empty.textContent = 'No incidents match the current filters.';
        incidentList.appendChild(empty);
        return;
    }

    filtered.forEach((record) => {
        const row = document.createElement('button');
        row.className = `incident-row${Number(record.id) === Number(selectedId) ? ' active' : ''}`;
        row.type = 'button';

        const threat = getThreat(record);
        row.innerHTML = `
            <div class="row-title">
                <span>#${record.id} ${titleCase(record.incidentType)}</span>
                <span class="badge ${threat}">${threat}</span>
            </div>
            <div class="row-meta">${titleCase(record.status)} | ${record.sourceResource || 'unknown'}</div>
            <div class="row-meta">${formatTime(record.createdAt)}</div>
            <div class="row-meta">${record.title || 'Police Incident'}</div>
        `;

        row.addEventListener('click', () => {
            selectedId = record.id;
            render();
        });

        incidentList.appendChild(row);
    });
}

function renderPatrols() {
    if (!patrolList) return;

    patrolList.innerHTML = '';

    if (!patrols.length) {
        const empty = document.createElement('div');
        empty.className = 'empty-list';
        empty.textContent = 'No active patrol units.';
        patrolList.appendChild(empty);
        return;
    }

    patrols.forEach((patrol) => {
        const row = document.createElement('div');
        row.className = 'patrol-row';
        row.innerHTML = `
            <strong>${escapeHtml(patrol.zoneLabel || patrol.zoneKey || 'Unknown Patrol')}</strong>
            <span>${escapeHtml(patrol.status || 'unknown')} | ${escapeHtml(patrol.mode || 'patrol')} | waypoint ${escapeHtml(String(patrol.waypointIndex || '-'))}</span>
            ${patrol.assignedIncidentId ? `<span>Incident #${escapeHtml(String(patrol.assignedIncidentId))}</span>` : ''}
        `;
        patrolList.appendChild(row);
    });
}

function renderSignals() {
    if (!signalList) return;

    signalList.innerHTML = '';

    if (!signals.length) {
        const empty = document.createElement('div');
        empty.className = 'empty-list';
        empty.textContent = 'No patrol detection signals.';
        signalList.appendChild(empty);
        return;
    }

    signals.forEach((signal) => {
        const row = document.createElement('div');
        row.className = 'patrol-row';
        row.innerHTML = `
            <strong>Signal #${escapeHtml(signal.id)} | ${escapeHtml(signal.label || signal.signalType || 'Unknown')}</strong>
            <span>Detected: ${signal.detected ? 'Yes' : 'No'} | Patrol: ${escapeHtml(signal.detectedByPatrolId || 'none')}</span>
        `;
        signalList.appendChild(row);
    });
}

function renderKeyValues(container, data) {
    container.innerHTML = '';
    const entries = Object.entries(data || {});

    if (!entries.length) {
        const empty = document.createElement('div');
        empty.textContent = 'None';
        container.appendChild(empty);
        return;
    }

    entries.forEach(([key, value]) => {
        const row = document.createElement('div');
        const displayValue = typeof value === 'object' && value !== null ? JSON.stringify(value) : String(value);
        row.textContent = `${key}: ${displayValue}`;
        container.appendChild(row);
    });
}

function renderNotes(container, notes) {
    container.innerHTML = '';

    if (!notes || !notes.length) {
        const empty = document.createElement('div');
        empty.textContent = 'No notes recorded.';
        container.appendChild(empty);
        return;
    }

    notes.forEach((note) => {
        const row = document.createElement('div');
        row.textContent = `[${formatTime(note.time || note.timestamp)}] ${note.author || 'unknown'}: ${note.text || note.note || ''}`;
        container.appendChild(row);
    });
}

function renderRecommendedUnits(container, units) {
    const normalizedUnits = Array.isArray(units)
        ? units
        : Object.keys(units || {})
            .sort((a, b) => Number(a) - Number(b))
            .map((key) => units[key])
            .filter(Boolean);

    container.innerHTML = '';

    if (!normalizedUnits.length) {
        const empty = document.createElement('div');
        empty.className = 'muted-row';
        empty.textContent = 'No recommended units.';
        container.appendChild(empty);
        return;
    }

    normalizedUnits.forEach((unit) => {
        const row = document.createElement('div');
        row.className = 'recommended-unit';
        row.textContent = `${titleCase(unit.type || 'patrol')} x${Number(unit.count || 1)}`;
        container.appendChild(row);
    });
}

function renderMovingTarget(container, record) {
    const target = record.movingTarget || {};
    const speed = Number(target.speed || 0);
    const heading = Number(target.heading || 0);
    container.innerHTML = '';

    if (!target.targetId && !target.plate && !target.lastKnownCoords) {
        const empty = document.createElement('div');
        empty.className = 'muted-row';
        empty.textContent = 'No moving target attached.';
        container.appendChild(empty);
        return;
    }

    const rows = [
        ['Target ID', target.targetId ? `#${target.targetId}` : 'Unknown'],
        ['Plate', target.plate || 'Unknown'],
        ['Model', target.model || 'Unknown'],
        ['Status', target.lostAt ? 'Lost' : 'Tracking'],
        ['Last Known', formatCoords(target.lastKnownCoords)],
        ['Speed', Number.isFinite(speed) ? `${Math.round(speed)} mph` : 'Unknown'],
        ['Heading', Number.isFinite(heading) ? String(Math.round(heading)) : 'Unknown'],
        ['Updated', target.updatedAt ? formatTime(target.updatedAt) : 'Unknown'],
        ['Lost', target.lostAt ? formatTime(target.lostAt) : 'No'],
        ['Expired', target.expired ? 'Yes' : 'No']
    ];

    rows.forEach(([label, value]) => {
        const row = document.createElement('div');
        row.className = 'detail-row';
        row.innerHTML = `<span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong>`;
        container.appendChild(row);
    });
}

function renderSuspectInteraction(incident) {
    const el = document.getElementById('suspect-interaction-section');

    if (!el) return;

    const interaction = incident.suspectInteraction;

    if (!interaction) {
        el.innerHTML = '<div class="muted-row">No suspect interaction recorded.</div>';
        return;
    }

    el.innerHTML = `
        <div class="detail-row"><span>Status</span><strong>${escapeHtml(titleCase(interaction.status || 'unknown'))}</strong></div>
        <div class="detail-row"><span>Label</span><strong>${escapeHtml(interaction.label || 'Unknown')}</strong></div>
        <div class="detail-row"><span>Patrol</span><strong>${escapeHtml(interaction.patrolId || '-')}</strong></div>
        <div class="detail-row"><span>Updated</span><strong>${formatTime(interaction.updatedAt)}</strong></div>
    `;
}

function renderDetail() {
    const record = getSelectedRecord();

    if (!record) {
        emptyState.classList.remove('hidden');
        detailContent.classList.add('hidden');
        return;
    }

    emptyState.classList.add('hidden');
    detailContent.classList.remove('hidden');

    const assessment = record.assessment || {};
    const dispatch = record.dispatch || {};
    const dispatchPlan = record.dispatchPlan || {};
    const recommendedUnits = Array.isArray(dispatchPlan.recommendedUnits)
        ? dispatchPlan.recommendedUnits
        : Object.keys(dispatchPlan.recommendedUnits || {})
            .sort((a, b) => Number(a) - Number(b))
            .map((key) => dispatchPlan.recommendedUnits[key])
            .filter(Boolean);
    const threat = assessment.finalThreat || 'unknown';

    document.getElementById('detailSource').textContent = record.sourceResource || 'unknown';
    document.getElementById('detailTitle').textContent = record.title || 'Police Incident';
    document.getElementById('detailMessage').textContent = record.message || 'Incident reported.';
    document.getElementById('detailId').textContent = `#${record.id}`;
    document.getElementById('detailStatus').textContent = titleCase(record.status);
    document.getElementById('detailType').textContent = titleCase(record.incidentType);
    document.getElementById('detailCreated').textContent = formatTime(record.createdAt);
    document.getElementById('detailResponse').textContent = titleCase(assessment.response);
    document.getElementById('detailUnits').textContent = assessment.unitsRecommended || 1;
    document.getElementById('detailLocation').textContent = record.locationText !== 'Unknown' ? record.locationText : formatCoords(record.coords);
    document.getElementById('detailAssigned').textContent = record.assignedUnit || 'Unassigned';
    document.getElementById('detailDispatchType').textContent = titleCase(dispatch.assignedType || 'none');
    document.getElementById('detailAssignedBy').textContent = dispatch.assignedByName || 'None';
    document.getElementById('detailAssignedAt').textContent = formatOptionalTime(dispatch.assignedAt);
    document.getElementById('detailAiStatus').textContent = dispatch.aiStatus ? titleCase(dispatch.aiStatus) : 'None';
    document.getElementById('detailAiScene').textContent = dispatch.aiSceneBehavior ? titleCase(dispatch.aiSceneBehavior) : 'None';
    document.getElementById('detailAiTask').textContent = dispatch.aiTaskId || 'None';
    document.getElementById('detailPatrolId').textContent = dispatch.patrolId || 'None';
    document.getElementById('detailPatrolStatus').textContent = dispatch.patrolStatus ? titleCase(dispatch.patrolStatus) : 'None';
    document.getElementById('detailPursuitStatus').textContent = ['pursuit_active', 'pursuit_lost', 'felony_stop', 'pursuit_cleared'].includes(record.status)
        ? titleCase(record.status)
        : 'None';
    document.getElementById('detailPatrolDistance').textContent = dispatch.patrolDistance
        ? `${Math.round(Number(dispatch.patrolDistance))}m`
        : 'None';
    document.getElementById('dispatchPlanLabel').textContent = dispatchPlan.label || 'None';
    document.getElementById('dispatchPlanAppliedBy').textContent = dispatchPlan.appliedBy || 'None';
    document.getElementById('dispatchPlanAppliedAt').textContent = formatOptionalTime(dispatchPlan.appliedAt);

    const threatBadge = document.getElementById('threatBadge');
    threatBadge.className = `badge ${threat}`;
    threatBadge.textContent = threat;

    const forceBadge = document.getElementById('forceBadge');
    forceBadge.textContent = titleCase(assessment.forcePolicy);

    document.getElementById('unitInput').value = record.assignedUnit || '';
    renderRecommendedUnits(document.getElementById('recommendedUnitsList'), recommendedUnits);
    renderMovingTarget(document.getElementById('movingTargetList'), record);
    renderSuspectInteraction(record);
    renderKeyValues(document.getElementById('metadataList'), record.metadata || {});
    renderNotes(document.getElementById('notesList'), record.notes || []);
}

function render() {
    renderPatrols();
    renderSignals();
    renderList();
    renderDetail();
}

function setData(data) {
    records = Array.isArray(data.records) ? data.records : [];
    patrols = Array.isArray(data.patrols) ? data.patrols : [];
    signals = Array.isArray(data.signals) ? data.signals : [];

    if (!selectedId && records.length) {
        selectedId = records[0].id;
    }

    if (selectedId && !getSelectedRecord()) {
        selectedId = records.length ? records[0].id : null;
    }

    render();
}

function doIncidentAction(action, extra = {}) {
    const record = getSelectedRecord();
    if (!record) return;

    nui('incidentAction', { id: record.id, action, ...extra }).then((result) => {
        if (result && result.records) {
            if (result.incident && result.incident.id) {
                selectedId = result.incident.id;
            }
            setData(result);
        }
    });
}

document.getElementById('closeBtn').addEventListener('click', () => {
    nui('close');
});

document.getElementById('refreshBtn').addEventListener('click', () => {
    nui('refresh').then((result) => {
        if (result && result.records) setData(result);
    });
});

document.getElementById('assignBtn').addEventListener('click', () => {
    const unit = document.getElementById('unitInput').value.trim();
    if (!unit) return;
    doIncidentAction('assign', { unit });
});

document.querySelectorAll('[data-ai-unit]').forEach((button) => {
    button.addEventListener('click', () => {
        doIncidentAction('assign_ai', { aiUnitType: button.dataset.aiUnit });
    });
});

document.getElementById('clearAiBtn').addEventListener('click', () => {
    doIncidentAction('clear_ai');
});

document.getElementById('dispatchPatrolBtn').addEventListener('click', () => {
    doIncidentAction('dispatch_patrol');
});

document.getElementById('dispatchRecommendedBtn').addEventListener('click', () => {
    doIncidentAction('dispatch_recommended');
});

document.getElementById('recalculatePlanBtn').addEventListener('click', () => {
    doIncidentAction('recalculate_plan');
});

document.getElementById('noteBtn').addEventListener('click', () => {
    const input = document.getElementById('noteInput');
    const note = input.value.trim();
    if (!note) return;
    input.value = '';
    doIncidentAction('note', { note });
});

document.getElementById('closeIncidentBtn').addEventListener('click', () => {
    doIncidentAction('close');
});

statusFilter.addEventListener('change', render);
threatFilter.addEventListener('change', render);

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        nui('close');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        app.classList.remove('hidden');
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
    }

    if (data.action === 'setData') {
        setData(data);
    }
});
