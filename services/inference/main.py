"""
AITB Inference Server
Fast API-based ML model serving with ONNX Runtime optimization
Supports multiple AI models: Qwen, Gemma, Mistral, SmolLM, Granite
"""

import os
import json
import time
import asyncio
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any, Union
from datetime import datetime, timezone

import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import onnxruntime as ort
from transformers import AutoTokenizer, AutoConfig
import torch
import psutil
import GPUtil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/inference.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AITB Inference Server",
    description="AI Model Inference Service for Trading Bot",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global variables
model_registry = {}
loaded_models = {}
model_stats = {}

# Pydantic models for API
class PredictionRequest(BaseModel):
    """Request model for predictions"""
    model_name: str = Field(..., description="Name of the model to use")
    features: List[float] = Field(..., description="Input features for prediction")
    sequence_length: Optional[int] = Field(32, description="Sequence length for time series models")
    return_confidence: Optional[bool] = Field(True, description="Whether to return confidence scores")

class PredictionResponse(BaseModel):
    """Response model for predictions"""
    model_name: str
    prediction: Union[float, List[float]]
    confidence: Optional[float] = None
    latency_ms: float
    timestamp: str
    model_version: str

class ModelInfo(BaseModel):
    """Model information response"""
    name: str
    version: str
    type: str
    accuracy: Optional[float] = None
    latency_ms: Optional[float] = None
    memory_mb: Optional[float] = None
    last_used: Optional[str] = None
    status: str

class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    timestamp: str
    models_loaded: int
    system_info: Dict[str, Any]

# Model Registry Management
class ModelRegistry:
    """Manages AI model registry and metadata"""
    
    def __init__(self, registry_path: str = "/app/data/models/model_registry.json"):
        self.registry_path = registry_path
        self.models = {}
        self.load_registry()
    
    def load_registry(self):
        """Load model registry from JSON file"""
        try:
            if os.path.exists(self.registry_path):
                with open(self.registry_path, 'r') as f:
                    data = json.load(f)
                    self.models = data.get('models', {})
                logger.info(f"Loaded {len(self.models)} models from registry")
            else:
                self.create_default_registry()
        except Exception as e:
            logger.error(f"Error loading model registry: {e}")
            self.create_default_registry()
    
    def create_default_registry(self):
        """Create default model registry with supported models"""
        self.models = {
            "qwen-2b": {
                "path": "/app/data/models/qwen-2b.onnx",
                "type": "transformer",
                "version": "1.0.0",
                "accuracy": 0.0,
                "latency_ms": 0.0,
                "memory_mb": 0.0,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "status": "available"
            },
            "gemma-2b": {
                "path": "/app/data/models/gemma-2b.onnx",
                "type": "transformer", 
                "version": "1.0.0",
                "accuracy": 0.0,
                "latency_ms": 0.0,
                "memory_mb": 0.0,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "status": "available"
            },
            "mistral-7b": {
                "path": "/app/data/models/mistral-7b.onnx",
                "type": "transformer",
                "version": "1.0.0", 
                "accuracy": 0.0,
                "latency_ms": 0.0,
                "memory_mb": 0.0,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "status": "available"
            },
            "smollm-1b": {
                "path": "/app/data/models/smollm-1b.onnx",
                "type": "transformer",
                "version": "1.0.0",
                "accuracy": 0.0,
                "latency_ms": 0.0,
                "memory_mb": 0.0,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "status": "available"
            },
            "granite-3b": {
                "path": "/app/data/models/granite-3b.onnx",
                "type": "transformer",
                "version": "1.0.0",
                "accuracy": 0.0,
                "latency_ms": 0.0,
                "memory_mb": 0.0,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "status": "available"
            }
        }
        self.save_registry()
    
    def save_registry(self):
        """Save model registry to JSON file"""
        try:
            os.makedirs(os.path.dirname(self.registry_path), exist_ok=True)
            with open(self.registry_path, 'w') as f:
                json.dump({"models": self.models, "updated_at": datetime.now(timezone.utc).isoformat()}, f, indent=2)
            logger.info("Model registry saved successfully")
        except Exception as e:
            logger.error(f"Error saving model registry: {e}")

