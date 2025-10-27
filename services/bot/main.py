"""
AITB Trading Bot - Main Application
AI-powered cryptocurrency trading bot with multi-model ensemble predictions
"""

import os
import sys
import asyncio
import logging
import json
import time
import signal
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass

import pandas as pd
import numpy as np
import ccxt
import requests
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS
import sqlite3
import duckdb
from telegram import Bot
from telegram.error import TelegramError
import schedule
import psutil

# Configure logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
@dataclass
class Config:
    """Trading bot configuration"""
    # API Keys
    coinapi_key: str = os.getenv('COINAPI_KEY', '')
    coinmarketcap_key: str = os.getenv('COINMARKETCAP_KEY', '')
    telegram_token: str = os.getenv('TG_BOT_TOKEN', '')
    telegram_chat_id: str = os.getenv('TG_CHAT_ID', '')
    
    # Database paths
    database_path: str = os.getenv('DATABASE_PATH', '/app/data/db')
    models_path: str = os.getenv('MODELS_PATH', '/app/data/models')
    
    # Services
    inference_url: str = os.getenv('INFERENCE_URL', 'http://inference:8001')
    influx_url: str = os.getenv('INFLUX_URL', 'http://influxdb:8086')
    influx_token: str = os.getenv('INFLUX_TOKEN', '')
    influx_org: str = os.getenv('INFLUX_ORG', 'aitb-org')
    influx_bucket: str = os.getenv('INFLUX_BUCKET', 'aitb')
    
    # Trading settings
    trading_pairs: List[str] = None
    max_position_size: float = float(os.getenv('MAX_POSITION_SIZE', '0.02'))
    stop_loss_pct: float = float(os.getenv('STOP_LOSS_PCT', '0.05'))
    take_profit_pct: float = float(os.getenv('TAKE_PROFIT_PCT', '0.15'))
    trading_mode: str = os.getenv('TRADING_MODE', 'paper')
    
    # AI Models
    active_models: List[str] = None
    min_accuracy: float = float(os.getenv('MIN_ACCURACY', '0.65'))
    min_sharpe_ratio: float = float(os.getenv('MIN_SHARPE_RATIO', '1.5'))
    
    def __post_init__(self):
        if self.trading_pairs is None:
            pairs_str = os.getenv('TRADING_PAIRS', 'BTC/USDT,ETH/USDT,ADA/USDT,DOT/USDT')
            self.trading_pairs = [pair.strip() for pair in pairs_str.split(',')]
        
        if self.active_models is None:
            models_str = os.getenv('ACTIVE_MODELS', 'qwen-2b,gemma-2b,mistral-7b')
            self.active_models = [model.strip() for model in models_str.split(',')]

# Initialize configuration
config = Config()

