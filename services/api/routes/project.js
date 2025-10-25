const express = require('express');
const router = express.Router();

// Placeholder for project routes
router.get('/', (req, res) => {
    res.json({
        message: 'AITB Projects API',
        status: 'available',
        timestamp: new Date().toISOString()
    });
});

module.exports = router;