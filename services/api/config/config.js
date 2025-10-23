require('dotenv').config();

const config = {
    // Environment
    environment: process.env.NODE_ENV || 'development',
    
    // Server Configuration
    server: {
        port: parseInt(process.env.API_PORT) || 3000,
        host: process.env.API_HOST || '0.0.0.0'
    },

    // Database Configuration
    database: {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT) || 5432,
        name: process.env.DB_NAME || 'aitb',
        user: process.env.DB_USER || 'aitb_user',
        password: process.env.DB_PASSWORD || 'aitb_secure_password',
        ssl: process.env.DB_SSL === 'true',
        maxConnections: parseInt(process.env.DB_MAX_CONNECTIONS) || 20,
        idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000
    },

    // Redis Configuration
    redis: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT) || 6379,
        password: process.env.REDIS_PASSWORD || 'redis_secure_password',
        db: parseInt(process.env.REDIS_DB) || 0,
        keyPrefix: process.env.REDIS_KEY_PREFIX || 'aitb:',
        maxRetriesPerRequest: 3,
        retryDelayOnFailover: 100,
        enableReadyCheck: false,
        maxRetriesPerRequest: null
    },

    // JWT Configuration
    jwt: {
        secret: process.env.JWT_SECRET || 'your_jwt_secret_here',
        expiresIn: process.env.JWT_EXPIRES_IN || '24h',
        refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d'
    },

    // File Upload Configuration
    upload: {
        maxSize: parseInt(process.env.UPLOAD_MAX_SIZE) || 10 * 1024 * 1024, // 10MB
        allowedTypes: ['image/jpeg', 'image/png', 'image/gif', 'application/pdf', 'text/plain'],
        destination: process.env.UPLOAD_DESTINATION || './uploads'
    },

    // Logging Configuration
    logging: {
        level: process.env.LOG_LEVEL || 'info',
        filename: process.env.LOG_FILENAME || 'aitb-api.log',
        maxFiles: process.env.LOG_MAX_FILES || 14,
        maxSize: process.env.LOG_MAX_SIZE || '20m'
    },

    // Security Configuration
    security: {
        rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
        rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX) || 100,
        corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:3001',
        bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS) || 12
    },

    // External Services
    services: {
        openaiApiKey: process.env.OPENAI_API_KEY || '',
        anthropicApiKey: process.env.ANTHROPIC_API_KEY || '',
        githubToken: process.env.GITHUB_TOKEN || ''
    }
};

module.exports = config;