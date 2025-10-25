#!/usr/bin/env python3
"""
AITB HuggingFace Fallback Inference System
Provides backup AI inference when local containers are down
"""

import requests
import json
import os
from datetime import datetime
from typing import Dict, Any, Optional

class HuggingFaceFallback:
    def __init__(self):
        self.hf_token = "your_huggingface_token_here"
        self.api_base = "https://api-inference.huggingface.co/models"
        self.headers = {"Authorization": f"Bearer {self.hf_token}"}
        self.models = {
            "text-generation": "microsoft/DialoGPT-medium",
            "trading-analysis": "EleutherAI/gpt-neo-2.7B",
            "sentiment": "cardiffnlp/twitter-roberta-base-sentiment-latest"
        }
        
    def query_model(self, model_name: str, prompt: str) -> Dict[str, Any]:
        """Query HuggingFace API for model inference"""
        try:
            url = f"{self.api_base}/{model_name}"
            payload = {"inputs": prompt}
            
            response = requests.post(url, headers=self.headers, json=payload)
            response.raise_for_status()
            
            result = {
                "model": model_name,
                "prompt": prompt,
                "response": response.json(),
                "timestamp": datetime.now().isoformat(),
                "status": "success"
            }
            
            # Log to fallback file
            self._log_inference(result)
            return result
            
        except Exception as e:
            error_result = {
                "model": model_name,
                "prompt": prompt,
                "error": str(e),
                "timestamp": datetime.now().isoformat(),
                "status": "error"
            }
            self._log_inference(error_result)
            return error_result
    
    def trading_prediction(self, market_data: str) -> Dict[str, Any]:
        """Generate trading prediction using HuggingFace models"""
        prompt = f"Analyze this market data and predict trading action: {market_data}"
        return self.query_model(self.models["trading-analysis"], prompt)
    
    def sentiment_analysis(self, text: str) -> Dict[str, Any]:
        """Perform sentiment analysis on market news"""
        return self.query_model(self.models["sentiment"], text)
    
    def _log_inference(self, result: Dict[str, Any]):
        """Log inference results to file"""
        log_dir = "D:/GentleOmega/logs"
        os.makedirs(log_dir, exist_ok=True)
        
        timestamp = datetime.now().strftime("%Y%m%d")
        log_file = f"{log_dir}/inference_fallback_{timestamp}.json"
        
        # Append to daily log file
        try:
            if os.path.exists(log_file):
                with open(log_file, 'r') as f:
                    data = json.load(f)
            else:
                data = {"entries": []}
            
            data["entries"].append(result)
            
            with open(log_file, 'w') as f:
                json.dump(data, f, indent=2)
                
        except Exception as e:
            print(f"Failed to log inference: {e}")
    
    def test_connection(self) -> bool:
        """Test if HuggingFace API is accessible"""
        try:
            response = requests.get("https://huggingface.co/api/whoami", 
                                  headers=self.headers, timeout=10)
            return response.status_code == 200
        except:
            return False

if __name__ == "__main__":
    # Test the fallback system
    fallback = HuggingFaceFallback()
    
    print("Testing HuggingFace API connection...")
    if fallback.test_connection():
        print("✓ HuggingFace API accessible")
        
        # Test trading prediction
        result = fallback.trading_prediction("BTC price: $67,000, volume up 15%, RSI: 45")
        print(f"Trading prediction result: {result}")
        
    else:
        print("✗ HuggingFace API not accessible")