# Model Loading and Management
class ModelManager:
    """Manages loading and caching of ONNX models"""
    
    def __init__(self):
        self.loaded_models = {}
        self.model_stats = {}
        self.providers = self.get_available_providers()
    
    def get_available_providers(self) -> List[str]:
        """Get available ONNX execution providers"""
        providers = ['CPUExecutionProvider']
        
        # Check for GPU support
        try:
            import onnxruntime as ort
            available = ort.get_available_providers()
            if 'CUDAExecutionProvider' in available:
                providers.insert(0, 'CUDAExecutionProvider')
        except Exception as e:
            logger.warning(f"GPU provider check failed: {e}")
        
        logger.info(f"Available providers: {providers}")
        return providers
    
    async def load_model(self, model_name: str, model_info: Dict[str, Any]) -> bool:
        """Load ONNX model into memory"""
        try:
            model_path = model_info['path']
            
            if not os.path.exists(model_path):
                logger.warning(f"Model file not found: {model_path}")
                return False
            
            # ONNX Runtime session options
            sess_options = ort.SessionOptions()
            sess_options.enable_cpu_mem_arena = False
            sess_options.enable_mem_pattern = False
            sess_options.enable_mem_reuse = False
            sess_options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
            
            # Load model
            start_time = time.time()
            session = ort.InferenceSession(
                model_path,
                sess_options=sess_options,
                providers=self.providers
            )
            load_time = (time.time() - start_time) * 1000
            
            self.loaded_models[model_name] = {
                'session': session,
                'info': model_info,
                'loaded_at': datetime.now(timezone.utc).isoformat()
            }
            
            self.model_stats[model_name] = {
                'load_time_ms': load_time,
                'prediction_count': 0,
                'total_inference_time_ms': 0.0,
                'avg_inference_time_ms': 0.0,
                'last_used': None
            }
            
            logger.info(f"Successfully loaded model {model_name} in {load_time:.2f}ms")
            return True
            
        except Exception as e:
            logger.error(f"Error loading model {model_name}: {e}")
            return False
    
    async def predict(self, model_name: str, features: np.ndarray) -> Dict[str, Any]:
        """Run inference on loaded model"""
        if model_name not in self.loaded_models:
            raise ValueError(f"Model {model_name} not loaded")
        
        try:
            session = self.loaded_models[model_name]['session']
            model_info = self.loaded_models[model_name]['info']
            
            # Prepare input
            input_name = session.get_inputs()[0].name
            input_data = {input_name: features.astype(np.float32)}
            
            # Run inference
            start_time = time.time()
            outputs = session.run(None, input_data)
            inference_time = (time.time() - start_time) * 1000
            
            # Update statistics
            stats = self.model_stats[model_name]
            stats['prediction_count'] += 1
            stats['total_inference_time_ms'] += inference_time
            stats['avg_inference_time_ms'] = stats['total_inference_time_ms'] / stats['prediction_count']
            stats['last_used'] = datetime.now(timezone.utc).isoformat()
            
            # Process output
            prediction = outputs[0]
            if len(prediction.shape) > 1:
                prediction = prediction[0]  # Take first batch item
            
            # Calculate confidence (simplified)
            confidence = None
            if len(outputs) > 1:
                confidence = float(np.max(outputs[1]))  # If model outputs confidence
            else:
                # Estimate confidence based on prediction magnitude
                confidence = min(1.0, abs(float(prediction[0])) if hasattr(prediction, '__len__') else abs(float(prediction)))
            
            return {
                'prediction': prediction.tolist() if hasattr(prediction, 'tolist') else float(prediction),
                'confidence': confidence,
                'latency_ms': inference_time,
                'model_version': model_info['version']
            }
            
        except Exception as e:
            logger.error(f"Error during inference for model {model_name}: {e}")
            raise

# Initialize global instances
registry = ModelRegistry()
model_manager = ModelManager()

# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize models on startup"""
    logger.info("Starting AITB Inference Server...")
    
    # Load available models
    active_models = os.getenv('ACTIVE_MODELS', 'qwen-2b,gemma-2b').split(',')
    
    for model_name in active_models:
        model_name = model_name.strip()
        if model_name in registry.models:
            success = await model_manager.load_model(model_name, registry.models[model_name])
            if success:
                logger.info(f"Model {model_name} loaded successfully")
            else:
                logger.warning(f"Failed to load model {model_name}")
    
    logger.info("AITB Inference Server startup completed")

# API Endpoints
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    # System information
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    system_info = {
        "cpu_percent": cpu_percent,
        "memory_percent": memory.percent,
        "memory_available_gb": memory.available / (1024**3),
        "disk_free_gb": disk.free / (1024**3),
        "uptime_seconds": time.time() - psutil.boot_time()
    }
    
    # GPU information if available
    try:
        gpus = GPUtil.getGPUs()
        if gpus:
            gpu_info = []
            for gpu in gpus:
                gpu_info.append({
                    "name": gpu.name,
                    "memory_percent": gpu.memoryUtil * 100,
                    "memory_free_mb": gpu.memoryFree,
                    "temperature": gpu.temperature
                })
            system_info["gpus"] = gpu_info
    except Exception:
        pass  # No GPU available
    
    return HealthResponse(
        status="healthy",
        timestamp=datetime.now(timezone.utc).isoformat(),
        models_loaded=len(model_manager.loaded_models),
        system_info=system_info
    )

