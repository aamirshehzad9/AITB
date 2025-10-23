const Redis = require('redis');
const config = require('./config');
const logger = require('../utils/logger');

class RedisClient {
    constructor() {
        this.client = null;
        this.connected = false;
    }

    async connect() {
        if (this.connected) {
            return this.client;
        }

        try {
            this.client = Redis.createClient({
                host: config.redis.host,
                port: config.redis.port,
                password: config.redis.password,
                db: config.redis.db,
                prefix: config.redis.keyPrefix,
                retryDelayOnFailover: config.redis.retryDelayOnFailover,
                maxRetriesPerRequest: config.redis.maxRetriesPerRequest,
                enableReadyCheck: config.redis.enableReadyCheck
            });

            this.client.on('error', (err) => {
                logger.error('Redis Client Error:', err);
            });

            this.client.on('connect', () => {
                logger.info('Redis client connected');
            });

            this.client.on('ready', () => {
                this.connected = true;
                logger.info('Redis client ready');
            });

            this.client.on('end', () => {
                this.connected = false;
                logger.info('Redis client disconnected');
            });

            await this.client.connect();
            
            // Test the connection
            await this.client.ping();
            
            return this.client;
        } catch (error) {
            logger.error('Redis connection failed:', error);
            throw error;
        }
    }

    async get(key) {
        if (!this.connected) {
            throw new Error('Redis not connected');
        }

        try {
            const value = await this.client.get(key);
            return value ? JSON.parse(value) : null;
        } catch (error) {
            logger.error('Redis GET error:', { key, error: error.message });
            throw error;
        }
    }

    async set(key, value, expiration = null) {
        if (!this.connected) {
            throw new Error('Redis not connected');
        }

        try {
            const stringValue = JSON.stringify(value);
            if (expiration) {
                return await this.client.setEx(key, expiration, stringValue);
            } else {
                return await this.client.set(key, stringValue);
            }
        } catch (error) {
            logger.error('Redis SET error:', { key, error: error.message });
            throw error;
        }
    }

    async del(key) {
        if (!this.connected) {
            throw new Error('Redis not connected');
        }

        try {
            return await this.client.del(key);
        } catch (error) {
            logger.error('Redis DEL error:', { key, error: error.message });
            throw error;
        }
    }

    async exists(key) {
        if (!this.connected) {
            throw new Error('Redis not connected');
        }

        try {
            return await this.client.exists(key);
        } catch (error) {
            logger.error('Redis EXISTS error:', { key, error: error.message });
            throw error;
        }
    }

    async hget(hash, field) {
        if (!this.connected) {
            throw new Error('Redis not connected');
        }

        try {
            const value = await this.client.hGet(hash, field);
            return value ? JSON.parse(value) : null;
        } catch (error) {
            logger.error('Redis HGET error:', { hash, field, error: error.message });
            throw error;
        }
    }

    async hset(hash, field, value) {
        if (!this.connected) {
            throw new Error('Redis not connected');
        }

        try {
            return await this.client.hSet(hash, field, JSON.stringify(value));
        } catch (error) {
            logger.error('Redis HSET error:', { hash, field, error: error.message });
            throw error;
        }
    }

    async disconnect() {
        if (this.client) {
            await this.client.disconnect();
            this.connected = false;
            logger.info('Redis connection closed');
        }
    }

    // Health check method
    async healthCheck() {
        try {
            const pong = await this.client.ping();
            return pong === 'PONG';
        } catch (error) {
            logger.error('Redis health check failed:', error);
            return false;
        }
    }
}

// Create singleton instance
const redisClient = new RedisClient();

module.exports = redisClient;