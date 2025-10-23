const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const config = require('../config/config');
const database = require('../config/database');
const redis = require('../config/redis');
const logger = require('../utils/logger');

const router = express.Router();

// Register endpoint
router.post('/register', async (req, res) => {
    try {
        const { username, email, password, fullName } = req.body;

        // Validate input
        if (!username || !email || !password) {
            return res.status(400).json({
                error: 'Username, email, and password are required'
            });
        }

        // Check if user already exists
        const existingUser = await database.query(
            'SELECT id FROM users WHERE username = $1 OR email = $2',
            [username, email]
        );

        if (existingUser.rows.length > 0) {
            return res.status(409).json({
                error: 'Username or email already exists'
            });
        }

        // Hash password
        const hashedPassword = await bcrypt.hash(password, config.security.bcryptRounds);

        // Create user
        const result = await database.query(
            `INSERT INTO users (username, email, password_hash, full_name, created_at) 
             VALUES ($1, $2, $3, $4, NOW()) 
             RETURNING id, username, email, full_name, created_at`,
            [username, email, hashedPassword, fullName]
        );

        const newUser = result.rows[0];

        logger.logBusiness('user_registered', newUser.id, {
            username: newUser.username,
            email: newUser.email
        });

        res.status(201).json({
            message: 'User registered successfully',
            user: {
                id: newUser.id,
                username: newUser.username,
                email: newUser.email,
                fullName: newUser.full_name,
                createdAt: newUser.created_at
            }
        });

    } catch (error) {
        logger.error('Registration failed:', error);
        res.status(500).json({
            error: 'Registration failed'
        });
    }
});

// Login endpoint
router.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({
                error: 'Username and password are required'
            });
        }

        // Find user
        const result = await database.query(
            'SELECT id, username, email, password_hash, full_name, last_login FROM users WHERE username = $1 OR email = $1',
            [username]
        );

        if (result.rows.length === 0) {
            logger.logSecurityEvent('failed_login_attempt', {
                username,
                reason: 'user_not_found',
                ip: req.ip
            });
            
            return res.status(401).json({
                error: 'Invalid credentials'
            });
        }

        const user = result.rows[0];

        // Verify password
        const isValidPassword = await bcrypt.compare(password, user.password_hash);
        if (!isValidPassword) {
            logger.logSecurityEvent('failed_login_attempt', {
                username,
                userId: user.id,
                reason: 'invalid_password',
                ip: req.ip
            });
            
            return res.status(401).json({
                error: 'Invalid credentials'
            });
        }

        // Generate JWT tokens
        const tokenPayload = {
            userId: user.id,
            username: user.username,
            email: user.email
        };

        const accessToken = jwt.sign(tokenPayload, config.jwt.secret, {
            expiresIn: config.jwt.expiresIn
        });

        const refreshToken = jwt.sign(tokenPayload, config.jwt.secret, {
            expiresIn: config.jwt.refreshExpiresIn
        });

        // Store refresh token in Redis
        await redis.set(
            `refresh_token:${user.id}`, 
            refreshToken, 
            7 * 24 * 60 * 60 // 7 days in seconds
        );

        // Update last login
        await database.query(
            'UPDATE users SET last_login = NOW() WHERE id = $1',
            [user.id]
        );

        logger.logBusiness('user_logged_in', user.id, {
            username: user.username,
            ip: req.ip
        });

        res.json({
            message: 'Login successful',
            user: {
                id: user.id,
                username: user.username,
                email: user.email,
                fullName: user.full_name,
                lastLogin: user.last_login
            },
            tokens: {
                accessToken,
                refreshToken
            }
        });

    } catch (error) {
        logger.error('Login failed:', error);
        res.status(500).json({
            error: 'Login failed'
        });
    }
});

// Refresh token endpoint
router.post('/refresh', async (req, res) => {
    try {
        const { refreshToken } = req.body;

        if (!refreshToken) {
            return res.status(400).json({
                error: 'Refresh token is required'
            });
        }

        // Verify refresh token
        const decoded = jwt.verify(refreshToken, config.jwt.secret);
        
        // Check if token exists in Redis
        const storedToken = await redis.get(`refresh_token:${decoded.userId}`);
        if (!storedToken || storedToken !== refreshToken) {
            return res.status(401).json({
                error: 'Invalid refresh token'
            });
        }

        // Generate new access token
        const tokenPayload = {
            userId: decoded.userId,
            username: decoded.username,
            email: decoded.email
        };

        const newAccessToken = jwt.sign(tokenPayload, config.jwt.secret, {
            expiresIn: config.jwt.expiresIn
        });

        res.json({
            accessToken: newAccessToken
        });

    } catch (error) {
        logger.error('Token refresh failed:', error);
        res.status(401).json({
            error: 'Invalid refresh token'
        });
    }
});

// Logout endpoint
router.post('/logout', async (req, res) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: 'Access token required'
            });
        }

        const token = authHeader.substring(7);
        const decoded = jwt.verify(token, config.jwt.secret);

        // Remove refresh token from Redis
        await redis.del(`refresh_token:${decoded.userId}`);

        logger.logBusiness('user_logged_out', decoded.userId, {
            username: decoded.username
        });

        res.json({
            message: 'Logout successful'
        });

    } catch (error) {
        logger.error('Logout failed:', error);
        res.status(500).json({
            error: 'Logout failed'
        });
    }
});

module.exports = router;