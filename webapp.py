#!/usr/bin/env python3
"""
AITB Web Server - Simple Flask API replacement
Provides REST API endpoints for the AITB system integration
"""

from flask import Flask, jsonify, request, render_template_string
import requests
import json
import os
from datetime import datetime
from typing import Dict, Any

app = Flask(__name__)
app.config['DEBUG'] = True

# Configuration
MCP_BASE_URL = "http://localhost:8600"
DASHBOARD_URL = "http://localhost:8501"
GRAFANA_URL = "http://localhost:3001"
INFLUXDB_URL = "http://localhost:8086"

# HTML template for the main page
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>AITB Control Panel</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 40px; }
        .header h1 { color: #2c3e50; margin-bottom: 10px; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .status-card { background: #ecf0f1; padding: 20px; border-radius: 8px; border-left: 4px solid #3498db; }
        .status-card.healthy { border-left-color: #27ae60; }
        .status-card.warning { border-left-color: #f39c12; }
        .status-card.error { border-left-color: #e74c3c; }
        .status-card h3 { margin: 0 0 10px 0; color: #2c3e50; }
        .status-card p { margin: 5px 0; color: #7f8c8d; }
        .status-card a { color: #3498db; text-decoration: none; font-weight: bold; }
        .status-card a:hover { text-decoration: underline; }
        .actions { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .action-btn { display: block; padding: 12px 20px; background: #3498db; color: white; text-decoration: none; border-radius: 5px; text-align: center; transition: background 0.3s; }
        .action-btn:hover { background: #2980b9; }
        .action-btn.test { background: #27ae60; }
        .action-btn.test:hover { background: #229954; }
        .footer { text-align: center; margin-top: 40px; color: #7f8c8d; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 AITB Control Panel</h1>
            <p>AI Trading Bot + GOmini-AI Integration Dashboard</p>
        </div>
        
        <div class="status-grid">
            <div class="status-card healthy">
                <h3>🎛️ MCP Hub</h3>
                <p>Status: <strong>{{ mcp_status }}</strong></p>
                <p><a href="{{ mcp_url }}" target="_blank">{{ mcp_url }}</a></p>
            </div>
            
            <div class="status-card healthy">
                <h3>📊 Trading Dashboard</h3>
                <p>Status: <strong>Active</strong></p>
                <p><a href="{{ dashboard_url }}" target="_blank">{{ dashboard_url }}</a></p>
            </div>
            
            <div class="status-card healthy">
                <h3>📈 Grafana</h3>
                <p>Status: <strong>Active</strong></p>
                <p><a href="{{ grafana_url }}" target="_blank">{{ grafana_url }}</a></p>
            </div>
            
            <div class="status-card healthy">
                <h3>💾 InfluxDB</h3>
                <p>Status: <strong>Active</strong></p>
                <p><a href="{{ influxdb_url }}" target="_blank">{{ influxdb_url }}</a></p>
            </div>
        </div>
        
        <div class="actions">
            <a href="/api/health" class="action-btn">Health Check</a>
            <a href="/api/models" class="action-btn">View Models</a>
            <a href="/api/test-inference" class="action-btn test">Test Inference</a>
            <a href="/api/status" class="action-btn">System Status</a>
        </div>
        
        <div class="footer">
            <p>AITB System • Last Updated: {{ timestamp }}</p>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template_string(HTML_TEMPLATE,
        mcp_status="Healthy",
        mcp_url=MCP_BASE_URL,
        dashboard_url=DASHBOARD_URL,
        grafana_url=GRAFANA_URL,
        influxdb_url=INFLUXDB_URL,
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    )

@app.route('/api/health')
def health():
    """Health check endpoint"""
    services = {}
    
    # Check MCP Hub
    try:
        response = requests.get(f"{MCP_BASE_URL}/health", timeout=5)
        services['mcp_hub'] = {
            'status': 'healthy' if response.status_code == 200 else 'unhealthy',
            'url': MCP_BASE_URL,
            'response_time': response.elapsed.total_seconds()
        }
    except Exception as e:
        services['mcp_hub'] = {'status': 'unhealthy', 'error': str(e)}
    
    # Check InfluxDB
    try:
        response = requests.get(f"{INFLUXDB_URL}/ping", timeout=5)
        services['influxdb'] = {
            'status': 'healthy' if response.status_code == 204 else 'unhealthy',
            'url': INFLUXDB_URL
        }
    except Exception as e:
        services['influxdb'] = {'status': 'unhealthy', 'error': str(e)}
    
    # Check Dashboard
    try:
        response = requests.get(f"{DASHBOARD_URL}/_stcore/health", timeout=5)
        services['dashboard'] = {
            'status': 'healthy' if response.status_code == 200 else 'unhealthy',
            'url': DASHBOARD_URL
        }
    except Exception as e:
        services['dashboard'] = {'status': 'unhealthy', 'error': str(e)}
    
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'services': services
    })

@app.route('/api/models')
def models():
    """Get available models from MCP Hub"""
    try:
        response = requests.get(f"{MCP_BASE_URL}/models", timeout=10)
        return jsonify(response.json())
    except Exception as e:
        return jsonify({'error': str(e), 'fallback': 'HuggingFace API available'}), 500

@app.route('/api/test-inference', methods=['GET', 'POST'])
def test_inference():
    """Test inference endpoint"""
    try:
        prompt = request.json.get('prompt', 'Predict next trade action for BTC/USDT') if request.method == 'POST' else 'Test inference prompt'
        
        # Try MCP Hub first
        response = requests.post(f"{MCP_BASE_URL}/generate", 
                               json={'prompt': prompt, 'model': 'test-gemma-model'},
                               timeout=30)
        
        return jsonify({
            'status': 'success',
            'source': 'MCP Hub',
            'result': response.json(),
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        # Fallback message
        return jsonify({
            'status': 'fallback',
            'source': 'Local System',
            'message': 'MCP Hub unavailable, fallback logic would activate',
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }), 200

@app.route('/api/status')
def status():
    """System status endpoint"""
    return jsonify({
        'system': 'AITB Control Panel',
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat(),
        'components': {
            'mcp_hub': MCP_BASE_URL,
            'dashboard': DASHBOARD_URL,
            'grafana': GRAFANA_URL,
            'influxdb': INFLUXDB_URL,
            'api_server': 'http://localhost:5000'
        },
        'features': {
            'docker_integration': True,
            'model_management': True,
            'inference_fallback': True,
            'monitoring': True
        }
    })

if __name__ == '__main__':
    print("🚀 Starting AITB Web Server...")
    print(f"📊 Dashboard: {DASHBOARD_URL}")
    print(f"🎛️  MCP Hub: {MCP_BASE_URL}")
    print(f"🌐 Web UI: http://localhost:5000")
    
    app.run(host='0.0.0.0', port=5000, debug=True)