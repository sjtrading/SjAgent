#!/usr/bin/env node

/**
 * SjAgent Communication Layer
 * Node.js server for ai-trading-machine cluster communication
 */

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const redis = require('redis');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
require('dotenv').config();

// Configuration
const PORT = process.env.PORT || 3000;
const REDIS_URL = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
const I7_HOST = process.env.I7_HOST || '172.18.93.7';
const I7_USER = process.env.I7_USER || 'sivarajumalladi';

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Initialize Socket.IO
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Redis clients
let redisClient;
let redisSubscriber;

// Initialize Redis connections
async function initRedis() {
  try {
    redisClient = redis.createClient({ url: REDIS_URL });
    redisSubscriber = redisClient.duplicate();

    await redisClient.connect();
    await redisSubscriber.connect();

    console.log('✅ Redis connected');

    // Subscribe to cluster events
    await redisSubscriber.subscribe('cluster:status', 'cluster:jobs', 'cluster:results');

    redisSubscriber.on('message', (channel, message) => {
      console.log(`📡 Redis message: ${channel} - ${message}`);
      io.emit(channel, JSON.parse(message));
    });

  } catch (error) {
    console.error('❌ Redis connection failed:', error);
  }
}

// Routes
app.get('/', (req, res) => {
  res.json({
    name: 'SjAgent Communication Layer',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      'GET /': 'API info',
      'GET /health': 'Health check',
      'POST /jobs': 'Submit backtest job',
      'GET /jobs/:id': 'Get job status',
      'GET /cluster/status': 'Cluster status',
      'WebSocket': 'Real-time updates'
    }
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    redis: redisClient?.isOpen ? 'connected' : 'disconnected'
  });
});

// Submit backtest job
app.post('/jobs', async (req, res) => {
  try {
    const { strategies, symbols, startDate, endDate } = req.body;

    if (!strategies || !symbols || !startDate || !endDate) {
      return res.status(400).json({
        error: 'Missing required fields',
        required: ['strategies', 'symbols', 'startDate', 'endDate']
      });
    }

    // Generate job ID
    const jobId = `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    // Job data
    const jobData = {
      id: jobId,
      strategies: Array.isArray(strategies) ? strategies : [strategies],
      symbols: Array.isArray(symbols) ? symbols : [symbols],
      startDate,
      endDate,
      status: 'queued',
      submittedAt: new Date().toISOString(),
      progress: 0
    };

    // Store job in Redis
    await redisClient.set(`job:${jobId}`, JSON.stringify(jobData));

    // Add to job queue
    await redisClient.lPush('job:queue', jobId);

    // Notify via WebSocket
    io.emit('job:submitted', jobData);

    // Trigger ClaudBot notification
    notifyClaudBot('job_submitted', jobData);

    res.json({
      success: true,
      jobId,
      message: 'Job submitted successfully',
      data: jobData
    });

  } catch (error) {
    console.error('Job submission error:', error);
    res.status(500).json({ error: 'Failed to submit job' });
  }
});

// Get job status
app.get('/jobs/:id', async (req, res) => {
  try {
    const jobId = req.params.id;
    const jobData = await redisClient.get(`job:${jobId}`);

    if (!jobData) {
      return res.status(404).json({ error: 'Job not found' });
    }

    res.json(JSON.parse(jobData));
  } catch (error) {
    console.error('Job status error:', error);
    res.status(500).json({ error: 'Failed to get job status' });
  }
});

// Get cluster status
app.get('/cluster/status', async (req, res) => {
  try {
    const status = {
      timestamp: new Date().toISOString(),
      redis: redisClient?.isOpen ? 'connected' : 'disconnected',
      websocket: io.engine.clientsCount + ' clients connected',
      jobs: {
        queued: await redisClient.lLen('job:queue'),
        processing: await redisClient.lLen('job:processing'),
        completed: await redisClient.lLen('job:completed')
      }
    };

    res.json(status);
  } catch (error) {
    console.error('Cluster status error:', error);
    res.status(500).json({ error: 'Failed to get cluster status' });
  }
});

// WebSocket connection handling
io.on('connection', (socket) => {
  console.log(`🔌 Client connected: ${socket.id}`);

  // Send welcome message
  socket.emit('welcome', {
    message: 'Connected to SjAgent Communication Layer',
    timestamp: new Date().toISOString()
  });

  // Handle client requests
  socket.on('subscribe', (channels) => {
    console.log(`📡 Client ${socket.id} subscribed to:`, channels);
    socket.emit('subscribed', { channels });
  });

  socket.on('get_cluster_status', async () => {
    try {
      const status = {
        redis: redisClient?.isOpen ? 'connected' : 'disconnected',
        jobs: {
          queued: await redisClient.lLen('job:queue'),
          processing: await redisClient.lLen('job:processing'),
          completed: await redisClient.lLen('job:completed')
        }
      };
      socket.emit('cluster_status', status);
    } catch (error) {
      socket.emit('error', { message: 'Failed to get cluster status' });
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
  });
});

// ClaudBot notification function
async function notifyClaudBot(event, data) {
  try {
    // This would integrate with your ClaudBot system
    console.log(`🤖 ClaudBot notification: ${event}`, data);

    // Example: Send webhook to ClaudBot
    // await axios.post(process.env.CLAUDBOT_WEBHOOK_URL, {
    //   event,
    //   data,
    //   timestamp: new Date().toISOString()
    // });

  } catch (error) {
    console.error('ClaudBot notification failed:', error);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🛑 Shutting down gracefully...');

  if (redisClient) await redisClient.quit();
  if (redisSubscriber) await redisSubscriber.quit();

  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  process.emit('SIGTERM');
});

// Start server
async function startServer() {
  try {
    await initRedis();

    server.listen(PORT, () => {
      console.log(`🚀 SjAgent Communication Layer running on port ${PORT}`);
      console.log(`📡 WebSocket server ready`);
      console.log(`🔗 API endpoints available at http://localhost:${PORT}`);
      console.log(`📊 Health check: http://localhost:${PORT}/health`);
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

startServer();
