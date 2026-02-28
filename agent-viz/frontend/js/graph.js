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

            // Sort nodes by timestamp to assign hierarchical levels
            const sorted = [...data.nodes].sort((a, b) => {
                const ta = a.timestamp || a.createdAt || a.startedAt || '';
                const tb = b.timestamp || b.createdAt || b.startedAt || '';
                return ta.localeCompare(tb);
            });

            // Assign levels: Agents at top, then Sessions, then Actions by time
            const levelMap = {};
            let actionLevel = 2;
            sorted.forEach(n => {
                if (n.type === 'Agent') {
                    levelMap[n.id] = 0;
                } else if (n.type === 'Session') {
                    levelMap[n.id] = 1;
                } else {
                    levelMap[n.id] = actionLevel++;
                }
            });

            const nodes = new vis.DataSet(
                data.nodes.map(n => ({
                    id: n.id,
                    label: (n.label || n.id).substring(0, 35),
                    level: levelMap[n.id] || 0,
                    color: n.type === 'Agent' ? '#e94560' :
                           n.type === 'Session' ? '#0fbcf9' : '#ffffff',
                    shape: n.type === 'Agent' ? 'dot' :
                           n.type === 'Session' ? 'diamond' : 'dot',
                    size: n.type === 'Agent' ? 30 : n.type === 'Session' ? 18 : 8,
                    font: { color: '#ffffff', size: 10 }
                }))
            );

            const edges = new vis.DataSet(
                data.edges.map(e => ({
                    from: e.source,
                    to: e.target,
                    arrows: 'to',
                    color: { color: '#555', opacity: 0.6 },
                    smooth: { type: 'cubicBezier', roundness: 0.4 }
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
                        levelSeparation: 60,
                        nodeSpacing: 30,
                        treeSpacing: 80,
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
