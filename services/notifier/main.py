#!/usr/bin/env python3
"""
AITB Telegram Notifier Service
Monitors system events and sends notifications to Telegram
"""

import os
import sys
import asyncio
import logging
import json
from datetime import datetime
from typing import Optional

import requests
from telegram import Bot
from influxdb_client import InfluxDBClient
from influxdb_client.client.query_api import QueryApi

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/notifier.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class AITBNotifier:
    def __init__(self):
        # Telegram configuration
        self.bot_token = os.getenv('TG_BOT_TOKEN')
        self.chat_id = os.getenv('TG_CHAT_ID')
        
        # InfluxDB configuration
        self.influx_url = os.getenv('INFLUX_URL', 'http://influxdb:8086')
        self.influx_token = os.getenv('INFLUX_TOKEN')
        self.influx_org = os.getenv('INFLUX_ORG', 'aitb-org')
        self.influx_bucket = os.getenv('INFLUX_BUCKET', 'aitb')
        
        # Validate required environment variables
        if not self.bot_token or not self.chat_id:
            logger.error("Missing required Telegram configuration")
            sys.exit(1)
            
        # Initialize Telegram bot
        self.bot = Bot(token=self.bot_token)
        
        # Initialize InfluxDB client if configured
        self.influx_client = None
        if self.influx_token:
            self.influx_client = InfluxDBClient(
                url=self.influx_url,
                token=self.influx_token,
                org=self.influx_org
            )
        
        logger.info("AITB Notifier initialized")
    
    async def send_notification(self, message: str, parse_mode: Optional[str] = None):
        """Send notification to Telegram"""
        try:
            await self.bot.send_message(
                chat_id=self.chat_id,
                text=message,
                parse_mode=parse_mode
            )
            logger.info(f"Notification sent: {message[:50]}...")
        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
    
    async def check_system_health(self):
        """Check system health and send alerts if needed"""
        try:
            # Check if InfluxDB is available
            if self.influx_client:
                query_api = self.influx_client.query_api()
                
                # Query for recent system metrics
                query = f'''
                from(bucket: "{self.influx_bucket}")
                |> range(start: -5m)
                |> filter(fn: (r) => r._measurement == "system")
                |> last()
                '''
                
                result = query_api.query(query)
                if not result:
                    await self.send_notification("⚠️ No recent system metrics in InfluxDB")
            
            logger.info("System health check completed")
            
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            await self.send_notification(f"🚨 Health check failed: {str(e)}")
    
    async def run(self):
        """Main notification service loop"""
        logger.info("Starting AITB Notifier service...")
        await self.send_notification("🤖 AITB Notifier service started")
        
        while True:
            try:
                await self.check_system_health()
                await asyncio.sleep(300)  # Check every 5 minutes
                
            except KeyboardInterrupt:
                logger.info("Shutdown signal received")
                break
            except Exception as e:
                logger.error(f"Unexpected error: {e}")
                await asyncio.sleep(60)  # Wait 1 minute before retry
        
        await self.send_notification("🛑 AITB Notifier service stopped")
        logger.info("AITB Notifier service stopped")

def main():
    """Entry point"""
    try:
        notifier = AITBNotifier()
        asyncio.run(notifier.run())
    except Exception as e:
        logger.error(f"Failed to start notifier: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()