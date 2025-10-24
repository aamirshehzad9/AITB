#!/usr/bin/env python3
"""
AITB Trading Dashboard
Streamlit-based real-time visualization for paper trading data
"""

import streamlit as st
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.express as px
from influxdb_client import InfluxDBClient
import time
import datetime
from typing import Dict, List, Optional
import requests
import json

# Configuration
INFLUXDB_URL = "http://influxdb:8086"
INFLUXDB_TOKEN = "aitb_token"
INFLUXDB_ORG = "aitb"
INFLUXDB_BUCKET = "aitb"

BOT_SERVICE_URL = "http://bot:8000"
INFERENCE_SERVICE_URL = "http://inference:8001"

# Page configuration
st.set_page_config(
    page_title="AITB Trading Dashboard",
    page_icon="📈",
    layout="wide",
    initial_sidebar_state="expanded"
)

class AITBDashboard:
    def __init__(self):
        self.influx_client = None
        self.init_influxdb()
    
    def init_influxdb(self):
        """Initialize InfluxDB connection"""
        try:
            self.influx_client = InfluxDBClient(
                url=INFLUXDB_URL,
                token=INFLUXDB_TOKEN,
                org=INFLUXDB_ORG
            )
            # Test connection
            self.influx_client.ping()
        except Exception as e:
            st.error(f"Failed to connect to InfluxDB: {str(e)}")
            self.influx_client = None
    
    def get_bot_status(self) -> Dict:
        """Get current bot status"""
        try:
            response = requests.get(f"{BOT_SERVICE_URL}/status", timeout=5)
            return response.json() if response.status_code == 200 else {}
        except:
            return {"status": "offline", "error": "Connection failed"}
    
    def get_inference_status(self) -> Dict:
        """Get inference service status"""
        try:
            response = requests.get(f"{INFERENCE_SERVICE_URL}/health", timeout=5)
            return response.json() if response.status_code == 200 else {}
        except:
            return {"status": "offline", "error": "Connection failed"}
    
    def get_trading_metrics(self, time_range: str = "1h") -> pd.DataFrame:
        """Fetch trading metrics from InfluxDB"""
        if not self.influx_client:
            return pd.DataFrame()
        
        try:
            query = f'''
            from(bucket: "{INFLUXDB_BUCKET}")
            |> range(start: -{time_range})
            |> filter(fn: (r) => r._measurement == "trading_metrics")
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            '''
            
            query_api = self.influx_client.query_api()
            result = query_api.query_data_frame(query)
            
            if not result.empty and isinstance(result, pd.DataFrame):
                result['_time'] = pd.to_datetime(result['_time'])
                return result.sort_values('_time')
            return pd.DataFrame()
        except Exception as e:
            st.warning(f"Error fetching trading metrics: {str(e)}")
            return pd.DataFrame()
    
    def get_market_data(self, symbol: str = "BTC/USDT", time_range: str = "1h") -> pd.DataFrame:
        """Fetch market data (OHLC) from InfluxDB or generate sample data"""
        if not self.influx_client:
            return self._generate_sample_market_data(symbol)
        
        try:
            query = f'''
            from(bucket: "{INFLUXDB_BUCKET}")
            |> range(start: -{time_range})
            |> filter(fn: (r) => r._measurement == "market_data")
            |> filter(fn: (r) => r.symbol == "{symbol}")
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            '''
            
            query_api = self.influx_client.query_api()
            result = query_api.query_data_frame(query)
            
            if not result.empty and isinstance(result, pd.DataFrame):
                result['_time'] = pd.to_datetime(result['_time'])
                return result.sort_values('_time')
            
            # Fallback to sample data if no real data found
            return self._generate_sample_market_data(symbol)
        except Exception as e:
            st.warning(f"Using sample data - InfluxDB connection issue: {str(e)}")
            return self._generate_sample_market_data(symbol)
    
    def _generate_sample_market_data(self, symbol: str) -> pd.DataFrame:
        """Generate sample OHLC data for demo purposes"""
        import random
        from datetime import datetime, timedelta
        
        # Base prices for different symbols
        base_prices = {
            "BTC/USDT": 43000,
            "ETH/USDT": 2600,
            "ADA/USDT": 0.45,
            "DOT/USDT": 6.5
        }
        
        base_price = base_prices.get(symbol, 43000)
        
        # Generate 60 data points (1 hour of minute data)
        data = []
        current_time = datetime.now() - timedelta(hours=1)
        current_price = base_price
        
        for i in range(60):
            # Random price movement
            change_percent = random.uniform(-0.005, 0.005)  # ±0.5%
            current_price *= (1 + change_percent)
            
            # OHLC with some randomness
            open_price = current_price
            high_price = open_price * random.uniform(1.0, 1.003)
            low_price = open_price * random.uniform(0.997, 1.0)
            close_price = open_price * random.uniform(0.998, 1.002)
            volume = random.uniform(100, 1000)
            
            data.append({
                '_time': current_time + timedelta(minutes=i),
                'open': open_price,
                'high': high_price,
                'low': low_price,
                'close': close_price,
                'volume': volume,
                'symbol': symbol
            })
        
        return pd.DataFrame(data)
    
    def get_ai_predictions(self, time_range: str = "1h") -> pd.DataFrame:
        """Fetch AI prediction data from InfluxDB"""
        if not self.influx_client:
            return pd.DataFrame()
        
        try:
            query = f'''
            from(bucket: "{INFLUXDB_BUCKET}")
            |> range(start: -{time_range})
            |> filter(fn: (r) => r._measurement == "ai_predictions")
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
            '''
            
            query_api = self.influx_client.query_api()
            result = query_api.query_data_frame(query)
            
            if not result.empty and isinstance(result, pd.DataFrame):
                result['_time'] = pd.to_datetime(result['_time'])
                return result.sort_values('_time')
            return pd.DataFrame()
        except Exception as e:
            st.warning(f"Error fetching AI predictions: {str(e)}")
            return pd.DataFrame()
    
    def create_candlestick_chart(self, df: pd.DataFrame, symbol: str) -> go.Figure:
        """Create candlestick chart with volume"""
        if df.empty:
            return go.Figure().add_annotation(
                text="No market data available",
                xref="paper", yref="paper",
                x=0.5, y=0.5, showarrow=False
            )
        
        # Create subplots
        fig = make_subplots(
            rows=2, cols=1,
            shared_xaxes=True,
            vertical_spacing=0.1,
            subplot_titles=(f"{symbol} Price", "Volume"),
            row_width=[0.7, 0.3]
        )
        
        # Candlestick chart
        fig.add_trace(
            go.Candlestick(
                x=df['_time'],
                open=df.get('open', df.get('price', 0)),
                high=df.get('high', df.get('price', 0)),
                low=df.get('low', df.get('price', 0)),
                close=df.get('close', df.get('price', 0)),
                name="Price"
            ),
            row=1, col=1
        )
        
        # Volume bars
        if 'volume' in df.columns:
            fig.add_trace(
                go.Bar(
                    x=df['_time'],
                    y=df['volume'],
                    name="Volume",
                    marker_color='rgba(158,202,225,0.6)'
                ),
                row=2, col=1
            )
        
        fig.update_layout(
            title=f"{symbol} Real-time Chart",
            xaxis_rangeslider_visible=False,
            height=600
        )
        
        return fig
    
    def render_status_cards(self):
        """Render service status cards"""
        col1, col2, col3 = st.columns(3)
        
        with col1:
            bot_status = self.get_bot_status()
            status = bot_status.get('status', 'unknown')
            color = "🟢" if status == "running" else "🔴"
            st.metric(
                label=f"{color} Trading Bot",
                value=status.title(),
                delta=f"Trades: {bot_status.get('session', {}).get('trades_count', 0)}"
            )
        
        with col2:
            inf_status = self.get_inference_status()
            status = inf_status.get('status', 'unknown')
            color = "🟢" if status == "healthy" else "🔴"
            st.metric(
                label=f"{color} AI Inference",
                value=status.title(),
                delta=f"Models: {len(inf_status.get('models', []))}"
            )
        
        with col3:
            db_status = "Connected" if self.influx_client else "Offline"
            color = "🟢" if self.influx_client else "🔴"
            st.metric(
                label=f"{color} Database",
                value=db_status,
                delta="InfluxDB"
            )
    
    def render_trading_metrics(self):
        """Render trading performance metrics"""
        st.subheader("📊 Trading Performance")
        
        col1, col2, col3, col4 = st.columns(4)
        
        # Get recent metrics
        metrics_df = self.get_trading_metrics("24h")
        
        if not metrics_df.empty:
            latest_balance = metrics_df.get('balance', pd.Series([10000])).iloc[-1]
            total_trades = metrics_df.get('trades_count', pd.Series([0])).max()
            win_rate = metrics_df.get('win_rate', pd.Series([0])).mean() * 100
            pnl = latest_balance - 10000  # Assuming 10k starting balance
        else:
            latest_balance, total_trades, win_rate, pnl = 10000, 0, 0, 0
        
        with col1:
            st.metric("Portfolio Value", f"${latest_balance:,.2f}", f"{pnl:+.2f}")
        
        with col2:
            st.metric("Total Trades", int(total_trades))
        
        with col3:
            st.metric("Win Rate", f"{win_rate:.1f}%")
        
        with col4:
            pofa_score = min(100, (latest_balance / 10000) * 100) if latest_balance > 0 else 0
            st.metric("PoFA Score", f"{pofa_score:.1f}%")
    
    def render_ai_insights(self):
        """Render AI prediction insights"""
        st.subheader("🤖 AI Trading Insights")
        
        predictions_df = self.get_ai_predictions("1h")
        
        if not predictions_df.empty:
            col1, col2 = st.columns(2)
            
            with col1:
                # Latest prediction confidence
                if 'confidence' in predictions_df.columns:
                    latest_confidence = predictions_df['confidence'].iloc[-1] * 100
                    st.metric("AI Confidence", f"{latest_confidence:.1f}%")
                
                # Prediction trend
                if 'direction' in predictions_df.columns:
                    latest_direction = predictions_df['direction'].iloc[-1]
                    direction_emoji = "📈" if latest_direction > 0 else "📉"
                    st.metric("Market Signal", f"{direction_emoji} {latest_direction}")
            
            with col2:
                # Model agreement
                if len(predictions_df) > 0:
                    st.metric("Predictions Today", len(predictions_df))
                
                # Active models
                st.metric("Active Models", "3", "qwen, gemma, mistral")
        else:
            st.info("Waiting for AI predictions...")
    
    def run(self):
        """Main dashboard application"""
        # Header
        st.title("🚀 AITB Trading Dashboard")
        st.markdown("*Real-time AI-Driven Paper Trading Visualization*")
        
        # Auto-refresh
        if st.checkbox("Auto-refresh (30s)", value=True):
            time.sleep(30)
            st.rerun()
        
        # Status overview
        self.render_status_cards()
        st.divider()
        
        # Trading metrics
        self.render_trading_metrics()
        st.divider()
        
        # Main chart section
        col1, col2 = st.columns([3, 1])
        
        with col1:
            st.subheader("📈 Live Market Chart")
            
            # Symbol selector
            symbol = st.selectbox(
                "Trading Pair",
                ["BTC/USDT", "ETH/USDT", "ADA/USDT", "DOT/USDT"],
                index=0
            )
            
            # Time range selector
            time_range = st.selectbox(
                "Time Range",
                ["1h", "4h", "24h", "7d"],
                index=0
            )
            
            # Get and display market data
            market_df = self.get_market_data(symbol, time_range)
            chart = self.create_candlestick_chart(market_df, symbol)
            st.plotly_chart(chart, use_container_width=True)
        
        with col2:
            self.render_ai_insights()
        
        # Footer with system info
        st.divider()
        st.markdown(
            f"*Last updated: {datetime.datetime.now().strftime('%H:%M:%S')} | "
            f"AITB v1.0.0 | Phase 3 Dashboard*"
        )

def main():
    """Main application entry point"""
    dashboard = AITBDashboard()
    dashboard.run()

if __name__ == "__main__":
    main()