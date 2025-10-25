const express = require('express');
const router = express.Router();

// Placeholder for toolkit routes
router.get('/', (req, res) => {
    res.json({
        message: 'AITB Toolkit API',
        status: 'available',
        timestamp: new Date().toISOString()
    });
});

module.exports = router;