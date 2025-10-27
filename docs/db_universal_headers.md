# AITB Database Universal Headers
**Contract-First Database Schema Definition**  
**Episode 6 - DB Universals**  
**Date:** 2025-10-27  

## Overview
This document defines the exact column specifications for all AITB database tables, establishing universal headers that ensure consistency across data ingestion, storage, and retrieval operations. These schemas serve as the single source of truth for all database operations.

---

## Table Schemas

### 1. Candles (OHLCV Data)
**Purpose:** Store candlestick/OHLCV market data for technical analysis  
**Primary Key:** `(symbol, timeframe, timestamp)`  
**Indexes:** `symbol`, `timestamp`, `(symbol, timeframe)`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique record identifier |
| `symbol` | VARCHAR(20) | NOT NULL, INDEX | Trading pair symbol (e.g., 'BTCUSDT') |
| `timeframe` | VARCHAR(10) | NOT NULL | Candlestick interval ('1m', '5m', '1h', '1d') |
| `timestamp` | TIMESTAMP | NOT NULL, INDEX | Candle open time (UTC) |
| `open` | DECIMAL(20,8) | NOT NULL | Opening price |
| `high` | DECIMAL(20,8) | NOT NULL | Highest price |
| `low` | DECIMAL(20,8) | NOT NULL | Lowest price |
| `close` | DECIMAL(20,8) | NOT NULL | Closing price |
| `volume` | DECIMAL(20,8) | NOT NULL | Volume traded in base asset |
| `quote_volume` | DECIMAL(20,8) | NOT NULL | Volume traded in quote asset |
| `trades_count` | INT | NOT NULL | Number of trades in period |
| `taker_buy_volume` | DECIMAL(20,8) | NOT NULL | Taker buy volume (base asset) |
| `taker_buy_quote_volume` | DECIMAL(20,8) | NOT NULL | Taker buy volume (quote asset) |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |
| `updated_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP ON UPDATE | Last update time |

**Sample Row:**
```sql
INSERT INTO candles VALUES (
  1, 'BTCUSDT', '1h', '2025-10-27 00:00:00',
  65000.00, 65250.00, 64800.00, 65100.00,
  125.50, 8175000.00, 1847,
  62.75, 4087500.00,
  '2025-10-27 01:00:00', '2025-10-27 01:00:00'
);
```

---

### 2. Trades (Individual Trade Executions)
**Purpose:** Store individual trade execution records for order flow analysis  
**Primary Key:** `id`  
**Indexes:** `symbol`, `timestamp`, `trade_id`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique record identifier |
| `trade_id` | BIGINT | NOT NULL, UNIQUE | Exchange-specific trade ID |
| `symbol` | VARCHAR(20) | NOT NULL, INDEX | Trading pair symbol |
| `timestamp` | TIMESTAMP(3) | NOT NULL, INDEX | Trade execution time (UTC, millisecond precision) |
| `price` | DECIMAL(20,8) | NOT NULL | Trade execution price |
| `quantity` | DECIMAL(20,8) | NOT NULL | Trade quantity (base asset) |
| `quote_quantity` | DECIMAL(20,8) | NOT NULL | Trade value (quote asset) |
| `is_buyer_maker` | BOOLEAN | NOT NULL | True if buyer is market maker |
| `side` | ENUM('BUY', 'SELL') | NOT NULL | Trade side from perspective |
| `fee` | DECIMAL(20,8) | DEFAULT 0 | Trading fee amount |
| `fee_asset` | VARCHAR(10) | NULL | Asset used for fee payment |
| `order_id` | BIGINT | NULL | Related order ID (if available) |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |

**Sample Row:**
```sql
INSERT INTO trades VALUES (
  1, 123456789, 'BTCUSDT', '2025-10-27 12:34:56.789',
  65000.00, 0.15, 9750.00, true, 'BUY',
  9.75, 'USDT', 987654321, '2025-10-27 12:34:57'
);
```

---

### 3. Orderbook (Market Depth Snapshots)
**Purpose:** Store order book depth snapshots for liquidity analysis  
**Primary Key:** `(symbol, timestamp, side, price_level)`  
**Indexes:** `symbol`, `timestamp`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique record identifier |
| `symbol` | VARCHAR(20) | NOT NULL, INDEX | Trading pair symbol |
| `timestamp` | TIMESTAMP(3) | NOT NULL, INDEX | Snapshot timestamp (UTC) |
| `side` | ENUM('BID', 'ASK') | NOT NULL | Order book side |
| `price_level` | TINYINT | NOT NULL | Depth level (0=best, 19=worst) |
| `price` | DECIMAL(20,8) | NOT NULL | Price level |
| `quantity` | DECIMAL(20,8) | NOT NULL | Aggregate quantity at level |
| `orders_count` | INT | DEFAULT 0 | Number of orders at level |
| `update_id` | BIGINT | NOT NULL | Exchange update sequence ID |
| `spread_bps` | DECIMAL(8,4) | NULL | Spread in basis points (for level 0) |
| `mid_price` | DECIMAL(20,8) | NULL | Mid-market price (for level 0) |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |

**Sample Row:**
```sql
INSERT INTO orderbook VALUES (
  1, 'BTCUSDT', '2025-10-27 12:34:56.789', 'BID', 0,
  64999.50, 2.45, 15, 567890123,
  3.85, 65000.25, '2025-10-27 12:34:57'
);
```

---

### 4. FuturesCtx (Futures Context Data)
**Purpose:** Store futures-specific context including funding rates, open interest  
**Primary Key:** `(symbol, timestamp, context_type)`  
**Indexes:** `symbol`, `timestamp`, `context_type`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique record identifier |
| `symbol` | VARCHAR(20) | NOT NULL, INDEX | Futures contract symbol |
| `timestamp` | TIMESTAMP | NOT NULL, INDEX | Context data timestamp (UTC) |
| `context_type` | ENUM('FUNDING', 'OI', 'MARK_PRICE', 'INDEX_PRICE') | NOT NULL | Data type |
| `funding_rate` | DECIMAL(12,8) | NULL | Current funding rate (for FUNDING) |
| `predicted_rate` | DECIMAL(12,8) | NULL | Predicted next funding rate |
| `funding_time` | TIMESTAMP | NULL | Next funding time |
| `open_interest` | DECIMAL(20,8) | NULL | Open interest value (for OI) |
| `open_interest_usd` | DECIMAL(20,2) | NULL | Open interest in USD |
| `mark_price` | DECIMAL(20,8) | NULL | Mark price (for MARK_PRICE) |
| `index_price` | DECIMAL(20,8) | NULL | Index price (for INDEX_PRICE) |
| `basis_bps` | DECIMAL(8,4) | NULL | Basis in basis points |
| `premium_index` | DECIMAL(12,8) | NULL | Premium index value |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |

**Sample Row:**
```sql
INSERT INTO futures_ctx VALUES (
  1, 'BTCUSDT-PERP', '2025-10-27 12:00:00', 'FUNDING',
  0.00010000, 0.00008500, '2025-10-27 16:00:00',
  125000000.00, 8125000000.00, 65000.50, 65001.25,
  -1.15, 0.00000750, '2025-10-27 12:00:05'
);
```

---

### 5. Liquidations (Forced Position Closures)
**Purpose:** Track liquidation events for risk analysis and market sentiment  
**Primary Key:** `id`  
**Indexes:** `symbol`, `timestamp`, `side`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique record identifier |
| `symbol` | VARCHAR(20) | NOT NULL, INDEX | Liquidated contract symbol |
| `timestamp` | TIMESTAMP(3) | NOT NULL, INDEX | Liquidation timestamp (UTC) |
| `side` | ENUM('LONG', 'SHORT') | NOT NULL, INDEX | Liquidated position side |
| `price` | DECIMAL(20,8) | NOT NULL | Liquidation price |
| `quantity` | DECIMAL(20,8) | NOT NULL | Liquidated quantity |
| `value_usd` | DECIMAL(20,2) | NOT NULL | Liquidation value in USD |
| `leverage` | DECIMAL(4,2) | NULL | Position leverage (if available) |
| `margin_ratio` | DECIMAL(6,4) | NULL | Margin ratio at liquidation |
| `liquidation_fee` | DECIMAL(20,8) | NULL | Liquidation fee charged |
| `insurance_fund` | DECIMAL(20,8) | NULL | Insurance fund contribution |
| `bankruptcy_price` | DECIMAL(20,8) | NULL | Bankruptcy price |
| `exchange` | VARCHAR(20) | NOT NULL | Exchange identifier |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |

**Sample Row:**
```sql
INSERT INTO liquidations VALUES (
  1, 'BTCUSDT-PERP', '2025-10-27 14:23:45.123', 'LONG',
  64500.00, 1.50, 96750.00, 10.00, 0.0250,
  483.75, 0.00, 64000.00, 'BINANCE', '2025-10-27 14:23:46'
);
```

---

### 6. Features (ML Feature Store)
**Purpose:** Store computed features for machine learning models  
**Primary Key:** `(symbol, timestamp, feature_set, feature_name)`  
**Indexes:** `symbol`, `timestamp`, `feature_set`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Unique record identifier |
| `symbol` | VARCHAR(20) | NOT NULL, INDEX | Associated trading symbol |
| `timestamp` | TIMESTAMP | NOT NULL, INDEX | Feature calculation timestamp (UTC) |
| `feature_set` | VARCHAR(50) | NOT NULL, INDEX | Feature group identifier |
| `feature_name` | VARCHAR(100) | NOT NULL | Specific feature name |
| `feature_value` | DECIMAL(20,8) | NOT NULL | Computed feature value |
| `feature_type` | ENUM('TECHNICAL', 'FUNDAMENTAL', 'SENTIMENT', 'RISK', 'MACRO') | NOT NULL | Feature category |
| `timeframe` | VARCHAR(10) | NOT NULL | Feature calculation timeframe |
| `version` | VARCHAR(10) | NOT NULL | Feature calculation version |
| `confidence` | DECIMAL(4,3) | NULL | Feature confidence score (0-1) |
| `metadata` | JSON | NULL | Additional feature metadata |
| `calculation_time_ms` | INT | NULL | Feature calculation duration |
| `dependencies` | TEXT | NULL | Comma-separated dependency list |
| `created_at` | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Record creation time |

**Sample Row:**
```sql
INSERT INTO features VALUES (
  1, 'BTCUSDT', '2025-10-27 12:00:00', 'momentum_indicators', 'rsi_14',
  72.45, 'TECHNICAL', '1h', 'v1.2.0', 0.985,
  '{"period": 14, "source": "close"}', 12, 'candles_1h',
  '2025-10-27 12:00:15'
);
```

---

## Data Retention Policies

### Hot Data (Real-time Access)
**Storage:** Primary database (PostgreSQL/InfluxDB)  
**Performance:** Sub-second query response  

| Table | Retention Period | Rationale |
|-------|------------------|-----------|
| `candles` | 90 days (1m,5m), 1 year (1h,1d) | Active trading analysis |
| `trades` | 30 days | Order flow analysis |
| `orderbook` | 7 days | Recent liquidity patterns |
| `futures_ctx` | 90 days | Funding rate trends |
| `liquidations` | 180 days | Risk analysis history |
| `features` | 30 days | Model inference data |

### Warm Data (Historical Analysis)
**Storage:** Compressed database partitions  
**Performance:** 1-10 second query response  

| Table | Retention Period | Compression |
|-------|------------------|-------------|
| `candles` | 2 years (1h,1d) | 85% compression |
| `trades` | 1 year | 90% compression |
| `futures_ctx` | 1 year | 80% compression |
| `liquidations` | 2 years | 85% compression |
| `features` | 6 months | 75% compression |

### Cold Data (Archive Storage)
**Storage:** Parquet files on filesystem  
**Performance:** 10-60 second query response  

All tables: **Indefinite retention** in daily parquet exports

---

## Daily Parquet Export Paths

### Directory Structure
```
D:\docker\archives\parquet\
├── candles\
│   ├── 2025-10-27\
│   │   ├── BTCUSDT_1m_2025-10-27.parquet
│   │   ├── BTCUSDT_5m_2025-10-27.parquet
│   │   ├── BTCUSDT_1h_2025-10-27.parquet
│   │   └── BTCUSDT_1d_2025-10-27.parquet
│   └── 2025-10-28\
│       └── ...
├── trades\
│   ├── 2025-10-27\
│   │   ├── BTCUSDT_trades_2025-10-27_00.parquet (hourly splits)
│   │   ├── BTCUSDT_trades_2025-10-27_01.parquet
│   │   └── ...
│   └── 2025-10-28\
│       └── ...
├── orderbook\
│   ├── 2025-10-27\
│   │   ├── BTCUSDT_orderbook_2025-10-27_00.parquet
│   │   └── ...
│   └── 2025-10-28\
│       └── ...
├── futures_ctx\
│   ├── 2025-10-27\
│   │   ├── BTCUSDT-PERP_funding_2025-10-27.parquet
│   │   ├── BTCUSDT-PERP_oi_2025-10-27.parquet
│   │   └── ...
│   └── 2025-10-28\
│       └── ...
├── liquidations\
│   ├── 2025-10-27\
│   │   ├── liquidations_2025-10-27.parquet
│   │   └── ...
│   └── 2025-10-28\
│       └── ...
└── features\
    ├── 2025-10-27\
    │   ├── BTCUSDT_technical_2025-10-27.parquet
    │   ├── BTCUSDT_sentiment_2025-10-27.parquet
    │   └── ...
    └── 2025-10-28\
        └── ...
