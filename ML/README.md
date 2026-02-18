# Farmly Machine Learning Service

## Description
A Python-based microservice using FastAPI to provide AI capabilities:
- **Crop Disease Detection**: Image classification using PyTorch/TensorFlow models.
- **Crop Recommendation**: Machine learning model recommendations based on soil parameters.

## Prerequisites
- Python 3.8+
- Virtual environment (recommended)

## Installation
```bash
pip install -r requirements.txt
```

## Running
```bash
uvicorn app:app --reload --port 8000
```
API documentation is available at `http://localhost:8000/docs`.
