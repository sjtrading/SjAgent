# SjAgent Communication Layer

**Standalone Node.js repository** for real-time communication with ai-trading-machine distributed backtesting cluster.

[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)
[![Express](https://img.shields.io/badge/Express-4.x-blue.svg)](https://expressjs.com/)
[![Socket.io](https://img.shields.io/badge/Socket.io-4.x-black.svg)](https://socket.io/)
[![Redis](https://img.shields.io/badge/Redis-7.x-red.svg)](https://redis.io/)

## 🎯 Purpose

SjAgent provides the communication layer for the ai-trading-machine distributed backtesting cluster, enabling:

- **Real-time WebSocket monitoring** of backtesting jobs
- **REST API** for job submission and management
- **Web dashboard** for live cluster status visualization
- **ClaudBot integration** for natural language control
- **Redis queue integration** with Python backtesting workers

## 🏗️ Architecture

```
┌─────────────────┐    WebSocket/HTTP    ┌─────────────────┐
│   Mac M4        │◄──────────────────► │   SjAgent       │
│   (Client)      │                     │   (Node.js)     │
└─────────────────┘                     └─────────────────┘
        │                                       │
        │ SSH                                   │
        ▼                                       ▼
┌─────────────────┐    Redis Queue         ┌─────────────────┐
│   i7 Ubuntu     │◄─────────────────────► │   Python        │
│   (Server)      │                        │   Backtesting   │
└─────────────────┘                        └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- Redis server running
- ai-trading-machine cluster configured

### Installation
```bash
# Clone the repository
git clone https://github.com/sivarajumalladi/SjAgent.git
cd SjAgent

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your Redis and cluster settings (I7_HOST=172.18.93.7)

# Start the server
npm start
```

### Access Points
- **Web Dashboard**: http://localhost:3000
- **REST API**: http://localhost:3000/api/jobs
- **WebSocket**: ws://localhost:3000 (for real-time updates)

## 📡 API Endpoints

### REST API

#### Submit Job
```http
POST /api/jobs
Content-Type: application/json

{
  "strategy": "rsi",
  "symbol": "RELIANCE",
  "startDate": "2020-01-01",
  "endDate": "2020-12-31",
  "parameters": {
    "period": 14,
    "threshold": 0.05
  }
}
```

#### Get Job Status
```http
GET /api/jobs/:jobId
```

#### Get All Jobs
```http
GET /api/jobs
```

#### Cancel Job
```http
DELETE /api/jobs/:jobId
```

### WebSocket Events

#### Client → Server
- `submit-job`: Submit new backtesting job
- `cancel-job`: Cancel running job
- `get-status`: Request cluster status

#### Server → Client
- `job-status`: Job status updates
- `cluster-status`: Cluster health updates
- `job-completed`: Job completion notifications

## 🔧 Configuration

### Environment Variables (.env)
```bash
# Server Configuration
PORT=3000
NODE_ENV=development

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Cluster Configuration
CLUSTER_HOST=i7-server.local
CLUSTER_USER=ubuntu
SSH_KEY_PATH=~/.ssh/cluster_key

# ClaudBot Integration
CLAUDBOT_WEBHOOK_URL=http://localhost:8000/webhook
```

### Redis Queue Names
- `backtest:jobs` - Job submission queue
- `backtest:results` - Job results queue
- `backtest:status` - Real-time status updates

## 🎨 Web Dashboard

The web dashboard provides:
- **Live Job Status**: Real-time job progress and results
- **Cluster Metrics**: CPU, memory, and throughput monitoring
- **Interactive Controls**: Submit/cancel jobs via UI
- **Historical Results**: Past job results and performance metrics

## 🤖 ClaudBot Integration

SjAgent integrates with ClaudBot agents for natural language control:

```javascript
// Webhook endpoint for ClaudBot notifications
POST /api/webhook/claudbot
Content-Type: application/json

{
  "event": "job_completed",
  "jobId": "rsi-reliance-2020",
  "result": { ... }
}
```

## 🧪 Testing

```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage

# Integration tests
npm run test:integration
```

## 📊 Monitoring

### Health Checks
- **Server Health**: GET /health
- **Redis Connection**: GET /health/redis
- **Cluster Connection**: GET /health/cluster

### Metrics
- Job throughput (jobs/minute)
- WebSocket connection count
- API response times
- Error rates

## 🐳 Docker Support

```bash
# Build image
docker build -t sjagent .

# Run container
docker run -p 3000:3000 \
  -e REDIS_HOST=host.docker.internal \
  sjagent
```

## 📚 Documentation

- [API Reference](docs/API.md)
- [WebSocket Protocol](docs/WEBSOCKET.md)
- [Integration Guide](docs/INTEGRATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## 🤝 Related Repositories

- [ai-trading-machine](https://github.com/sivarajumalladi/ai-trading-machine) - Python backtesting cluster
- [ClaudBot](https://github.com/sivarajumalladi/ClaudBot) - Agent system integration

## 📄 License

This project is part of the AI Trading Machine platform. See main repository for licensing information.
