const express = require('express');
const database = require('../config/database');
const redis = require('../config/redis');
const logger = require('../utils/logger');

const router = express.Router();

// Basic health check
router.get('/', async (req, res) => {
    const healthData = {
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    };

    try {
        // Check database connection
        const dbHealthy = await database.healthCheck();
        healthData.database = dbHealthy ? 'connected' : 'disconnected';

        // Check Redis connection
        const redisHealthy = await redis.healthCheck();
        healthData.redis = redisHealthy ? 'connected' : 'disconnected';

        // Overall health status
        const overallHealthy = dbHealthy && redisHealthy;
        healthData.status = overallHealthy ? 'OK' : 'DEGRADED';

        const statusCode = overallHealthy ? 200 : 503;
        res.status(statusCode).json(healthData);

        logger.info('Health check performed', {
            status: healthData.status,
            database: healthData.database,
            redis: healthData.redis
        });

    } catch (error) {
        logger.error('Health check failed:', error);
        
        res.status(503).json({
            ...healthData,
            status: 'ERROR',
            error: error.message
        });
    }
});

// Detailed system info (for monitoring)
router.get('/detailed', async (req, res) => {
    try {
        const memoryUsage = process.memoryUsage();
        const cpuUsage = process.cpuUsage();

        const detailedHealth = {
            status: 'OK',
            timestamp: new Date().toISOString(),
            system: {
                uptime: process.uptime(),
                platform: process.platform,
                arch: process.arch,
                nodeVersion: process.version,
                pid: process.pid,
                memory: {
                    rss: `${Math.round(memoryUsage.rss / 1024 / 1024)}MB`,
                    heapTotal: `${Math.round(memoryUsage.heapTotal / 1024 / 1024)}MB`,
                    heapUsed: `${Math.round(memoryUsage.heapUsed / 1024 / 1024)}MB`,
                    external: `${Math.round(memoryUsage.external / 1024 / 1024)}MB`
                },
                cpu: {
                    user: cpuUsage.user,
                    system: cpuUsage.system
                }
            }
        };

        // Test database
        const dbStart = Date.now();
        const dbHealthy = await database.healthCheck();
        const dbLatency = Date.now() - dbStart;
        
        detailedHealth.database = {
            status: dbHealthy ? 'connected' : 'disconnected',
            latency: `${dbLatency}ms`
        };

        // Test Redis
        const redisStart = Date.now();
        const redisHealthy = await redis.healthCheck();
        const redisLatency = Date.now() - redisStart;
        
        detailedHealth.redis = {
            status: redisHealthy ? 'connected' : 'disconnected',
            latency: `${redisLatency}ms`
        };

        // Overall status
        const overallHealthy = dbHealthy && redisHealthy;
        detailedHealth.status = overallHealthy ? 'OK' : 'DEGRADED';

        const statusCode = overallHealthy ? 200 : 503;
        res.status(statusCode).json(detailedHealth);

    } catch (error) {
        logger.error('Detailed health check failed:', error);
        
        res.status(503).json({
            status: 'ERROR',
            timestamp: new Date().toISOString(),
            error: error.message
        });
    }
});

// Readiness probe (for Kubernetes)
router.get('/ready', async (req, res) => {
    try {
        const dbHealthy = await database.healthCheck();
        const redisHealthy = await redis.healthCheck();
        
        if (dbHealthy && redisHealthy) {
            res.status(200).json({ status: 'ready' });
        } else {
            res.status(503).json({ status: 'not ready' });
        }
    } catch (error) {
        res.status(503).json({ status: 'not ready', error: error.message });
    }
});

// Liveness probe (for Kubernetes)
router.get('/live', (req, res) => {
    res.status(200).json({ 
        status: 'alive',
        timestamp: new Date().toISOString()
    });
});

module.exports = router;