```

### Export Naming Conventions

**Candles:**
- Pattern: `{SYMBOL}_{TIMEFRAME}_{YYYY-MM-DD}.parquet`
- Example: `BTCUSDT_1h_2025-10-27.parquet`

**Trades:**
- Pattern: `{SYMBOL}_trades_{YYYY-MM-DD}_{HH}.parquet`
- Example: `BTCUSDT_trades_2025-10-27_14.parquet`
- Split: Hourly files for high-volume symbols

**Orderbook:**
- Pattern: `{SYMBOL}_orderbook_{YYYY-MM-DD}_{HH}.parquet`
- Example: `ETHUSDT_orderbook_2025-10-27_09.parquet`
- Split: Hourly files due to high frequency

**Futures Context:**
- Pattern: `{SYMBOL}_{CONTEXT_TYPE}_{YYYY-MM-DD}.parquet`
- Example: `BTCUSDT-PERP_funding_2025-10-27.parquet`

**Liquidations:**
- Pattern: `liquidations_{YYYY-MM-DD}.parquet`
- Example: `liquidations_2025-10-27.parquet`
- Note: All symbols combined daily

**Features:**
- Pattern: `{SYMBOL}_{FEATURE_TYPE}_{YYYY-MM-DD}.parquet`
- Example: `BTCUSDT_technical_2025-10-27.parquet`

### Export Automation

**Daily Export Schedule:**
- **Time:** 02:00 UTC (off-peak hours)
- **Trigger:** Cron job in AITB system
- **Process:** Automated SQL → Parquet conversion
- **Validation:** Row count and schema verification
- **Notification:** Success/failure alerts via Telegram

**Compression Settings:**
- **Algorithm:** Snappy (balanced speed/compression)
- **Row Group Size:** 100,000 rows
- **Page Size:** 1MB
- **Dictionary Encoding:** Enabled for string columns
- **Expected Compression:** 70-85% depending on table

**Metadata Preservation:**
- Schema version in parquet metadata
- Export timestamp and source database
- Data quality metrics (null counts, min/max values)
- Source table row count for validation

---

## Implementation Notes

### Database Engine Compatibility
- **Primary:** PostgreSQL 14+ with TimescaleDB extension
- **Alternative:** InfluxDB 2.x for time-series data
- **Compatibility:** Schema designed for both engines

### Data Types Mapping
```sql
-- PostgreSQL Types
DECIMAL(20,8) → NUMERIC(20,8)
TIMESTAMP(3) → TIMESTAMP WITH TIME ZONE
ENUM → CUSTOM TYPE or VARCHAR with CHECK constraint
JSON → JSONB for better performance

