# Farmly (formerly SHRI BUILD)

**Farmly** is a smart, data-driven web application designed to help farmers make informed decisions. By integrating machine learning, environmental data, advanced imaging techniques, and innovative marketplace features, we aim to provide farmers with real-time insights into rainfall patterns, crop recommendations, disease management, and more.

## Components

This repository contains the following components:

- **Frontend**: A React-based web application for the user interface.
- **Backend**: A Node.js/Express server managing API requests, authentication, and database interactions.
- **ML**: A Python/FastAPI service for machine learning predictions (Crop recommendation, Disease detection).
- **Android**: A mobile application built with React Native/Expo.

## Getting Started

### Prerequisites

- **Node.js**: v14+
- **Python**: v3.8+
- **MongoDB**: Local or cloud instance.
- **Redis**: Local instance (optional, fallback available).

### Installation

1.  **Clone the repository**
2.  **Setup Backend**
    ```bash
    cd backend
    npm install
    # Create .env file (see backend/README.md)
    npm start
    ```
3.  **Setup Frontend**
    ```bash
    cd frontend
    npm install
    # Create .env file (see frontend/README.md)
    npm run dev
    ```
4.  **Setup ML Service**
    ```bash
    cd ML
    pip install -r requirements.txt
    uvicorn app:app --reload --port 8000
    ```

## Features

- **Rainfall Analysis**: Historical and real-time rainfall data.
- **Crop Recommendation**: AI-driven suggestions based on soil and weather.
- **Disease Detection**: Image-based diagnosis of crop diseases.
- **Marketplace**: Buy and sell agricultural products.