# Initialize FastAPI app for bot API
app = FastAPI(
    title="AITB Trading Bot",
    description="AI-Powered Cryptocurrency Trading Bot",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables
bot_instance = None
is_running = False
trading_session = {}

class DatabaseManager:
    """Manages SQLite and DuckDB connections"""
    
    def __init__(self):
        self.sqlite_path = os.path.join(config.database_path, 'trades.sqlite')
        self.duckdb_path = os.path.join(config.database_path, 'metrics.duckdb')
        self.setup_databases()
    
    def setup_databases(self):
        """Initialize database schemas"""
        os.makedirs(config.database_path, exist_ok=True)
        
        # SQLite for transactional data
        with sqlite3.connect(self.sqlite_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS trades (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    pair TEXT NOT NULL,
                    side TEXT NOT NULL,
                    amount REAL NOT NULL,
                    price REAL NOT NULL,
                    total REAL NOT NULL,
                    fee REAL DEFAULT 0,
                    order_id TEXT,
                    strategy TEXT,
                    model_used TEXT,
                    confidence REAL,
                    pnl REAL DEFAULT 0,
                    status TEXT DEFAULT 'open',
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            conn.execute("""
                CREATE TABLE IF NOT EXISTS portfolio (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TEXT NOT NULL,
                    asset TEXT NOT NULL,
                    balance REAL NOT NULL,
                    usd_value REAL,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            conn.execute("""
                CREATE TABLE IF NOT EXISTS config_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
                )
            """)
        
        # DuckDB for analytics
        with duckdb.connect(self.duckdb_path) as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS market_data (
                    timestamp TIMESTAMP,
                    pair VARCHAR,
                    open DECIMAL(18,8),
                    high DECIMAL(18,8),
                    low DECIMAL(18,8),
                    close DECIMAL(18,8),
                    volume DECIMAL(18,8),
                    PRIMARY KEY (timestamp, pair)
                )
            """)
            
            conn.execute("""
                CREATE TABLE IF NOT EXISTS model_predictions (
                    timestamp TIMESTAMP,
                    pair VARCHAR,
                    model_name VARCHAR,
                    prediction DECIMAL(10,6),
                    confidence DECIMAL(5,4),
                    features JSON,
                    PRIMARY KEY (timestamp, pair, model_name)
                )
            """)
            
            conn.execute("""
                CREATE TABLE IF NOT EXISTS performance_metrics (
                    timestamp TIMESTAMP,
                    metric_name VARCHAR,
                    value DECIMAL(18,8),
                    pair VARCHAR,
                    timeframe VARCHAR,
                    PRIMARY KEY (timestamp, metric_name, pair, timeframe)
                )
            """)
        
        logger.info("Database schemas initialized successfully")

class MetricsManager:
    """Manages InfluxDB metrics collection"""
    
    def __init__(self):
        self.client = None
        self.write_api = None
        self.connect()
    
    def connect(self):
        """Connect to InfluxDB"""
        try:
            self.client = InfluxDBClient(
                url=config.influx_url,
                token=config.influx_token,
                org=config.influx_org
            )
            self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
            logger.info("Connected to InfluxDB successfully")
        except Exception as e:
            logger.error(f"Failed to connect to InfluxDB: {e}")
    
    def write_metric(self, measurement: str, tags: Dict[str, str], fields: Dict[str, float], timestamp: datetime = None):
        """Write metric to InfluxDB"""
        if not self.write_api:
            return
        
        try:
            point = Point(measurement)
            
            for tag_key, tag_value in tags.items():
                point = point.tag(tag_key, tag_value)
            
            for field_key, field_value in fields.items():
                point = point.field(field_key, field_value)
            
            if timestamp:
                point = point.time(timestamp, WritePrecision.NS)
            
            self.write_api.write(bucket=config.influx_bucket, record=point)
            
        except Exception as e:
            logger.error(f"Failed to write metric to InfluxDB: {e}")
    
    def write_trade_metrics(self, trade_data: Dict[str, Any]):
        """Write trading-specific metrics"""
        self.write_metric(
            "trades",
            {
                "pair": trade_data["pair"],
                "side": trade_data["side"],
                "strategy": trade_data.get("strategy", "unknown"),
                "model": trade_data.get("model_used", "unknown")
            },
            {
                "amount": trade_data["amount"],
                "price": trade_data["price"],
                "total": trade_data["total"],
                "fee": trade_data.get("fee", 0),
                "confidence": trade_data.get("confidence", 0),
                "pnl": trade_data.get("pnl", 0)
            }
        )
    
    def write_performance_metrics(self, metrics: Dict[str, float]):
        """Write performance metrics"""
        self.write_metric(
            "performance",
            {"source": "trading_bot"},
            metrics
        )

class TelegramNotifier:
    """Handles Telegram notifications"""
    
    def __init__(self):
        self.bot = None
        self.chat_id = config.telegram_chat_id
        self.setup()
    
    def setup(self):
        """Initialize Telegram bot"""
        if config.telegram_token:
            try:
                self.bot = Bot(token=config.telegram_token)
                logger.info("Telegram bot initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Telegram bot: {e}")
    
    async def send_message(self, message: str):
        """Send message to Telegram"""
        if not self.bot or not self.chat_id:
            logger.warning("Telegram not configured, skipping notification")
            return
        
        try:
            await self.bot.send_message(chat_id=self.chat_id, text=message)
            logger.info(f"Telegram message sent: {message[:50]}...")
        except TelegramError as e:
            logger.error(f"Failed to send Telegram message: {e}")
    
    async def send_trade_alert(self, trade_data: Dict[str, Any]):
        """Send trade notification"""
        side_emoji = "🟢" if trade_data["side"] == "buy" else "🔴"
        message = f"""
{side_emoji} Trade Executed

Pair: {trade_data["pair"]}
Side: {trade_data["side"].upper()}
Amount: {trade_data["amount"]}
Price: ${trade_data["price"]:.8f}
Total: ${trade_data["total"]:.2f}
Model: {trade_data.get("model_used", "N/A")}
Confidence: {trade_data.get("confidence", 0):.2%}

Time: {datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")}
        """
        await self.send_message(message.strip())

class AIInferenceClient:
    """Client for AI inference server"""
    
    def __init__(self):
        self.inference_url = config.inference_url
        self.session = requests.Session()
    
    async def get_prediction(self, model_name: str, features: List[float]) -> Dict[str, Any]:
        """Get prediction from AI model"""
        try:
            response = self.session.post(
                f"{self.inference_url}/predict",
                json={
                    "model_name": model_name,
                    "features": features,
                    "return_confidence": True
                },
                timeout=5.0
            )
            response.raise_for_status()
            return response.json()
        
        except Exception as e:
            logger.error(f"Inference request failed for model {model_name}: {e}")
            return None
    
    async def get_ensemble_prediction(self, features: List[float]) -> Dict[str, Any]:
        """Get ensemble prediction from multiple models"""
        try:
            response = self.session.post(
                f"{self.inference_url}/predict/ensemble",
                json={
                    "model_name": "ensemble",
                    "features": features,
                    "return_confidence": True
                },
                timeout=10.0
            )
            response.raise_for_status()
            return response.json()
        
        except Exception as e:
            logger.error(f"Ensemble inference request failed: {e}")
            return None

class MarketDataManager:
    """Manages market data collection and processing"""
    
    def __init__(self):
        self.exchanges = {}
        self.setup_exchanges()
    
    def setup_exchanges(self):
        """Initialize exchange connections"""
        try:
            # Initialize exchanges (paper trading mode by default)
            self.exchanges['binance'] = ccxt.binance({
                'apiKey': '',  # Paper trading - no real API keys needed
                'secret': '',
                'sandbox': True,  # Use testnet
                'enableRateLimit': True,
            })
            logger.info("Exchange connections initialized")
        except Exception as e:
            logger.error(f"Failed to initialize exchanges: {e}")
    
    async def get_market_data(self, pair: str, timeframe: str = '1m', limit: int = 100) -> pd.DataFrame:
        """Fetch market data for a trading pair"""
        try:
            exchange = self.exchanges.get('binance')
            if not exchange:
                return pd.DataFrame()
            
            ohlcv = exchange.fetch_ohlcv(pair, timeframe, limit=limit)
            
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
            df.set_index('timestamp', inplace=True)
            
            return df
        
        except Exception as e:
            logger.error(f"Failed to fetch market data for {pair}: {e}")
            return pd.DataFrame()
    
    def calculate_technical_indicators(self, df: pd.DataFrame) -> pd.DataFrame:
        """Calculate technical indicators"""
        if df.empty:
            return df
        
        try:
            # Simple indicators
            df['sma_20'] = df['close'].rolling(window=20).mean()
            df['sma_50'] = df['close'].rolling(window=50).mean()
            df['ema_12'] = df['close'].ewm(span=12).mean()
            df['ema_26'] = df['close'].ewm(span=26).mean()
            
            # MACD
            df['macd'] = df['ema_12'] - df['ema_26']
            df['macd_signal'] = df['macd'].ewm(span=9).mean()
            df['macd_histogram'] = df['macd'] - df['macd_signal']
            
            # RSI
            delta = df['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / loss
            df['rsi'] = 100 - (100 / (1 + rs))
            
            # Bollinger Bands
            df['bb_middle'] = df['close'].rolling(window=20).mean()
            bb_std = df['close'].rolling(window=20).std()
            df['bb_upper'] = df['bb_middle'] + (bb_std * 2)
            df['bb_lower'] = df['bb_middle'] - (bb_std * 2)
            
            # Volume indicators
            df['volume_sma'] = df['volume'].rolling(window=20).mean()
            df['volume_ratio'] = df['volume'] / df['volume_sma']
            
            return df
        
        except Exception as e:
            logger.error(f"Failed to calculate technical indicators: {e}")
            return df

class TradingEngine:
    """Main trading engine"""
    
    def __init__(self):
        self.db_manager = DatabaseManager()
        self.metrics_manager = MetricsManager()
        self.notifier = TelegramNotifier()
        self.inference_client = AIInferenceClient()
        self.market_data_manager = MarketDataManager()
        
        self.portfolio = {}
        self.active_trades = {}
        self.last_predictions = {}
    
    async def analyze_market(self, pair: str) -> Dict[str, Any]:
        """Analyze market for a trading pair"""
        try:
            # Get market data
            df = await self.market_data_manager.get_market_data(pair)
            if df.empty:
                return None
            
            # Calculate technical indicators
            df = self.market_data_manager.calculate_technical_indicators(df)
            
            # Prepare features for AI model
            latest = df.iloc[-1]
            features = [
                latest['close'],
                latest['volume'],
                latest.get('rsi', 50),
                latest.get('macd', 0),
                latest.get('bb_upper', latest['close']) - latest['close'],
                latest.get('bb_lower', latest['close']) - latest['close'],
                latest.get('volume_ratio', 1),
                (latest['close'] - latest.get('sma_20', latest['close'])) / latest['close'],
                (latest['close'] - latest.get('sma_50', latest['close'])) / latest['close']
            ]
            
            # Get AI predictions
            ensemble_prediction = await self.inference_client.get_ensemble_prediction(features)
            
            return {
                'pair': pair,
                'market_data': df,
                'features': features,
                'prediction': ensemble_prediction,
                'analysis_time': datetime.now(timezone.utc)
            }
        
        except Exception as e:
            logger.error(f"Market analysis failed for {pair}: {e}")
            return None
    
    async def execute_trade(self, pair: str, side: str, amount: float, analysis: Dict[str, Any]):
        """Execute a trade based on analysis"""
        try:
            # For paper trading, simulate execution
            current_price = analysis['market_data']['close'].iloc[-1]
            
            # Simulate slippage (0.01-0.05%)
            slippage = np.random.uniform(0.0001, 0.0005)
            execution_price = current_price * (1 + slippage if side == 'buy' else 1 - slippage)
            
            total_value = amount * execution_price
            fee = total_value * 0.001  # 0.1% fee simulation
            
            trade_data = {
                'timestamp': datetime.now(timezone.utc).isoformat(),
                'pair': pair,
                'side': side,
                'amount': amount,
                'price': execution_price,
                'total': total_value,
                'fee': fee,
                'order_id': f"sim_{int(time.time())}",
                'strategy': 'ai_ensemble',
                'model_used': 'ensemble',
                'confidence': analysis['prediction'].get('confidence', 0) if analysis['prediction'] else 0,
                'status': 'filled'
            }
            
            # Save to database
            with sqlite3.connect(self.db_manager.sqlite_path) as conn:
                conn.execute("""
                    INSERT INTO trades 
                    (timestamp, pair, side, amount, price, total, fee, order_id, 
                     strategy, model_used, confidence, status)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    trade_data['timestamp'], trade_data['pair'], trade_data['side'],
                    trade_data['amount'], trade_data['price'], trade_data['total'],
                    trade_data['fee'], trade_data['order_id'], trade_data['strategy'],
                    trade_data['model_used'], trade_data['confidence'], trade_data['status']
                ))
            
            # Write metrics
            self.metrics_manager.write_trade_metrics(trade_data)
            
            # Send notification
            await self.notifier.send_trade_alert(trade_data)
            
            logger.info(f"Trade executed: {side} {amount} {pair} at {execution_price}")
            return trade_data
        
        except Exception as e:
            logger.error(f"Trade execution failed: {e}")
            return None
    
    async def trading_loop(self):
        """Main trading loop"""
        logger.info("Starting trading loop...")
        last_heartbeat = 0
        
        while is_running:
            try:
                # Heartbeat logging every 60 seconds or less
                current_time = time.time()
                if current_time - last_heartbeat >= 60:
                    logger.info(f"🟢 HEARTBEAT: AITB Bot alive - {datetime.now(timezone.utc).isoformat()} - Active pairs: {len(config.trading_pairs)} - Memory: {psutil.virtual_memory().percent:.1f}%")
                    last_heartbeat = current_time
                
                for pair in config.trading_pairs:
                    # Analyze market
                    analysis = await self.analyze_market(pair)
                    if not analysis or not analysis['prediction']:
                        continue
                    
                    prediction = analysis['prediction']
                    confidence = prediction.get('confidence', 0)
                    
                    # Trading decision logic
                    if confidence > 0.7:  # High confidence threshold
                        pred_value = prediction.get('prediction', 0)
                        
                        if isinstance(pred_value, list):
                            pred_value = pred_value[0] if pred_value else 0
                        
                        # Simple strategy: buy on positive prediction, sell on negative
                        if pred_value > 0.1 and confidence > 0.7:
                            # Buy signal
                            amount = config.max_position_size * 1000  # Example amount
                            await self.execute_trade(pair, 'buy', amount, analysis)
                        elif pred_value < -0.1 and confidence > 0.7:
                            # Sell signal (if we have position)
                            amount = config.max_position_size * 1000  # Example amount
                            await self.execute_trade(pair, 'sell', amount, analysis)
                
                # Write performance metrics
                self.metrics_manager.write_performance_metrics({
                    'active_pairs': len(config.trading_pairs),
                    'bot_uptime': time.time() - trading_session.get('start_time', time.time()),
                    'memory_usage': psutil.virtual_memory().percent
                })
                
                # Wait before next iteration
                await asyncio.sleep(60)  # 1 minute interval
                
            except Exception as e:
                logger.error(f"Error in trading loop: {e}")
                await asyncio.sleep(10)

# Initialize trading engine
trading_engine = TradingEngine()

# FastAPI endpoints
@app.on_event("startup")
async def startup_event():
    """Initialize bot on startup"""
    global is_running, trading_session
    
    logger.info("AITB Trading Bot starting up...")
    
    # Initialize trading session
    trading_session = {
        'start_time': time.time(),
        'trades_count': 0,
        'status': 'running'
    }
    
    is_running = True
    
    # Start trading loop in background
    asyncio.create_task(trading_engine.trading_loop())
    
    # Send startup notification
    await trading_engine.notifier.send_message("🚀 AITB Trading Bot started successfully!")
    
    logger.info("AITB Trading Bot startup completed")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    global is_running
    
    logger.info("AITB Trading Bot shutting down...")
    is_running = False
    
    # Send shutdown notification
    await trading_engine.notifier.send_message("⚠️ AITB Trading Bot shutting down...")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime": time.time() - trading_session.get('start_time', time.time()),
        "is_running": is_running,
        "active_pairs": len(config.trading_pairs),
        "trading_mode": config.trading_mode
    }

@app.get("/status")
async def get_status():
    """Get detailed bot status"""
    return {
        "session": trading_session,
        "config": {
            "trading_pairs": config.trading_pairs,
            "trading_mode": config.trading_mode,
            "max_position_size": config.max_position_size,
            "active_models": config.active_models
        },
        "portfolio": trading_engine.portfolio,
        "active_trades": len(trading_engine.active_trades)
    }

@app.get("/trades")
async def get_recent_trades(limit: int = 10):
    """Get recent trades"""
    try:
        with sqlite3.connect(trading_engine.db_manager.sqlite_path) as conn:
            query = "SELECT * FROM trades ORDER BY created_at DESC LIMIT ?"
            df = pd.read_sql_query(query, conn, params=[limit])
            return df.to_dict(orient='records')
    except Exception as e:
        logger.error(f"Failed to fetch trades: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/manual_trade")
async def manual_trade(pair: str, side: str, amount: float):
    """Execute manual trade"""
    try:
        analysis = await trading_engine.analyze_market(pair)
        if not analysis:
            raise HTTPException(status_code=400, detail="Failed to analyze market")
        
        trade = await trading_engine.execute_trade(pair, side, amount, analysis)
        if not trade:
            raise HTTPException(status_code=500, detail="Failed to execute trade")
        
        return trade
    except Exception as e:
        logger.error(f"Manual trade failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "AITB Trading Bot",
        "version": "1.0.0",
        "status": "running" if is_running else "stopped",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "endpoints": {
            "health": "/health",
            "status": "/status",
            "trades": "/trades",
            "manual_trade": "/manual_trade",
            "docs": "/docs"
        }
    }

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    global is_running
    logger.info(f"Received signal {signum}, shutting down gracefully...")
    is_running = False

if __name__ == "__main__":
    # Register signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Start the FastAPI server
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        workers=1,
        log_level="info"
    )