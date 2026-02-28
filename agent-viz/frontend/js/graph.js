/**
 * Graph visualization using vis-network via API
 * Top-down triangular layout: Agent -> Sessions -> Action chains by time
 */
let networkInstance = null;

const GraphViz = {
    init() {
        this.renderFromAPI();
    },

    refresh() {
        this.renderFromAPI();
    },

    updateQuery(showActions, showSessions) {
        this.renderFromAPI();
    },

    showFallback() {
        const container = document.getElementById('graph-container');
        container.innerHTML = `
            <div style="padding: 40px; text-align: center; color: #a0a0a0;">
                <h3>Graph Visualization</h3>
                <p>No graph data available yet. Click Sync to load sessions.</p>
            </div>
        `;
    },

    async renderFromAPI() {
        const container = document.getElementById('graph-container');

        try {
            const data = await API.getGraph(150);

            if (!data.nodes || data.nodes.length === 0) {
                this.showFallback();
                return;
            }

            if (typeof vis === 'undefined' || !vis.Network) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement('script');
                    script.src = 'https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js';
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            // Categorize edges
            const hasSession = [];   // Agent -> Session
            const followedBy = [];   // Action -> Action (temporal chain)
            const contains = [];     // Session -> Action (all actions)
            const spawned = [];      // Agent -> Agent

            // Track which actions have an incoming FOLLOWED_BY
            const hasIncomingFollow = new Set();

            data.edges.forEach(e => {
                if (e.type === 'HAS_SESSION') hasSession.push(e);
                else if (e.type === 'FOLLOWED_BY') {
                    followedBy.push(e);
                    hasIncomingFollow.add(e.target);
                }
                else if (e.type === 'CONTAINS') contains.push(e);
                else if (e.type === 'SPAWNED') spawned.push(e);
            });

            // Build display edges:
            // 1. Agent -> Session (HAS_SESSION)
            // 2. Session -> first action only (CONTAINS where target has no incoming FOLLOWED_BY)
            // 3. Action -> Action (FOLLOWED_BY chains)
            // 4. Agent -> Agent (SPAWNED)
            const displayEdges = [
                ...hasSession,
                ...spawned,
                ...followedBy,
                ...contains.filter(e => !hasIncomingFollow.has(e.target))
            ];

            // BFS from agent roots to assign tree depth levels
            const nodeSet = new Set(data.nodes.map(n => n.id));
            const childrenOf = {};
            displayEdges.forEach(e => {
                if (nodeSet.has(e.source) && nodeSet.has(e.target)) {
                    if (!childrenOf[e.source]) childrenOf[e.source] = [];
                    childrenOf[e.source].push(e.target);
                }
            });

            const levelMap = {};
            const roots = data.nodes.filter(n => n.type === 'Agent').map(n => n.id);
            const queue = roots.map(id => ({ id, level: 0 }));
            const visited = new Set();

            while (queue.length > 0) {
                const { id, level } = queue.shift();
                if (visited.has(id)) continue;
                visited.add(id);
                levelMap[id] = level;
                (childrenOf[id] || []).forEach(childId => {
                    if (!visited.has(childId)) {
                        queue.push({ id: childId, level: level + 1 });
                    }
                });
            }

            // Fallback for unvisited nodes
            data.nodes.forEach(n => {
                if (!(n.id in levelMap)) {
                    if (n.type === 'Agent') levelMap[n.id] = 0;
                    else if (n.type === 'Session') levelMap[n.id] = 1;
                    else levelMap[n.id] = 2;
                }
            });

            // Build rich labels with metadata
            function buildLabel(n) {
                if (n.type === 'Agent') return n.label || n.id;
                if (n.type === 'Session') {
                    let label = (n.label || n.id).substring(0, 40);
                    if (n.model) label += '\n' + n.model;
                    if (n.channel) label += ' · ' + n.channel;
                    return label;
                }
                // Action nodes
                let lines = [];
                const name = n.label || n.action_type || n.id;
                const atype = n.action_type || '';
                lines.push(atype !== name ? `${atype}: ${name}` : name);
                if (n.details) {
                    try {
                        const d = typeof n.details === 'string' ?
                            n.details.replace(/'/g, '"') : n.details;
                        const parsed = JSON.parse(d);
                        if (parsed.tool) lines[0] = parsed.tool;
                        if (parsed.args_preview) {
                            const args = parsed.args_preview.substring(0, 60);
                            lines.push(args);
                        }
                    } catch(e) {
                        const detail = String(n.details).substring(0, 60);
                        if (detail && detail !== '{}') lines.push(detail);
                    }
                }
                if (n.timestamp) {
                    const t = new Date(n.timestamp);
                    lines.push(t.toLocaleTimeString());
                }
                return lines.join('\n');
            }

            const nodes = new vis.DataSet(
                data.nodes.map(n => ({
                    id: n.id,
                    label: buildLabel(n),
                    level: levelMap[n.id],
                    color: n.type === 'Agent' ? '#e94560' :
                           n.type === 'Session' ? '#0fbcf9' : '#ffffff',
                    shape: n.type === 'Agent' ? 'dot' :
                           n.type === 'Session' ? 'diamond' : 'dot',
                    size: n.type === 'Agent' ? 28 : n.type === 'Session' ? 16 : 6,
                    font: {
                        color: '#ffffff',
                        size: n.type === 'Action' ? 11 : 12,
                        face: 'Satoshi, sans-serif',
                        multi: 'text',
                        align: 'center'
                    }
                }))
            );

            const edges = new vis.DataSet(
                displayEdges
                    .filter(e => nodeSet.has(e.source) && nodeSet.has(e.target))
                    .map(e => ({
                        from: e.source,
                        to: e.target,
                        arrows: { to: { enabled: true, scaleFactor: 0.4 } },
                        color: { color: '#333', opacity: 0.4 },
                        smooth: { type: 'cubicBezier', roundness: 0.5 }
                    }))
            );

            if (networkInstance) {
                networkInstance.destroy();
            }

            networkInstance = new vis.Network(container, { nodes, edges }, {
                layout: {
                    hierarchical: {
                        direction: 'UD',
                        sortMethod: 'directed',
                        levelSeparation: 180,
                        nodeSpacing: 200,
                        treeSpacing: 200,
                        shakeTowards: 'roots'
                    }
                },
                physics: { enabled: false },
                interaction: {
                    hover: true,
                    tooltipDelay: 100,
                    zoomView: true,
                    dragView: true
                }
            });

        } catch (error) {
            console.error('Failed to render graph from API:', error);
            this.showFallback();
        }
    }
};
