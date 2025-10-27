#!/usr/bin/env python3
"""
AITB Data Adapter - Live Price & Backfill Service
FastAPI-based data layer with Binance fallback for price feeds and historical data
"""

import asyncio
import json
import time
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Any
import logging

import requests
import pandas as pd
from fastapi import FastAPI, HTTPException, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('D:/logs/aitb/dashboard/data_adapter.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
INFLUXDB_URL = "http://localhost:8086"
INFLUXDB_TOKEN = "S8mcIaAj6RaWtAorE74GBFlVqc9izBaMcwB29y3H5IKBbVSt5ytG-z64kVmDqkrO-kp3_vXQ2NrqjE734Cazxw=="
INFLUXDB_ORG = "aitb"
INFLUXDB_BUCKET = "aitb"

BINANCE_BASE_URL = "https://api.binance.com/api/v3"

# FastAPI app
app = FastAPI(
    title="AITB Data Adapter",
    description="Live Price & Backfill Service with Binance Integration",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class PriceResponse(BaseModel):
    symbol: str
    price: float
    timestamp: str
    source: str  # "influx" or "binance"

class MarketData(BaseModel):
    symbol: str
    lastPrice: float
    priceChange: float
    priceChangePercent: float
    volume: float
    timestamp: str

class MarketsResponse(BaseModel):
    markets: List[MarketData]
    timestamp: str
    count: int

class BackfillRequest(BaseModel):
    symbol: str = Field(..., description="Trading pair symbol (e.g., BTCUSDT)")
    interval: str = Field(default="1m", description="Kline interval (1m, 5m, 1h, 1d)")
    limit: int = Field(default=500, description="Number of candles to fetch")

class BackfillResponse(BaseModel):
    symbol: str
    interval: str
    candlesWritten: int
    status: str
    message: str

# Bot Control models
class BotControlRequest(BaseModel):
    action: str = Field(..., description="Action to perform: start, pause, stop")
    symbol: Optional[str] = Field("BTCUSDT", description="Trading symbol")
    tf: Optional[str] = Field("15m", description="Timeframe")

class BotSignal(BaseModel):
    timestamp: str
    signal: str  # "buy", "sell", "hold"
    confidence: float
    symbol: str
    price: float
    reason: str

class BotStatus(BaseModel):
    state: str  # "stopped", "running", "paused"
    lastHeartbeatTs: str
    currentSymbol: str
    tf: str
    openPositions: List[Dict[str, Any]]
    pnl: float
    lastSignals: List[BotSignal]

class BotHeartbeat(BaseModel):
    timestamp: str
    state: str
    symbol: str
    tf: str
    lastSignal: Optional[BotSignal] = None
    openPositions: List[Dict[str, Any]] = []
    pnl: float = 0.0

class BotManager:
    """Bot state and control management"""
    
    def __init__(self):
        self.state = "stopped"  # stopped, running, paused
        self.current_symbol = "BTCUSDT"
        self.current_tf = "15m"
        self.last_heartbeat = datetime.now(timezone.utc)
        self.open_positions = []
        self.pnl = 0.0
        self.last_signals = []
        
    def update_heartbeat(self, heartbeat: BotHeartbeat):
        """Update bot status from heartbeat"""
        self.last_heartbeat = datetime.now(timezone.utc)
        self.state = heartbeat.state
        self.current_symbol = heartbeat.symbol
        self.current_tf = heartbeat.tf
        self.open_positions = heartbeat.openPositions
        self.pnl = heartbeat.pnl
        
        # Add new signal to history (keep last 3)
        if heartbeat.lastSignal:
            self.last_signals.insert(0, heartbeat.lastSignal)
            self.last_signals = self.last_signals[:3]
    
    def set_state(self, action: str, symbol: str = None, tf: str = None):
        """Update bot state based on control action"""
        if action == "start":
            self.state = "running"
        elif action == "pause":
            self.state = "paused"
        elif action == "stop":
            self.state = "stopped"
            self.open_positions = []
            
        if symbol:
            self.current_symbol = symbol
        if tf:
            self.current_tf = tf
    
    def get_status(self) -> BotStatus:
        """Get current bot status"""
        return BotStatus(
            state=self.state,
            lastHeartbeatTs=self.last_heartbeat.isoformat(),
            currentSymbol=self.current_symbol,
            tf=self.current_tf,
            openPositions=self.open_positions,
            pnl=self.pnl,
            lastSignals=self.last_signals
        )
    
    def is_heartbeat_stale(self, max_age_seconds: int = 60) -> bool:
        """Check if last heartbeat is stale"""
        age = (datetime.now(timezone.utc) - self.last_heartbeat).total_seconds()
        return age > max_age_seconds

class DataAdapter:
    """Data adapter with InfluxDB and Binance integration"""
    
    def __init__(self):
        self.influx_client = None
        self.write_api = None
        self.session = requests.Session()
        self.init_influxdb()
        
        # Popular trading pairs for markets endpoint
        self.default_symbols = [
            "BTCUSDT", "ETHUSDT", "BNBUSDT", "XRPUSDT", "SOLUSDT",
            "ADAUSDT", "DOGEUSDT", "AVAXUSDT", "DOTUSDT", "MATICUSDT",
            "LINKUSDT", "ATOMUSDT", "LTCUSDT", "UNIUSDT", "ETCUSDT",
            "FILUSDT", "TRXUSDT", "ALGOUSDT", "XLMUSDT", "VETUSDT"
        ]
    
    def init_influxdb(self):
        """Initialize InfluxDB connection"""
        try:
            self.influx_client = InfluxDBClient(
                url=INFLUXDB_URL,
                token=INFLUXDB_TOKEN,
                org=INFLUXDB_ORG
            )
            self.write_api = self.influx_client.write_api(write_options=SYNCHRONOUS)
            logger.info("Connected to InfluxDB successfully")
        except Exception as e:
            logger.error(f"Failed to connect to InfluxDB: {e}")
    
    async def get_latest_price_from_influx(self, symbol: str) -> Optional[Dict[str, Any]]:
        """Get latest price from InfluxDB for a symbol"""
        if not self.influx_client:
            return None
        
        try:
            query = f'''
            from(bucket: "{INFLUXDB_BUCKET}")
            |> range(start: -1h)
            |> filter(fn: (r) => r._measurement == "prices")
            |> filter(fn: (r) => r.symbol == "{symbol}")
            |> filter(fn: (r) => r._field == "price")
            |> last()
            '''
            
            query_api = self.influx_client.query_api()
            result = query_api.query(query)
            
            for table in result:
                for row in table.records:
                    return {
                        "symbol": symbol,
                        "price": float(row.get_value()),
                        "timestamp": row.get_time().isoformat(),
                        "source": "influx"
                    }
            
            return None
        except Exception as e:
            logger.warning(f"Error querying InfluxDB for {symbol}: {e}")
            return None
    
    async def get_price_from_binance(self, symbol: str) -> Optional[Dict[str, Any]]:
        """Get current price from Binance REST API"""
        try:
            response = self.session.get(
                f"{BINANCE_BASE_URL}/ticker/price",
                params={"symbol": symbol},
                timeout=5
            )
            response.raise_for_status()
            
            data = response.json()
            return {
                "symbol": data["symbol"],
                "price": float(data["price"]),
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "source": "binance"
            }
        except Exception as e:
            logger.error(f"Error fetching price from Binance for {symbol}: {e}")
            return None
    
    async def get_markets_from_binance(self, symbols: List[str]) -> List[Dict[str, Any]]:
        """Get 24hr ticker data for multiple symbols from Binance"""
        try:
            # Get all tickers in one request for efficiency
            response = self.session.get(
                f"{BINANCE_BASE_URL}/ticker/24hr",
                timeout=10
            )
            response.raise_for_status()
            
            all_tickers = response.json()
            
            # Filter to our symbols
            markets = []
            for ticker in all_tickers:
                if ticker["symbol"] in symbols:
                    markets.append({
                        "symbol": ticker["symbol"],
                        "lastPrice": float(ticker["lastPrice"]),
                        "priceChange": float(ticker["priceChange"]),
                        "priceChangePercent": float(ticker["priceChangePercent"]),
                        "volume": float(ticker["volume"]),
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    })
            
            # Sort by volume (highest first)
            markets.sort(key=lambda x: x["volume"], reverse=True)
            
            return markets[:20]  # Return top 20 by volume
            
        except Exception as e:
            logger.error(f"Error fetching markets from Binance: {e}")
            return []
    
    async def get_candles_from_binance(self, symbol: str, interval: str, limit: int) -> List[Dict[str, Any]]:
        """Get historical candle data from Binance"""
        try:
            response = self.session.get(
                f"{BINANCE_BASE_URL}/klines",
                params={
                    "symbol": symbol,
                    "interval": interval,
                    "limit": limit
                },
                timeout=30
            )
            response.raise_for_status()
            
            klines = response.json()
            candles = []
            
            for kline in klines:
                candles.append({
                    "timestamp": int(kline[0]) // 1000,  # Convert to seconds
                    "open": float(kline[1]),
                    "high": float(kline[2]),
                    "low": float(kline[3]),
                    "close": float(kline[4]),
                    "volume": float(kline[5]),
                    "symbol": symbol,
                    "timeframe": interval
                })
            
            return candles
            
        except Exception as e:
            logger.error(f"Error fetching candles from Binance for {symbol}: {e}")
            return []
    
    async def write_candles_to_influx(self, candles: List[Dict[str, Any]]) -> int:
        """Write candle data to InfluxDB following universal headers format"""
        if not self.write_api or not candles:
            return 0
        
        try:
            points = []
            for candle in candles:
                timestamp = datetime.fromtimestamp(candle["timestamp"], tz=timezone.utc)
                
                point = Point("candles") \
                    .tag("symbol", candle["symbol"]) \
                    .tag("timeframe", candle["timeframe"]) \
                    .field("open", candle["open"]) \
                    .field("high", candle["high"]) \
                    .field("low", candle["low"]) \
                    .field("close", candle["close"]) \
                    .field("volume", candle["volume"]) \
                    .time(timestamp, WritePrecision.S)
                
                points.append(point)
            
            self.write_api.write(bucket=INFLUXDB_BUCKET, record=points)
            logger.info(f"Written {len(points)} candles to InfluxDB")
            return len(points)
            
        except Exception as e:
            logger.error(f"Error writing candles to InfluxDB: {e}")
            return 0
    
    async def check_influx_candle_count(self, symbol: str, interval: str, hours: int = 24) -> int:
        """Check how many candles exist in InfluxDB for a symbol/interval"""
        if not self.influx_client:
            return 0
        
        try:
            query = f'''
            from(bucket: "{INFLUXDB_BUCKET}")
            |> range(start: -{hours}h)
            |> filter(fn: (r) => r._measurement == "candles")
            |> filter(fn: (r) => r.symbol == "{symbol}")
            |> filter(fn: (r) => r.timeframe == "{interval}")
            |> filter(fn: (r) => r._field == "close")
            |> count()
            '''
            
            query_api = self.influx_client.query_api()
            result = query_api.query(query)
            
            for table in result:
                for row in table.records:
                    return int(row.get_value())
            
            return 0
        except Exception as e:
            logger.warning(f"Error checking candle count in InfluxDB: {e}")
            return 0
    
    async def get_candles_from_influx(self, symbol: str, interval: str, limit: int) -> List[Dict[str, Any]]:
        """Get candle data from InfluxDB"""
        if not self.influx_client:
            return []
        
        try:
            # Query for candle data from the last 7 days, then limit results
            query = f'''
            from(bucket: "{INFLUXDB_BUCKET}")
            |> range(start: -7d)
            |> filter(fn: (r) => r._measurement == "candles")
            |> filter(fn: (r) => r.symbol == "{symbol}")
            |> filter(fn: (r) => r.timeframe == "{interval}")
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            |> sort(columns: ["_time"], desc: false)
            |> tail(n: {limit})
            '''
            
            query_api = self.influx_client.query_api()
            result = query_api.query(query)
            
            candles = []
            for table in result:
                for row in table.records:
                    candles.append({
                        "timestamp": int(row["_time"].timestamp()),
                        "open": float(row.get("open", 0)),
                        "high": float(row.get("high", 0)),
                        "low": float(row.get("low", 0)),
                        "close": float(row.get("close", 0)),
                        "volume": float(row.get("volume", 0)),
                        "symbol": symbol,
                        "timeframe": interval
                    })
            
            logger.info(f"Retrieved {len(candles)} candles from InfluxDB for {symbol} {interval}")
            return candles
            
        except Exception as e:
            logger.warning(f"Error retrieving candles from InfluxDB for {symbol} {interval}: {e}")
            return []

# Initialize data adapter
data_adapter = DataAdapter()

# Initialize bot manager
bot_manager = BotManager()

# API Endpoints
@app.get("/data/price", response_model=PriceResponse)
async def get_price(symbol: str = Query(..., description="Trading pair symbol (e.g., BTCUSDT)")):
    """Get current price for a symbol with InfluxDB fallback to Binance"""
    try:
        # First try InfluxDB
        influx_price = await data_adapter.get_latest_price_from_influx(symbol)
        
        # Check if InfluxDB price is recent (within 5 minutes)
        if influx_price:
            price_time = datetime.fromisoformat(influx_price["timestamp"].replace('Z', '+00:00'))
            age_seconds = (datetime.now(timezone.utc) - price_time).total_seconds()
            
            if age_seconds <= 300:  # 5 minutes
                return PriceResponse(**influx_price)
        
        # Fallback to Binance
        binance_price = await data_adapter.get_price_from_binance(symbol)
        if not binance_price:
            raise HTTPException(status_code=404, detail=f"Price not found for symbol {symbol}")
        
        return PriceResponse(**binance_price)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_price for {symbol}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/data/markets", response_model=MarketsResponse)
async def get_markets():
    """Get 20 symbols with live prices and 24h change from Binance"""
    try:
        markets = await data_adapter.get_markets_from_binance(data_adapter.default_symbols)
        
        if not markets:
            raise HTTPException(status_code=503, detail="Unable to fetch market data")
        
        return MarketsResponse(
            markets=[MarketData(**market) for market in markets],
            timestamp=datetime.now(timezone.utc).isoformat(),
            count=len(markets)
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_markets: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/chart/candles")
async def get_chart_candles(
    symbol: str = Query("BTCUSDT", description="Trading symbol"),
    interval: str = Query("1m", description="Timeframe interval"),
    limit: int = Query(500, description="Number of candles to retrieve", le=1000)
):
    """Get candle data for chart display with InfluxDB fallback to Binance"""
    try:
        # First try to get from InfluxDB
        candles = await data_adapter.get_candles_from_influx(symbol, interval, limit)
        
        if candles and len(candles) >= min(50, limit // 2):
            # Sufficient data in InfluxDB, return it
            return {
                "candles": candles,
                "symbol": symbol,
                "interval": interval,
                "count": len(candles),
                "source": "influxdb"
            }
        
        # Not enough data in InfluxDB, get from Binance and optionally store
        logger.info(f"Insufficient InfluxDB data for {symbol} {interval}, fetching from Binance")
        candles = await data_adapter.get_candles_from_binance(symbol, interval, limit)
        
        if candles:
            # Optionally write to InfluxDB in background for future requests
            try:
                await data_adapter.write_candles_to_influx(candles)
                logger.info(f"Stored {len(candles)} candles in InfluxDB for future use")
            except Exception as e:
                logger.warning(f"Failed to store candles in InfluxDB: {e}")
            
            return {
                "candles": candles,
                "symbol": symbol, 
                "interval": interval,
                "count": len(candles),
                "source": "binance"
            }
        
        raise HTTPException(status_code=404, detail=f"No candle data available for {symbol} {interval}")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_chart_candles: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/data/backfill-candles", response_model=BackfillResponse)
async def backfill_candles(request: BackfillRequest, background_tasks: BackgroundTasks):
    """Backfill candle data from Binance to InfluxDB if insufficient data exists"""
    try:
        # Check current candle count in InfluxDB
        current_count = await data_adapter.check_influx_candle_count(
            request.symbol, 
            request.interval
        )
        
        # Determine if backfill is needed (threshold: 100 candles)
        threshold = 100
        if current_count >= threshold:
            return BackfillResponse(
                symbol=request.symbol,
                interval=request.interval,
                candlesWritten=0,
                status="skipped",
                message=f"Sufficient data exists ({current_count} candles >= {threshold})"
            )
        
        # Fetch candles from Binance
        candles = await data_adapter.get_candles_from_binance(
            request.symbol,
            request.interval,
            request.limit
        )
        
        if not candles:
            return BackfillResponse(
                symbol=request.symbol,
                interval=request.interval,
                candlesWritten=0,
                status="failed",
                message="No candle data available from Binance"
            )
        
        # Write to InfluxDB
        written_count = await data_adapter.write_candles_to_influx(candles)
        
        return BackfillResponse(
            symbol=request.symbol,
            interval=request.interval,
            candlesWritten=written_count,
            status="success",
            message=f"Successfully backfilled {written_count} candles"
        )
        
    except Exception as e:
        logger.error(f"Error in backfill_candles: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Bot Control Endpoints
@app.post("/bot/control")
async def bot_control(request: BotControlRequest):
    """Control bot state (start/pause/stop)"""
    try:
        logger.info(f"Bot control request: {request.action} for {request.symbol} {request.tf}")
        
        # Validate action
        if request.action not in ["start", "pause", "stop"]:
            raise HTTPException(status_code=400, detail=f"Invalid action: {request.action}")
        
        # Update bot state
        bot_manager.set_state(request.action, request.symbol, request.tf)
        
        # Log state change
        logger.info(f"Bot state changed to: {bot_manager.state} (symbol: {bot_manager.current_symbol}, tf: {bot_manager.current_tf})")
        
        return {
            "status": "success",
            "message": f"Bot {request.action} command executed",
            "newState": bot_manager.state,
            "symbol": bot_manager.current_symbol,
            "tf": bot_manager.current_tf,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in bot_control: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/bot/status", response_model=BotStatus)
async def bot_status():
    """Get current bot status"""
    try:
        status = bot_manager.get_status()
        
        # Check if heartbeat is stale
        if bot_manager.is_heartbeat_stale() and bot_manager.state == "running":
            logger.warning("Bot heartbeat is stale, marking as disconnected")
            bot_manager.state = "disconnected"
            status.state = "disconnected"
        
        return status
        
    except Exception as e:
        logger.error(f"Error in bot_status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/bot/heartbeat")
async def bot_heartbeat(heartbeat: BotHeartbeat):
    """Receive heartbeat from bot worker"""
    try:
        logger.debug(f"Received bot heartbeat: state={heartbeat.state}, symbol={heartbeat.symbol}")
        
        # Update bot manager with heartbeat data
        bot_manager.update_heartbeat(heartbeat)
        
        return {
            "status": "success",
            "message": "Heartbeat received",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error in bot_heartbeat: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "data_adapter",
        "influxdb_connected": data_adapter.influx_client is not None
    }

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "AITB Data Adapter",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "endpoints": {
            "price": "/data/price?symbol=BTCUSDT",
            "markets": "/data/markets",
            "backfill": "/data/backfill-candles",
            "chart_candles": "/chart/candles?symbol=BTCUSDT&interval=1m&limit=100",
            "bot_control": "/bot/control (POST)",
            "bot_status": "/bot/status",
            "bot_heartbeat": "/bot/heartbeat (POST)",
            "health": "/health",
            "docs": "/docs"
        }
    }

if __name__ == "__main__":
    # Create logs directory if it doesn't exist
    import os
    os.makedirs("D:/logs/aitb/dashboard", exist_ok=True)
    
    # Run the FastAPI server
    uvicorn.run(
        "data_adapter:app",
        host="0.0.0.0",
        port=8502,  # Use port 8502 to avoid conflict with Streamlit on 8501
        reload=False,
        workers=1,
        log_level="info"
    )