const express = require('express');
const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

const router = express.Router();

// AITB Node Configuration
const AITB_CONFIG = {
    node: 'AITB',
    ip: '192.168.1.2',
    port: 8505
};

// Expected GOmini-AI Configuration
const GOMINI_CONFIG = {
    expectedNode: 'GOmini-AI',
    expectedIP: '192.168.1.4',
    port: 8505
};

// Path for storing handshake tokens
const HANDSHAKE_TOKEN_PATH = path.join('D:', 'AITB', 'logs', 'gomini_handshake_token.json');

/**
 * POST /handshake/init
 * Listens for incoming handshake initialization from GOmini-AI
 */
router.post('/init', async (req, res) => {
    try {
        const { node, ip, timestamp } = req.body;
        
        logger.info('Received handshake initialization request', {
            node,
            ip,
            timestamp,
            requestIP: req.ip,
            userAgent: req.get('User-Agent')
        });

        // Validate incoming payload
        if (!node || !ip) {
            logger.warn('Invalid handshake payload - missing required fields', { node, ip });
            return res.status(400).json({
                error: 'Invalid payload',
                message: 'Missing required fields: node, ip'
            });
        }

        // Validate node name
        if (node !== GOMINI_CONFIG.expectedNode) {
            logger.warn('Invalid node name in handshake', { 
                expected: GOMINI_CONFIG.expectedNode, 
                received: node 
            });
            return res.status(401).json({
                error: 'Invalid node',
                message: `Expected node: ${GOMINI_CONFIG.expectedNode}`
            });
        }

        // Validate IP address
        if (ip !== GOMINI_CONFIG.expectedIP) {
            logger.warn('Invalid IP address in handshake', { 
                expected: GOMINI_CONFIG.expectedIP, 
                received: ip 
            });
            return res.status(401).json({
                error: 'Invalid IP',
                message: `Expected IP: ${GOMINI_CONFIG.expectedIP}`
            });
        }

        // Generate response token
        const token = uuidv4();
        const handshakeData = {
            token,
            status: 'linked',
            fromNode: node,
            fromIP: ip,
            toNode: AITB_CONFIG.node,
            toIP: AITB_CONFIG.ip,
            timestamp: new Date().toISOString(),
            requestTimestamp: timestamp
        };

        // Store token in logs directory
        try {
            await fs.writeFile(
                HANDSHAKE_TOKEN_PATH, 
                JSON.stringify(handshakeData, null, 2)
            );
            logger.info('Handshake token stored successfully', { token, path: HANDSHAKE_TOKEN_PATH });
        } catch (error) {
            logger.error('Failed to store handshake token', { error: error.message });
            return res.status(500).json({
                error: 'Internal server error',
                message: 'Failed to store handshake token'
            });
        }

        // Send successful response first
        res.status(200).json({
            token,
            status: 'linked'
        });

        // Perform reverse verification (async, don't wait for response)
        setImmediate(async () => {
            try {
                await performReverseVerification(token);
            } catch (error) {
                logger.error('Reverse verification failed', { error: error.message });
            }
        });

    } catch (error) {
        logger.error('Error in handshake initialization', { error: error.message, stack: error.stack });
        res.status(500).json({
            error: 'Internal server error',
            message: 'Failed to process handshake initialization'
        });
    }
});

/**
 * Perform reverse verification POST to GOmini-AI
 */
