const winston = require('winston');
const DailyRotateFile = require('winston-daily-rotate-file');
const path = require('path');
const fs = require('fs');

// Ensure logs directory exists
const logsDir = path.join(process.cwd(), 'logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

// Custom format for structured logging
const customFormat = winston.format.combine(
    winston.format.timestamp({
        format: 'YYYY-MM-DD HH:mm:ss.SSS'
    }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.prettyPrint()
);

// Console format for development
const consoleFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({
        format: 'HH:mm:ss'
    }),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
        let output = `${timestamp} [${level}]: ${message}`;
        
        if (Object.keys(meta).length > 0) {
            output += `\n${JSON.stringify(meta, null, 2)}`;
        }
        
        return output;
    })
);

// Create transports
const transports = [];

// Console transport (always enabled in development)
if (process.env.NODE_ENV !== 'production') {
    transports.push(
        new winston.transports.Console({
            format: consoleFormat,
            level: 'debug'
        })
    );
}

// File transports
const fileTransports = [
    // All logs
    new DailyRotateFile({
        filename: path.join(logsDir, 'aitb-api-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        maxSize: '20m',
        maxFiles: '14d',
        format: customFormat,
        level: 'info'
    }),

    // Error logs only
    new DailyRotateFile({
        filename: path.join(logsDir, 'aitb-api-error-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        maxSize: '20m',
        maxFiles: '30d',
        format: customFormat,
        level: 'error'
    }),

    // Performance logs
    new DailyRotateFile({
        filename: path.join(logsDir, 'aitb-api-performance-%DATE%.log'),
        datePattern: 'YYYY-MM-DD',
        maxSize: '10m',
        maxFiles: '7d',
        format: customFormat,
        level: 'debug'
    })
];

transports.push(...fileTransports);

// Create logger instance
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: customFormat,
    defaultMeta: { 
        service: 'aitb-api',
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    },
    transports,
    exceptionHandlers: [
        new DailyRotateFile({
            filename: path.join(logsDir, 'aitb-api-exceptions-%DATE%.log'),
            datePattern: 'YYYY-MM-DD',
            maxSize: '20m',
            maxFiles: '30d',
            format: customFormat
        })
    ],
    rejectionHandlers: [
        new DailyRotateFile({
            filename: path.join(logsDir, 'aitb-api-rejections-%DATE%.log'),
            datePattern: 'YYYY-MM-DD',
            maxSize: '20m',
            maxFiles: '30d',
            format: customFormat
        })
    ]
});

// Add request logging helper
logger.logRequest = (req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = Date.now() - start;
        const logLevel = res.statusCode >= 400 ? 'error' : 'info';
        
        logger.log(logLevel, 'HTTP Request', {
            method: req.method,
            url: req.url,
            statusCode: res.statusCode,
            duration: `${duration}ms`,
            userAgent: req.get('User-Agent'),
            ip: req.ip,
            contentLength: res.get('Content-Length')
        });
    });
    
    next();
};

// Add performance logging helper
logger.logPerformance = (operation, startTime, metadata = {}) => {
    const duration = Date.now() - startTime;
    logger.debug('Performance', {
        operation,
        duration: `${duration}ms`,
        ...metadata
    });
};

// Add security event logging
logger.logSecurityEvent = (event, details) => {
    logger.warn('Security Event', {
        event,
        timestamp: new Date().toISOString(),
        ...details
    });
};

// Add business logic logging
logger.logBusiness = (action, userId, details) => {
    logger.info('Business Action', {
        action,
        userId,
        timestamp: new Date().toISOString(),
        ...details
    });
};

module.exports = logger;