/**
 * Main application logic for Agent-Viz dashboard
 */

// State
let refreshInterval = null;

// Initialize dashboard
document.addEventListener('DOMContentLoaded', async () => {
    console.log('Agent-Viz Dashboard initializing...');
    
    // Load initial data
    await Promise.all([
        loadStats(),
        loadSessions(),
        loadTools()
    ]);
    
    // Initialize graph
    try {
        GraphViz.init();
    } catch (e) {
        console.error('Graph init failed:', e);
        GraphViz.showFallback();
    }
    
    // Set up event listeners
    setupEventListeners();
    
    // Auto-refresh every 30 seconds
    refreshInterval = setInterval(() => {
        loadStats();
        loadSessions();
    }, 30000);
});

function setupEventListeners() {
    // Graph controls
    document.getElementById('show-actions')?.addEventListener('change', updateGraphFilters);
    document.getElementById('show-sessions')?.addEventListener('change', updateGraphFilters);
    
    // Modal close on outside click
    document.getElementById('session-modal')?.addEventListener('click', (e) => {
        if (e.target.classList.contains('modal')) {
            closeModal();
        }
    });
    
    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') closeModal();
        if (e.key === 'r' && e.ctrlKey) {
            e.preventDefault();
            refreshAll();
        }
    });
}

// Load stats
async function loadStats() {
    try {
        const stats = await API.getStats();
        
        document.getElementById('stat-sessions').textContent = stats.total_sessions || 0;
        document.getElementById('stat-actions').textContent = stats.total_actions || 0;
        document.getElementById('stat-tools').textContent = stats.total_tool_calls || 0;
        document.getElementById('stat-agents').textContent = stats.agents || 0;
        document.getElementById('stat-subagents').textContent = stats.subagents || 0;
    } catch (error) {
        console.error('Failed to load stats:', error);
    }
}

// Load recent sessions
async function loadSessions() {
    const container = document.getElementById('sessions-list');
    
    try {
        const data = await API.getSessions(20);
        
        if (!data.sessions || data.sessions.length === 0) {
            container.innerHTML = '<div class="loading">No sessions found</div>';
            return;
        }
        
        container.innerHTML = data.sessions.map(s => {
            const session = s.session;
            const actionCount = s.action_count || 0;
            const label = session.label || session.id?.substring(0, 8) + '...';
            const time = formatTime(session.started_at);
            
            return `
                <div class="list-item" onclick="showSession('${session.id}')">
                    <div class="list-item-title">${escapeHtml(label)}</div>
                    <div class="list-item-meta">
                        ${time}
                        <span class="list-item-badge">${actionCount} actions</span>
                    </div>
                </div>
            `;
        }).join('');
        
    } catch (error) {
        console.error('Failed to load sessions:', error);
        container.innerHTML = '<div class="loading">Failed to load sessions</div>';
    }
}

// Load tool usage
async function loadTools() {
    const container = document.getElementById('tools-list');
    
    try {
        const data = await API.getTools();
        
        if (!data.tools || data.tools.length === 0) {
            container.innerHTML = '<div class="loading">No tool usage data</div>';
            return;
        }
        
        container.innerHTML = data.tools.slice(0, 15).map(t => `
            <div class="tool-item">
                <span class="tool-name">${escapeHtml(t.tool)}</span>
                <span class="tool-count">${t.usage}×</span>
            </div>
        `).join('');
        
    } catch (error) {
        console.error('Failed to load tools:', error);
        container.innerHTML = '<div class="loading">Failed to load tools</div>';
    }
}

// Show session details modal
async function showSession(sessionId) {
    const modal = document.getElementById('session-modal');
    const title = document.getElementById('modal-title');
    const body = document.getElementById('modal-body');
    
    modal.classList.remove('hidden');
    title.textContent = 'Loading...';
    body.innerHTML = '<div class="loading">Loading session details...</div>';
    
    try {
        const data = await API.getSession(sessionId);
        
        const session = data.session;
        title.textContent = session.label || `Session ${sessionId.substring(0, 8)}...`;
        
        // Build timeline
        const actions = data.actions || [];
        
        let html = `
            <div class="session-meta">
                <p><strong>ID:</strong> ${session.id}</p>
                <p><strong>Started:</strong> ${formatTime(session.started_at)}</p>
                ${session.model ? `<p><strong>Model:</strong> ${session.model}</p>` : ''}
                ${session.channel ? `<p><strong>Channel:</strong> ${session.channel}</p>` : ''}
                <p><strong>Actions:</strong> ${actions.length}</p>
            </div>
            <h3 style="margin: 20px 0 10px;">Action Timeline</h3>
            <div class="timeline">
        `;
        
        for (const action of actions.slice(0, 50)) {
            const typeClass = action.type === 'tool_call' ? 'tool-call' : 
                             action.type === 'user_message' ? 'user-message' : '';
            
            html += `
                <div class="timeline-item ${typeClass}">
                    <div class="timeline-time">${formatTime(action.timestamp)}</div>
                    <div class="timeline-type">${action.type}${action.name ? ': ' + action.name : ''}</div>
                    ${action.details ? `<div class="timeline-details">${escapeHtml(String(action.details).substring(0, 100))}</div>` : ''}
                </div>
            `;
        }
        
        if (actions.length > 50) {
            html += `<div class="timeline-item"><em>... and ${actions.length - 50} more actions</em></div>`;
        }
        
        html += '</div>';
        body.innerHTML = html;
        
    } catch (error) {
        console.error('Failed to load session:', error);
        body.innerHTML = `<div class="loading">Error: ${error.message}</div>`;
    }
}

function closeModal() {
    document.getElementById('session-modal')?.classList.add('hidden');
}

// Trigger sync
async function triggerSync() {
    const btn = document.getElementById('sync-btn');
    btn.textContent = '⏳ Syncing...';
    btn.disabled = true;
    
    try {
        await API.triggerSync();
        
        // Wait a bit for sync to process
        await new Promise(r => setTimeout(r, 2000));
        
        // Reload data
        await Promise.all([
            loadStats(),
            loadSessions(),
            loadTools()
        ]);
        
        GraphViz.refresh();
        
        btn.textContent = '✓ Done!';
        setTimeout(() => {
            btn.textContent = '🔄 Sync';
            btn.disabled = false;
        }, 2000);
        
    } catch (error) {
        console.error('Sync failed:', error);
        btn.textContent = '❌ Error';
        setTimeout(() => {
            btn.textContent = '🔄 Sync';
            btn.disabled = false;
        }, 2000);
    }
}

// Refresh graph with current filters
function updateGraphFilters() {
    const showActions = document.getElementById('show-actions')?.checked ?? true;
    const showSessions = document.getElementById('show-sessions')?.checked ?? true;
    GraphViz.updateQuery(showActions, showSessions);
}

function refreshGraph() {
    GraphViz.refresh();
}

function refreshAll() {
    loadStats();
    loadSessions();
    loadTools();
    GraphViz.refresh();
}

// Utility functions
function formatTime(isoString) {
    if (!isoString) return 'Unknown';
    try {
        const date = new Date(isoString);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        
        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffMins < 1440) return `${Math.floor(diffMins / 60)}h ago`;
        
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } catch {
        return isoString;
    }
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
