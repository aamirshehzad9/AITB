const { Pool } = require('pg');
const config = require('./config');
const logger = require('../utils/logger');

class Database {
    constructor() {
        this.pool = null;
        this.connected = false;
    }

    async connect() {
        if (this.connected) {
            return this.pool;
        }

        try {
            this.pool = new Pool({
                host: config.database.host,
                port: config.database.port,
                database: config.database.name,
                user: config.database.user,
                password: config.database.password,
                ssl: config.database.ssl,
                max: config.database.maxConnections,
                idleTimeoutMillis: config.database.idleTimeoutMillis,
                connectionTimeoutMillis: 2000,
            });

            // Test the connection
            const client = await this.pool.connect();
            await client.query('SELECT NOW()');
            client.release();

            this.connected = true;
            logger.info('Database connected successfully');
            
            return this.pool;
        } catch (error) {
            logger.error('Database connection failed:', error);
            throw error;
        }
    }

    async query(text, params) {
        if (!this.connected) {
            throw new Error('Database not connected');
        }

        try {
            const start = Date.now();
            const result = await this.pool.query(text, params);
            const duration = Date.now() - start;
            
            logger.debug('Executed query', { 
                text, 
                duration, 
                rows: result.rowCount 
            });
            
            return result;
        } catch (error) {
            logger.error('Query execution failed:', { text, error: error.message });
            throw error;
        }
    }

    async getClient() {
        if (!this.connected) {
            throw new Error('Database not connected');
        }
        return await this.pool.connect();
    }

    async close() {
        if (this.pool) {
            await this.pool.end();
            this.connected = false;
            logger.info('Database connection closed');
        }
    }

    // Health check method
    async healthCheck() {
        try {
            const result = await this.query('SELECT 1 as healthy');
            return result.rows[0].healthy === 1;
        } catch (error) {
            logger.error('Database health check failed:', error);
            return false;
        }
    }
}

// Create singleton instance
const database = new Database();

module.exports = database;