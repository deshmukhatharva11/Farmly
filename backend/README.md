# Farmly Backend

## Description
The backend service for Farmly, built with Node.js and Express. It handles:
- User Authentication (JWT)
- Database Operations (MongoDB)
- Session Management (Redis with fallback)
- Payment Processing (Stripe)
- Dashboard Data Aggregation

## Prerequisites
- Node.js (v14+)
- MongoDB running on `mongodb://localhost:27017/kisansahayak`
- Redis (Optional, built-in fallback available)

## Environment Variables
Create a `.env` file in this directory:
```env
PORT=5000
MONGO_URL=mongodb://localhost:27017/kisansahayak
JWT_SECRET=your_secret_key
STRIPE_SECRET_KEY=your_stripe_key
BASE_URL=http://localhost:5173
```

## Running
```bash
npm install
npm start
```
The server will start on port 5000.