async function performReverseVerification(token) {
    const verificationPayload = {
        node: AITB_CONFIG.node,
        ip: AITB_CONFIG.ip,
        token: token,
        timestamp: new Date().toISOString()
    };

    const verificationURL = `http://${GOMINI_CONFIG.expectedIP}:${GOMINI_CONFIG.port}/handshake/verify`;

    try {
        logger.info('Starting reverse verification', { 
            url: verificationURL, 
            payload: verificationPayload 
        });

        const response = await axios.post(verificationURL, verificationPayload, {
            timeout: 10000, // 10 second timeout
            headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'AITB-Host/1.0'
            }
        });

        if (response.status === 200) {
            logger.info('[✓] Linked with GOmini-AI (192.168.1.4) successfully', {
                responseData: response.data,
                token
            });

            // Update the handshake token file with verification status
            try {
                const existingData = await fs.readFile(HANDSHAKE_TOKEN_PATH, 'utf8');
                const handshakeData = JSON.parse(existingData);
                handshakeData.verificationStatus = 'success';
                handshakeData.verificationTimestamp = new Date().toISOString();
                handshakeData.verificationResponse = response.data;

                await fs.writeFile(
                    HANDSHAKE_TOKEN_PATH, 
                    JSON.stringify(handshakeData, null, 2)
                );

                // Log the successful link event
                await logHandshakeEvent('success', token, handshakeData);

                // Update roadmap and sync to GitHub (if needed)
                await updateRoadmapAndSync(handshakeData);

            } catch (fileError) {
                logger.error('Failed to update handshake token file after verification', { 
                    error: fileError.message 
                });
            }
        } else {
            logger.warn('Unexpected response status from GOmini-AI verification', { 
                status: response.status,
                data: response.data 
            });
        }

    } catch (error) {
        logger.error('Reverse verification failed', { 
            error: error.message,
            url: verificationURL,
            token
        });

        // Update handshake token file with failure status
        try {
            const existingData = await fs.readFile(HANDSHAKE_TOKEN_PATH, 'utf8');
            const handshakeData = JSON.parse(existingData);
            handshakeData.verificationStatus = 'failed';
            handshakeData.verificationError = error.message;
            handshakeData.verificationTimestamp = new Date().toISOString();

            await fs.writeFile(
                HANDSHAKE_TOKEN_PATH, 
                JSON.stringify(handshakeData, null, 2)
            );

            await logHandshakeEvent('failed', token, handshakeData);

        } catch (fileError) {
            logger.error('Failed to update handshake token file after verification failure', { 
                error: fileError.message 
            });
        }
    }
}

/**
 * Log handshake event to activity log
 */
async function logHandshakeEvent(status, token, handshakeData) {
    const activityLogPath = path.join('D:', 'AITB', 'logs', 'activity_log.md');
    const timestamp = new Date().toISOString();
    
    let logEntry;
    if (status === 'success') {
        logEntry = `## ${timestamp}\n[✓] Linked with GOmini-AI (192.168.1.4) successfully.\n- Token: ${token}\n- Verification: Completed\n\n`;
    } else {
        logEntry = `## ${timestamp}\n[✗] Failed to link with GOmini-AI (192.168.1.4).\n- Token: ${token}\n- Error: ${handshakeData.verificationError || 'Unknown error'}\n\n`;
    }

    try {
        await fs.appendFile(activityLogPath, logEntry);
        logger.info('Handshake event logged to activity log', { status, token });
    } catch (error) {
        logger.error('Failed to log handshake event', { error: error.message });
    }
}

/**
 * Update roadmap state and sync to GitHub (placeholder)
 */
async function updateRoadmapAndSync(handshakeData) {
    try {
        const roadmapPath = path.join('D:', 'AITB', 'docs', 'roadmap.md');
        
        // Read current roadmap
        let roadmapContent = '';
        try {
            roadmapContent = await fs.readFile(roadmapPath, 'utf8');
        } catch (error) {
            logger.info('Roadmap file not found, creating new one');
            roadmapContent = '# AITB Roadmap\n\n';
        }

        // Add handshake completion to roadmap
        const roadmapUpdate = `\n## Network Connectivity - ${new Date().toISOString()}\n- [✓] GOmini-AI handshake completed successfully\n- Node: ${handshakeData.fromNode}\n- IP: ${handshakeData.fromIP}\n- Token: ${handshakeData.token}\n\n`;
        
        roadmapContent += roadmapUpdate;
        await fs.writeFile(roadmapPath, roadmapContent);
        
        logger.info('Roadmap updated with handshake completion');

        // TODO: Implement GitHub sync if needed
        // This would require GitHub API integration
        
    } catch (error) {
        logger.error('Failed to update roadmap', { error: error.message });
    }
}

/**
 * GET /handshake/status
 * Get current handshake status
 */
router.get('/status', async (req, res) => {
    try {
        const data = await fs.readFile(HANDSHAKE_TOKEN_PATH, 'utf8');
        const handshakeData = JSON.parse(data);
        
        res.json({
            status: 'active',
            handshake: handshakeData,
            node: AITB_CONFIG
        });
    } catch (error) {
        if (error.code === 'ENOENT') {
            res.json({
                status: 'no_handshake',
                message: 'No handshake token found',
                node: AITB_CONFIG
            });
        } else {
            logger.error('Error reading handshake status', { error: error.message });
            res.status(500).json({
                error: 'Failed to read handshake status'
            });
        }
    }
});

module.exports = router;