-- InfluxDB Types  
DECIMAL → FLOAT64
TIMESTAMP → TIME (nanosecond precision)
ENUM → TAG values
JSON → FIELD (JSON string)
```

### Indexing Strategy
```sql
-- Composite indexes for query optimization
CREATE INDEX idx_candles_symbol_timeframe_ts ON candles (symbol, timeframe, timestamp);
CREATE INDEX idx_trades_symbol_ts ON trades (symbol, timestamp);
CREATE INDEX idx_orderbook_symbol_ts_side ON orderbook (symbol, timestamp, side);
CREATE INDEX idx_futures_ctx_symbol_type_ts ON futures_ctx (symbol, context_type, timestamp);
CREATE INDEX idx_liquidations_ts_value ON liquidations (timestamp, value_usd);
CREATE INDEX idx_features_symbol_set_ts ON features (symbol, feature_set, timestamp);
```

### Data Quality Constraints
```sql
-- Price validation
ALTER TABLE candles ADD CONSTRAINT chk_candles_prices 
  CHECK (low <= open AND low <= close AND low <= high 
         AND high >= open AND high >= close);

-- Volume validation  
ALTER TABLE trades ADD CONSTRAINT chk_trades_volume
  CHECK (quantity > 0 AND price > 0);

-- Timestamp validation
ALTER TABLE orderbook ADD CONSTRAINT chk_orderbook_future
  CHECK (timestamp <= CURRENT_TIMESTAMP + INTERVAL '1 hour');
```

---

## Contract Compliance

This document establishes the **contract-first** approach for AITB database operations:

1. **No Schema Migrations:** These schemas are immutable contracts
2. **Additive Changes Only:** New columns may be added, existing never modified
3. **Version Control:** All schema changes tracked in git
4. **Documentation First:** Implementation follows documentation
5. **Cross-Team Agreement:** Changes require consensus across trading, ML, and data teams

**Next Phase:** Episode 7 will implement these schemas with full migration scripts and validation procedures.

---

*Document Version: 1.0*  
*Last Updated: 2025-10-27*  
*Status: Contract Approved - Ready for Implementation*