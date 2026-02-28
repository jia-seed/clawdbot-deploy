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

            const nodes = new vis.DataSet(
                data.nodes.map(n => ({
                    id: n.id,
                    label: (n.label || n.id).substring(0, 35),
                    color: n.type === 'Agent' ? '#e94560' :
                           n.type === 'Session' ? '#0fbcf9' : '#00d9a5',
                    shape: n.type === 'Agent' ? 'dot' :
                           n.type === 'Session' ? 'diamond' : 'triangle',
                    size: n.type === 'Agent' ? 30 : n.type === 'Session' ? 18 : 10,
                    font: { color: '#ffffff', size: 10 }
                }))
            );

            const edges = new vis.DataSet(
                data.edges.map(e => ({
                    from: e.source,
                    to: e.target,
                    arrows: 'to',
                    color: { color: '#555', opacity: 0.6 }
                }))
            );

            if (networkInstance) {
                networkInstance.destroy();
            }

            networkInstance = new vis.Network(container, { nodes, edges }, {
                physics: {
                    enabled: true,
                    solver: 'forceAtlas2Based',
                    forceAtlas2Based: {
                        gravitationalConstant: -80,
                        springLength: 120
                    },
                    stabilization: { iterations: 150 }
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
