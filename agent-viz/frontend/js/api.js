/**
 * API client for Agent-Viz backend
 */
const API = {
    baseUrl: window.location.hostname === 'localhost' 
        ? 'http://localhost:8000' 
        : window.location.origin,

    async fetch(endpoint, options = {}) {
        try {
            const response = await fetch(`${this.baseUrl}${endpoint}`, {
                ...options,
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                }
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.json();
        } catch (error) {
            console.error(`API error: ${endpoint}`, error);
            throw error;
        }
    },

    async getStats() {
        return this.fetch('/api/stats');
    },

    async getAgents() {
        return this.fetch('/api/agents');
    },

    async getSessions(limit = 50) {
        return this.fetch(`/api/sessions?limit=${limit}`);
    },

    async getSession(sessionId) {
        return this.fetch(`/api/session/${sessionId}`);
    },

    async getGraph(limit = 100) {
        return this.fetch(`/api/graph?limit=${limit}`);
    },

    async getTools() {
        return this.fetch('/api/tools');
    },

    async triggerSync(force = false) {
        return this.fetch(`/api/sync?force=${force}`, { method: 'POST' });
    }
};