@app.get("/models", response_model=List[ModelInfo])
async def list_models():
    """List all available models"""
    models = []
    
    for name, info in registry.models.items():
        model_info = ModelInfo(
            name=name,
            version=info['version'],
            type=info['type'],
            accuracy=info.get('accuracy'),
            status="loaded" if name in model_manager.loaded_models else "available"
        )
        
        # Add runtime statistics if model is loaded
        if name in model_manager.model_stats:
            stats = model_manager.model_stats[name]
            model_info.latency_ms = stats['avg_inference_time_ms']
            model_info.last_used = stats['last_used']
        
        models.append(model_info)
    
    return models

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    """Run prediction on specified model"""
    try:
        # Validate model exists and is loaded
        if request.model_name not in model_manager.loaded_models:
            raise HTTPException(
                status_code=404,
                detail=f"Model {request.model_name} not found or not loaded"
            )
        
        # Prepare features
        features = np.array(request.features).reshape(1, -1)
        
        # Run prediction
        result = await model_manager.predict(request.model_name, features)
        
        return PredictionResponse(
            model_name=request.model_name,
            prediction=result['prediction'],
            confidence=result['confidence'] if request.return_confidence else None,
            latency_ms=result['latency_ms'],
            timestamp=datetime.now(timezone.utc).isoformat(),
            model_version=result['model_version']
        )
        
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict/ensemble")
async def predict_ensemble(request: PredictionRequest):
    """Run ensemble prediction across multiple models"""
    try:
        # Get active models for ensemble
        active_models = [name for name in model_manager.loaded_models.keys()]
        
        if not active_models:
            raise HTTPException(status_code=404, detail="No models loaded for ensemble")
        
        # Prepare features
        features = np.array(request.features).reshape(1, -1)
        
        # Run predictions on all models
        predictions = []
        confidences = []
        total_latency = 0
        
        for model_name in active_models:
            try:
                result = await model_manager.predict(model_name, features)
                predictions.append(result['prediction'])
                if result['confidence']:
                    confidences.append(result['confidence'])
                total_latency += result['latency_ms']
            except Exception as e:
                logger.warning(f"Model {model_name} failed in ensemble: {e}")
                continue
        
        if not predictions:
            raise HTTPException(status_code=500, detail="All models failed in ensemble")
        
        # Ensemble averaging (weighted by confidence if available)
        if confidences and len(confidences) == len(predictions):
            weights = np.array(confidences) / np.sum(confidences)
            ensemble_prediction = np.average(predictions, weights=weights, axis=0)
            ensemble_confidence = np.mean(confidences)
        else:
            ensemble_prediction = np.mean(predictions, axis=0)
            ensemble_confidence = None
        
        return PredictionResponse(
            model_name="ensemble",
            prediction=ensemble_prediction.tolist() if hasattr(ensemble_prediction, 'tolist') else float(ensemble_prediction),
            confidence=ensemble_confidence,
            latency_ms=total_latency,
            timestamp=datetime.now(timezone.utc).isoformat(),
            model_version="ensemble-1.0.0"
        )
        
    except Exception as e:
        logger.error(f"Ensemble prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/models/{model_name}/stats")
async def get_model_stats(model_name: str):
    """Get detailed statistics for a specific model"""
    if model_name not in model_manager.model_stats:
        raise HTTPException(status_code=404, detail=f"Model {model_name} not found")
    
    stats = model_manager.model_stats[model_name].copy()
    
    # Add model registry info
    if model_name in registry.models:
        stats.update(registry.models[model_name])
    
    return stats

@app.post("/models/{model_name}/load")
async def load_model_endpoint(model_name: str, background_tasks: BackgroundTasks):
    """Load a specific model"""
    if model_name not in registry.models:
        raise HTTPException(status_code=404, detail=f"Model {model_name} not found in registry")
    
    if model_name in model_manager.loaded_models:
        return {"message": f"Model {model_name} already loaded"}
    
    # Load model in background
    success = await model_manager.load_model(model_name, registry.models[model_name])
    
    if success:
        return {"message": f"Model {model_name} loaded successfully"}
    else:
        raise HTTPException(status_code=500, detail=f"Failed to load model {model_name}")

@app.delete("/models/{model_name}")
async def unload_model(model_name: str):
    """Unload a specific model from memory"""
    if model_name not in model_manager.loaded_models:
        raise HTTPException(status_code=404, detail=f"Model {model_name} not loaded")
    
    try:
        del model_manager.loaded_models[model_name]
        if model_name in model_manager.model_stats:
            del model_manager.model_stats[model_name]
        
        logger.info(f"Model {model_name} unloaded successfully")
        return {"message": f"Model {model_name} unloaded successfully"}
        
    except Exception as e:
        logger.error(f"Error unloading model {model_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    """Root endpoint with service information"""
    return {
        "service": "AITB Inference Server",
        "version": "1.0.0",
        "status": "running",
        "models_loaded": len(model_manager.loaded_models),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "endpoints": {
            "health": "/health",
            "models": "/models", 
            "predict": "/predict",
            "ensemble": "/predict/ensemble",
            "docs": "/docs"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app", 
        host="0.0.0.0", 
        port=8001, 
        reload=False,
        workers=1,
        log_level="info"
    )