/**
 * Graph visualization using vis-network via API
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

            // Load vis-network from CDN if not already loaded
            if (typeof vis === 'undefined' || !vis.Network) {
                await new Promise((resolve, reject) => {
                    const script = document.createElement('script');
                    script.src = 'https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js';
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }

            // Filter out FOLLOWED_BY edges — they create linear chains
            // Keep HAS_SESSION, CONTAINS, SPAWNED for tree structure
            const treeEdges = data.edges.filter(e =>
                e.type !== 'FOLLOWED_BY'
            );

            // Build adjacency: parent -> children from tree edges
            const childrenOf = {};
            const nodeById = {};
            data.nodes.forEach(n => { nodeById[n.id] = n; });
            treeEdges.forEach(e => {
                if (!childrenOf[e.source]) childrenOf[e.source] = [];
                childrenOf[e.source].push(e.target);
            });

            // BFS from roots to assign levels (tree depth)
            const levelMap = {};
            const roots = data.nodes
                .filter(n => n.type === 'Agent')
                .map(n => n.id);

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

            // Assign remaining unvisited nodes a default level
            data.nodes.forEach(n => {
                if (!(n.id in levelMap)) {
                    if (n.type === 'Agent') levelMap[n.id] = 0;
                    else if (n.type === 'Session') levelMap[n.id] = 1;
                    else levelMap[n.id] = 2;
                }
            });

            const nodes = new vis.DataSet(
                data.nodes.map(n => ({
                    id: n.id,
                    label: (n.label || n.id).substring(0, 35),
                    level: levelMap[n.id],
                    color: n.type === 'Agent' ? '#e94560' :
                           n.type === 'Session' ? '#0fbcf9' : '#ffffff',
                    shape: n.type === 'Agent' ? 'dot' :
                           n.type === 'Session' ? 'diamond' : 'dot',
                    size: n.type === 'Agent' ? 30 : n.type === 'Session' ? 18 : 6,
                    font: { color: '#ffffff', size: 10, face: 'Satoshi, sans-serif' }
                }))
            );

            const edges = new vis.DataSet(
                treeEdges.map(e => ({
                    from: e.source,
                    to: e.target,
                    arrows: 'to',
                    color: { color: '#444', opacity: 0.5 },
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
                        levelSeparation: 50,
                        nodeSpacing: 20,
                        treeSpacing: 60,
                        shakeTowards: 'roots'
                    }
                },
                physics: {
                    enabled: false
                },
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
