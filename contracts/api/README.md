# AITB API Contracts

> **⚠️ MANDATORY REQUIREMENT FOR ALL AGENTS:**  
> **Agents MUST read `/context/project_manifest.yaml` before any action.**

TradingView-aligned API contracts for the AITB trading system.

## Overview

This directory contains JSON schema definitions for all API endpoints, following TradingView broker specification standards. All contracts document field names and types only (no implementation code).

## Contracts

### Market Data

#### `/quotes` - Real-time Quotes
- **File**: `quotes.json`
- **Purpose**: Bid/ask prices with market data
- **Key Fields**: `bid`, `ask`, `bid_size`, `ask_size`, `spread`, `volume`, `timestamp`
- **Status**: Streaming real-time data

#### `/depth` - Level 2 Order Book
- **File**: `depth.json` 
- **Purpose**: L2 order book depth data
- **Key Fields**: `asks[]`, `bids[]`, `timestamp`, `last_update_id`
- **Requirements**: Max 1 second staleness, proper price sorting
- **Format**: Arrays of `[price, volume, count]`

#### `/history` - Historical OHLCV Data
- **File**: `history.json`
- **Purpose**: Historical candlestick data with strict requirements
- **Key Fields**: `t[]`, `o[]`, `h[]`, `l[]`, `c[]`, `v[]` (arrays)
- **Requirements**: 
  - **00:00 UTC Rule**: Daily bars MUST start at 00:00 UTC
  - **Gap Tolerance**: Mismatched bars ≤5% of requested range
  - **Data Quality**: OHLC validation, no future data
- **Resolutions**: 1m, 5m, 15m, 30m, 1h, 4h, 1D, 1W, 1M

### Symbol Information & Access Control

#### `/symbol_info` - Symbol Metadata
- **File**: `symbol_info.json`
- **Purpose**: Symbol specifications and trading rules
- **Key Fields**: `symbol`, `type`, `exchange`, `pricescale`, `minmov`, `session`
- **Supported Types**: crypto, forex, stock, futures, index, bond

#### `/groups` - Symbol Groups
- **File**: `groups.json`
- **Purpose**: Symbol grouping and permission management
- **Key Fields**: `groups[]` with `name`, `symbols[]`, `permissions{}`
- **Examples**: crypto_major, crypto_minor with different access levels

#### `/permissions` - User Access Control
- **File**: `permissions.json`
- **Purpose**: User permissions and trading restrictions
- **Key Fields**: `permissions{}`, `trading_permissions{}`, `restrictions{}`
- **Features**: Position limits, rate limiting, trading hours, blocked symbols

### Trading Operations

#### `/orders` - Order Management
- **File**: `orders.json`
- **Purpose**: Complete order lifecycle with preview capabilities
- **Endpoints**:
  - `POST /orders` - Place order
  - `POST /orders/preview` - Preview order (required)
  - `PUT /orders/{id}` - Modify order
  - `DELETE /orders/{id}` - Cancel order
  - `GET /orders` - List orders
  - `GET /orders/{id}` - Get order details

#### Required Fields for All Orders
- **currentBid**: Best bid price at order time
- **currentAsk**: Best ask price at order time  
- **timestamp**: Order placement time
- **commission**: Fee calculation

#### Order Preview Requirements
Preview endpoints MUST provide:
- Estimated fill price
- Commission calculation
- Total cost breakdown
- Market impact assessment
- Risk warnings and validation errors

## Data Quality Standards

### Real-time Data
- **Latency**: ≤100ms for quotes, ≤1s for depth
- **Accuracy**: Bid ≤ Last ≤ Ask validation
- **Completeness**: No missing required fields

### Historical Data  
- **Gaps**: Maximum 5% missing data tolerance
- **Alignment**: Daily bars at 00:00 UTC sharp
- **Validation**: OHLC relationships, positive volumes
- **Pagination**: Support for large date ranges

### Access Control
- **Authentication**: Required for all trading operations
- **Authorization**: Symbol-level permissions
- **Rate Limiting**: Per-user request throttling
- **Audit Trail**: Complete order history

## TradingView Compatibility

All contracts follow TradingView broker API specification:
- Field naming conventions (`s`, `d`, `t`, `o`, `h`, `l`, `c`, `v`)
- Status codes (`ok`, `no_data`, `error`)
- Error handling with `errmsg` field
- Pagination support with `nextTime`
- Resolution format compatibility

## Implementation Notes

These contracts define the API surface only. Implementation must:

1. **Validate** all inputs according to schema
2. **Enforce** permission checks before data access
3. **Monitor** data quality metrics continuously  
4. **Maintain** audit logs for compliance
5. **Handle** edge cases (market closures, symbol suspension)

## Files Structure

```
contracts/api/
├── README.md              # This file
├── quotes.json            # Real-time bid/ask quotes
├── depth.json             # L2 order book depth  
├── history.json           # Historical OHLCV with UTC rules
├── symbol_info.json       # Symbol metadata
├── groups.json            # Symbol grouping
├── permissions.json       # User access control
└── orders.json           # Order management with preview
```

All contracts are versioned and include comprehensive examples for testing and validation.