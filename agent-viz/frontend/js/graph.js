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

            // Assign hierarchical levels by type and time buckets
            // Agent=0, Session=1, Actions=2+ bucketed by time
            const actions = data.nodes
                .filter(n => n.type !== 'Agent' && n.type !== 'Session')
                .map(n => ({
                    ...n,
                    ts: new Date(n.timestamp || n.createdAt || n.startedAt || 0).getTime()
                }))
                .sort((a, b) => a.ts - b.ts);

            const levelMap = {};
            data.nodes.forEach(n => {
                if (n.type === 'Agent') levelMap[n.id] = 0;
                else if (n.type === 'Session') levelMap[n.id] = 1;
            });

            if (actions.length > 0) {
                // Bucket actions into ~15-25 levels for a nice triangle
                const targetLevels = Math.min(Math.max(Math.ceil(actions.length / 3), 8), 25);
                const minTs = actions[0].ts;
                const maxTs = actions[actions.length - 1].ts;
                const range = maxTs - minTs || 1;

                actions.forEach(n => {
                    const t = (n.ts - minTs) / range; // 0..1
                    levelMap[n.id] = 2 + Math.floor(t * (targetLevels - 1));
                });
            }

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
