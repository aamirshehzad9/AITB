# AITB Host Agent - Handshake System

## Overview

The AITB Host agent (192.168.1.2) implements a secure handshake protocol to establish communication with GOmini-AI (192.168.1.4). This system enables automated node discovery and verification between AI systems.

## Architecture

### AITB Host Configuration
- **Node Name**: AITB
- **IP Address**: 192.168.1.2
- **Port**: 8505
- **Primary Endpoint**: `http://192.168.1.2:8505/handshake/init`

### GOmini-AI Configuration
- **Node Name**: GOmini-AI
- **IP Address**: 192.168.1.4
- **Port**: 8505
- **Verification Endpoint**: `http://192.168.1.4:8505/handshake/verify`

## Handshake Protocol

### 1. Initialization Request (GOmini-AI → AITB)

**Endpoint**: `POST http://192.168.1.2:8505/handshake/init`

**Request Payload**:
```json
{
  "node": "GOmini-AI",
  "ip": "192.168.1.4",
  "timestamp": "2025-10-25T12:00:00.000Z"
}
```

**Response Payload**:
```json
{
  "token": "uuid4-generated-token",
  "status": "linked"
}
```

### 2. Reverse Verification (AITB → GOmini-AI)

**Endpoint**: `POST http://192.168.1.4:8505/handshake/verify`

**Request Payload**:
```json
{
  "node": "AITB",
  "ip": "192.168.1.2",
  "token": "uuid4-generated-token",
  "timestamp": "2025-10-25T12:00:01.000Z"
}
```

**Expected Response**:
```json
{
  "status": "verified",
  "node": "GOmini-AI",
  "ip": "192.168.1.4",
  "token": "uuid4-generated-token",
  "timestamp": "2025-10-25T12:00:02.000Z"
}
```

## Security Features

### 1. IP Address Validation
- Only accepts handshake requests from `192.168.1.4`
- Validates source IP against expected GOmini-AI address

### 2. Node Name Verification
- Validates node name must be exactly "GOmini-AI"
- Prevents unauthorized nodes from establishing connections

### 3. Token-Based Authentication
- Generates unique UUID4 tokens for each handshake session
- Tokens are used for reverse verification
- Tokens are stored securely in logs for audit trail

## Data Storage

### Handshake Token Storage
**Location**: `D:\AITB\logs\gomini_handshake_token.json`

**Structure**:
```json
{
  "token": "uuid4-generated-token",
  "status": "linked",
  "fromNode": "GOmini-AI",
  "fromIP": "192.168.1.4",
  "toNode": "AITB",
  "toIP": "192.168.1.2",
  "timestamp": "2025-10-25T12:00:00.000Z",
  "requestTimestamp": "2025-10-25T12:00:00.000Z",
  "verificationStatus": "success",
  "verificationTimestamp": "2025-10-25T12:00:02.000Z",
  "verificationResponse": {
    "status": "verified",
    "node": "GOmini-AI",
    "ip": "192.168.1.4",
    "token": "uuid4-generated-token",
    "timestamp": "2025-10-25T12:00:02.000Z"
  }
}
```

### Activity Logging
**Location**: `D:\AITB\logs\activity_log.md`

**Format**:
```markdown
## 2025-10-25T12:00:02.000Z
[✓] Linked with GOmini-AI (192.168.1.4) successfully.
- Token: uuid4-generated-token
- Verification: Completed
```

## API Endpoints

### GET /handshake/status
Returns current handshake status and configuration.

**Response**:
```json
{
  "status": "active",
  "handshake": {
    "token": "uuid4-generated-token",
    "status": "linked",
    "fromNode": "GOmini-AI",
    "fromIP": "192.168.1.4",
    "verificationStatus": "success"
  },
  "node": {
    "node": "AITB",
    "ip": "192.168.1.2",
    "port": 8505
  }
}
```

### POST /handshake/init
Handles incoming handshake initialization requests from GOmini-AI.

## Error Handling

### Validation Errors
- **400 Bad Request**: Missing required fields (node, ip)
- **401 Unauthorized**: Invalid node name or IP address
- **500 Internal Server Error**: Token storage or processing failures

### Verification Errors
- Network timeouts (10 second timeout)
- Connection refused from GOmini-AI
- Invalid response format
- HTTP status code errors

## Installation and Startup

### Prerequisites
- Node.js 18+ installed
- Network connectivity between 192.168.1.2 and 192.168.1.4
- PowerShell execution policy allowing script execution

### Installation
```powershell
# Navigate to API service directory
cd D:\AITB\services\api

# Install dependencies
npm install
```

### Startup
```powershell
# Start AITB Host agent
D:\AITB\scripts\start-aitb-host.ps1
```

## Testing

### Manual Testing
```powershell
# Test handshake functionality
D:\AITB\scripts\test-handshake.ps1
```

### Mock GOmini-AI Server
```powershell
# Start mock verification server for testing
D:\AITB\scripts\mock-gomini-server.ps1
```

## Logging and Monitoring

### Log Levels
- **INFO**: Normal handshake operations, successful connections
- **WARN**: Validation failures, unexpected responses
- **ERROR**: Network errors, system failures

### Log Locations
- **Application Logs**: Winston logger output
- **Activity Log**: `D:\AITB\logs\activity_log.md`
- **Handshake Tokens**: `D:\AITB\logs\gomini_handshake_token.json`

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Verify AITB Host is running on port 8505
   - Check firewall settings for port 8505
   - Confirm IP address configuration

2. **Invalid Node/IP Errors**
   - Verify GOmini-AI is sending correct node name
   - Check IP address in request payload
   - Validate network routing between nodes

3. **Token Storage Errors**
   - Ensure `D:\AITB\logs` directory exists
   - Check file permissions for log directory
   - Verify disk space availability

4. **Reverse Verification Failures**
   - Confirm GOmini-AI verification endpoint is available
   - Check network connectivity to 192.168.1.4:8505
   - Verify GOmini-AI is handling `/handshake/verify` endpoint

### Debug Commands
```powershell
# Check if AITB Host is listening
netstat -an | findstr ":8505"

# Test connectivity to GOmini-AI
Test-NetConnection -ComputerName 192.168.1.4 -Port 8505

# Check handshake status
Invoke-RestMethod -Uri "http://192.168.1.2:8505/handshake/status"
```

## Future Enhancements

1. **GitHub Integration**
   - Automatic roadmap updates
   - Log synchronization to repository
   - Issue creation for failed handshakes

2. **Enhanced Security**
   - Certificate-based authentication
   - Encrypted token exchange
   - Rate limiting for handshake attempts

3. **Monitoring Integration**
   - Grafana dashboard metrics
   - InfluxDB time-series data
   - Alert notifications for failures

4. **High Availability**
   - Redundant handshake endpoints
   - Failover mechanisms
   - Health check integration