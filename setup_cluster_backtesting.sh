#!/bin/bash
# Cluster Backtesting Setup - Mac M4 Driver + i7 Worker Node
# Distributed computing architecture for backtesting

set -e

echo "🔗 Setting up Backtesting Cluster (Mac M4 Driver → i7 Worker Node)"
echo "================================================================="

# Configuration
WORKER_HOST=${WORKER_HOST:-"i7-thin-client.local"}
WORKER_USER=${WORKER_USER:-"backtest"}
CLUSTER_PORT=${CLUSTER_PORT:-"6379"}  # Redis port for job queue
DRIVER_PORT=${DRIVER_PORT:-"8080"}   # Driver API port

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Cluster Architecture:${NC}"
echo "======================"
echo "Client (Mac M4):      Job submission, monitoring, control interface"
echo "Server (i7):          Driver + Worker (scheduler + executor)"
echo ""

# Test SSH connection to worker
echo -e "${YELLOW}🔑 Testing connection to worker node...${NC}"
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$WORKER_USER@$WORKER_HOST" "echo 'Worker node reachable'" 2>/dev/null; then
    echo -e "${RED}❌ Cannot reach worker node. Please ensure:${NC}"
    echo "   1. SSH key authentication is configured"
    echo "   2. Worker node is accessible at $WORKER_HOST"
    echo "   3. User $WORKER_USER exists on worker"
    echo ""
    echo "Setup SSH keys:"
    echo "   ssh-keygen -t ed25519 -C 'cluster-driver@mac-m4'"
    echo "   ssh-copy-id $WORKER_USER@$WORKER_HOST"
    exit 1
fi
echo -e "${GREEN}✅ Worker node connection verified${NC}"

# Install Redis on both machines (for job queue)
echo -e "${YELLOW}📦 Setting up Redis job queue...${NC}"

# Install Redis on Mac M4 (Driver)
if ! command -v redis-server &> /dev/null; then
    echo "Installing Redis on Mac M4..."
    brew install redis
    brew services start redis
else
    echo "Redis already installed on Mac M4"
fi

# Install Redis on worker node
echo "Installing Redis on worker node..."
ssh "$WORKER_USER@$WORKER_HOST" "
    if ! command -v redis-server &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y redis-server
        sudo systemctl enable redis-server
        sudo systemctl start redis-server
    else
        echo 'Redis already installed on worker'
    fi
"

# Test Redis connectivity
echo "Testing Redis connectivity..."
if ! redis-cli ping &> /dev/null; then
    echo -e "${RED}❌ Redis not responding on driver${NC}"
    exit 1
fi

ssh "$WORKER_USER@$WORKER_HOST" "
    if ! redis-cli ping &> /dev/null; then
        echo 'Redis not responding on worker'
        exit 1
    fi
"
echo -e "${GREEN}✅ Redis job queue operational${NC}"

# Create cluster directory structure
echo -e "${YELLOW}📁 Setting up cluster directories...${NC}"
mkdir -p cluster/{driver,worker,shared}
mkdir -p cluster/driver/{jobs,results,logs,config}
mkdir -p cluster/worker/{jobs,results,logs,status}
mkdir -p cluster/shared/{queue,monitoring}

# Create cluster configuration
cat > cluster/config/cluster.yaml << EOF
# Backtesting Cluster Configuration
cluster:
  name: "mac-m4-i7-cluster"
  version: "1.0.0"

driver:
  host: "localhost"
  port: $DRIVER_PORT
  redis_host: "localhost"
  redis_port: $CLUSTER_PORT
  heartbeat_interval: 30  # seconds

worker:
  host: "$WORKER_HOST"
  user: "$WORKER_USER"
  redis_host: "$WORKER_HOST"
  redis_port: $CLUSTER_PORT
  max_concurrent_jobs: 4
  heartbeat_interval: 15
  resource_limits:
    cpu_percent: 90
    memory_percent: 85
    disk_percent: 90

jobs:
  queue_name: "backtest_jobs"
  result_queue: "backtest_results"
  status_queue: "worker_status"
  chunk_size: 1000
  timeout: 3600  # 1 hour per job

monitoring:
  enable_telegram: true
  enable_web_dashboard: true
  log_level: "INFO"
  metrics_interval: 60
EOF

# Create driver components
echo -e "${YELLOW}🎯 Creating cluster driver components...${NC}"

# Cluster job scheduler (driver)
cat > cluster/driver/cluster_scheduler.py << 'EOF'
#!/usr/bin/env python3
"""
Backtesting Cluster Scheduler - Mac M4 Driver
Distributes jobs to worker nodes and monitors progress
"""

import asyncio
import json
import logging
import redis
import time
from datetime import datetime
from typing import Dict, List, Optional
import yaml
import psutil

class ClusterScheduler:
    def __init__(self, config_path: str = "cluster/config/cluster.yaml"):
        with open(config_path) as f:
            self.config = yaml.safe_load(f)

        self.redis = redis.Redis(
            host=self.config['driver']['redis_host'],
            port=self.config['driver']['redis_port'],
            decode_responses=True
        )

        self.setup_logging()
        self.workers = {}  # worker_id -> status
        self.active_jobs = {}  # job_id -> worker_id

    def setup_logging(self):
        logging.basicConfig(
            level=getattr(logging, self.config['monitoring']['log_level']),
            format='%(asctime)s - DRIVER - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('cluster/driver/logs/cluster_driver.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    async def start(self):
        """Start the cluster scheduler"""
        self.logger.info("🚀 Starting Backtesting Cluster Driver")

        # Start background tasks
        await asyncio.gather(
            self.heartbeat_monitor(),
            self.job_distributor(),
            self.result_collector(),
            self.status_monitor()
        )

    async def heartbeat_monitor(self):
        """Monitor worker heartbeats"""
        while True:
            try:
                # Check worker status from Redis
                status_data = self.redis.hgetall("worker_status")
                current_time = time.time()

                for worker_id, status_json in status_data.items():
                    status = json.loads(status_json)
                    last_heartbeat = status.get('timestamp', 0)

                    if current_time - last_heartbeat > 60:  # 1 minute timeout
                        self.logger.warning(f"⚠️ Worker {worker_id} heartbeat timeout")
                        self.workers[worker_id] = 'offline'
                    else:
                        self.workers[worker_id] = 'online'
                        self.logger.debug(f"✅ Worker {worker_id} heartbeat OK")

            except Exception as e:
                self.logger.error(f"Heartbeat monitor error: {e}")

            await asyncio.sleep(self.config['driver']['heartbeat_interval'])

    async def job_distributor(self):
        """Distribute jobs to available workers"""
        while True:
            try:
                # Get pending jobs
                job_data = self.redis.blpop("backtest_jobs", timeout=5)
                if not job_data:
                    await asyncio.sleep(1)
                    continue

                job = json.loads(job_data[1])
                job_id = job['id']

                # Find available worker
                available_worker = None
                for worker_id, status in self.workers.items():
                    if status == 'online':
                        # Check worker capacity
                        worker_status = json.loads(
                            self.redis.hget("worker_status", worker_id) or "{}"
                        )
                        active_jobs = worker_status.get('active_jobs', 0)
                        max_jobs = self.config['worker']['max_concurrent_jobs']

                        if active_jobs < max_jobs:
                            available_worker = worker_id
                            break

                if available_worker:
                    # Assign job to worker
                    self.redis.rpush(f"worker_{available_worker}_jobs", json.dumps(job))
                    self.active_jobs[job_id] = available_worker
                    self.logger.info(f"📤 Assigned job {job_id} to worker {available_worker}")
                else:
                    # No workers available, requeue
                    self.redis.rpush("backtest_jobs", json.dumps(job))
                    self.logger.warning("⚠️ No workers available, requeued job")

            except Exception as e:
                self.logger.error(f"Job distributor error: {e}")
                await asyncio.sleep(5)

    async def result_collector(self):
        """Collect results from workers"""
        while True:
            try:
                # Get completed results
                result_data = self.redis.blpop("backtest_results", timeout=5)
                if not result_data:
                    await asyncio.sleep(1)
                    continue

                result = json.loads(result_data[1])
                job_id = result['job_id']
                worker_id = result.get('worker_id')

                # Save result
                result_file = f"cluster/driver/results/{job_id}.json"
                with open(result_file, 'w') as f:
                    json.dump(result, f, indent=2)

                # Clean up active job
                if job_id in self.active_jobs:
                    del self.active_jobs[job_id]

                self.logger.info(f"📥 Collected result for job {job_id} from worker {worker_id}")

            except Exception as e:
                self.logger.error(f"Result collector error: {e}")
                await asyncio.sleep(5)

    async def status_monitor(self):
        """Monitor cluster status"""
        while True:
            try:
                # Collect cluster metrics
                status = {
                    'timestamp': time.time(),
                    'workers': self.workers,
                    'active_jobs': len(self.active_jobs),
                    'pending_jobs': self.redis.llen("backtest_jobs"),
                    'driver_cpu': psutil.cpu_percent(),
                    'driver_memory': psutil.virtual_memory().percent
                }

                # Save status
                with open('cluster/driver/status/cluster_status.json', 'w') as f:
                    json.dump(status, f, indent=2)

                self.logger.debug(f"📊 Cluster status: {len(self.workers)} workers, {len(self.active_jobs)} active jobs")

            except Exception as e:
                self.logger.error(f"Status monitor error: {e}")

            await asyncio.sleep(self.config['monitoring']['metrics_interval'])

    def submit_job(self, strategies: List[str], symbols: List[str],
                  start_date: str, end_date: str, priority: int = 1) -> str:
        """Submit a backtest job to the cluster"""
        job_id = f"job_{int(time.time())}_{hash(str(strategies) + str(symbols)) % 10000}"

        job = {
            'id': job_id,
            'type': 'backtest',
            'strategies': strategies,
            'symbols': symbols,
            'start_date': start_date,
            'end_date': end_date,
            'priority': priority,
            'submitted_at': datetime.now().isoformat(),
            'status': 'pending'
        }

        # Add to job queue
        self.redis.rpush("backtest_jobs", json.dumps(job))

        self.logger.info(f"📝 Submitted job {job_id}: {len(strategies)} strategies, {len(symbols)} symbols")
        return job_id

    def get_cluster_status(self) -> Dict:
        """Get current cluster status"""
        try:
            with open('cluster/driver/status/cluster_status.json') as f:
                return json.load(f)
        except:
            return {'error': 'Status not available'}

async def main():
    scheduler = ClusterScheduler()
    await scheduler.start()

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Cluster worker node (i7)
cat > cluster/worker/cluster_worker.py << 'EOF'
#!/usr/bin/env python3
"""
Backtesting Cluster Worker - i7 Compute Node
Executes backtest jobs assigned by the driver
"""

import asyncio
import json
import logging
import redis
import subprocess
import time
import psutil
from datetime import datetime
from typing import Dict, Optional
import yaml

class ClusterWorker:
    def __init__(self, worker_id: str, config_path: str = "cluster/config/cluster.yaml"):
        self.worker_id = worker_id

        with open(config_path) as f:
            self.config = yaml.safe_load(f)

        # Connect to Redis (could be on driver or local)
        self.redis = redis.Redis(
            host=self.config['worker']['redis_host'],
            port=self.config['worker']['redis_port'],
            decode_responses=True
        )

        self.setup_logging()
        self.active_jobs = 0
        self.max_jobs = self.config['worker']['max_concurrent_jobs']

    def setup_logging(self):
        logging.basicConfig(
            level=getattr(logging, self.config['monitoring']['log_level']),
            format='%(asctime)s - WORKER - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(f'cluster/worker/logs/worker_{self.worker_id}.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    async def start(self):
        """Start the worker node"""
        self.logger.info(f"🚀 Starting worker node {self.worker_id}")

        # Start background tasks
        await asyncio.gather(
            self.heartbeat_sender(),
            self.job_processor(),
            self.resource_monitor()
        )

    async def heartbeat_sender(self):
        """Send heartbeat to driver"""
        while True:
            try:
                status = {
                    'worker_id': self.worker_id,
                    'timestamp': time.time(),
                    'active_jobs': self.active_jobs,
                    'cpu_percent': psutil.cpu_percent(),
                    'memory_percent': psutil.virtual_memory().percent,
                    'disk_percent': psutil.disk_usage('/').percent,
                    'status': 'active'
                }

                # Send to Redis hash
                self.redis.hset("worker_status", self.worker_id, json.dumps(status))
                self.logger.debug(f"💓 Heartbeat sent: {self.active_jobs} active jobs")

            except Exception as e:
                self.logger.error(f"Heartbeat error: {e}")

            await asyncio.sleep(self.config['worker']['heartbeat_interval'])

    async def job_processor(self):
        """Process jobs from the queue"""
        while True:
            try:
                # Check if we can accept more jobs
                if self.active_jobs >= self.max_jobs:
                    await asyncio.sleep(5)
                    continue

                # Get job from worker-specific queue
                job_data = self.redis.blpop(f"worker_{self.worker_id}_jobs", timeout=5)
                if not job_data:
                    await asyncio.sleep(1)
                    continue

                job = json.loads(job_data[1])
                self.active_jobs += 1

                # Process job asynchronously
                asyncio.create_task(self.execute_job(job))

            except Exception as e:
                self.logger.error(f"Job processor error: {e}")
                await asyncio.sleep(5)

    async def execute_job(self, job: Dict):
        """Execute a backtest job"""
        job_id = job['id']
        self.logger.info(f"🎯 Executing job {job_id}")

        try:
            # Update job status
            job['status'] = 'running'
            job['started_at'] = datetime.now().isoformat()
            job['worker_id'] = self.worker_id

            # Execute backtest
            result = await self.run_backtest(job)

            # Send result back
            result_message = {
                'job_id': job_id,
                'worker_id': self.worker_id,
                'result': result,
                'completed_at': datetime.now().isoformat(),
                'status': 'completed'
            }

            self.redis.rpush("backtest_results", json.dumps(result_message))
            self.logger.info(f"✅ Completed job {job_id}")

        except Exception as e:
            self.logger.error(f"❌ Job {job_id} failed: {e}")

            # Send failure result
            error_result = {
                'job_id': job_id,
                'worker_id': self.worker_id,
                'error': str(e),
                'completed_at': datetime.now().isoformat(),
                'status': 'failed'
            }
            self.redis.rpush("backtest_results", json.dumps(error_result))

        finally:
            self.active_jobs -= 1

    async def run_backtest(self, job: Dict) -> Dict:
        """Run the actual backtest"""
        strategies = ','.join(job['strategies'])
        symbols = ','.join(job['symbols'])
        start_date = job['start_date']
        end_date = job['end_date']

        # Run backtest command
        cmd = [
            'python', 'scripts/backtesting/run_local_backtest.py',
            '--strategies', strategies,
            '--symbols', symbols,
            '--start-date', start_date,
            '--end-date', end_date,
            '--output', f'/tmp/backtest_result_{job["id"]}.json'
        ]

        self.logger.debug(f"Running command: {' '.join(cmd)}")

        # Execute command
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd='/home/backtest/ai-trading-machine'  # Adjust path as needed
        )

        stdout, stderr = await process.communicate()

        if process.returncode != 0:
            raise Exception(f"Backtest failed: {stderr.decode()}")

        # Read result file
        result_file = f'/tmp/backtest_result_{job["id"]}.json'
        try:
            with open(result_file) as f:
                result = json.load(f)
            # Clean up
            subprocess.run(['rm', result_file], check=False)
            return result
        except Exception as e:
            return {'error': f'Could not read result file: {e}'}

    async def resource_monitor(self):
        """Monitor resource usage"""
        while True:
            try:
                cpu = psutil.cpu_percent()
                memory = psutil.virtual_memory().percent
                disk = psutil.disk_usage('/').percent

                limits = self.config['worker']['resource_limits']

                if cpu > limits['cpu_percent']:
                    self.logger.warning(f"⚠️ High CPU usage: {cpu}%")
                if memory > limits['memory_percent']:
                    self.logger.warning(f"⚠️ High memory usage: {memory}%")
                if disk > limits['disk_percent']:
                    self.logger.warning(f"⚠️ High disk usage: {disk}%")

            except Exception as e:
                self.logger.error(f"Resource monitor error: {e}")

            await asyncio.sleep(60)

async def main():
    import socket
    worker_id = f"worker_{socket.gethostname()}_{int(time.time())}"
    worker = ClusterWorker(worker_id)
    await worker.start()

if __name__ == "__main__":
    asyncio.run(main())
EOF

# Cluster control scripts
echo -e "${YELLOW}🎮 Creating cluster control scripts...${NC}"

# Start cluster script (runs on i7)
cat > start_cluster_i7.sh << EOF
#!/bin/bash
# Start the backtesting cluster on i7 (Driver + Worker)

echo "🚀 Starting Backtesting Cluster on i7..."
echo "======================================="

# Start Redis (if not running)
if ! pgrep redis-server > /dev/null; then
    echo "Starting Redis..."
    redis-server --daemonize yes
fi

# Start driver + worker on i7
echo "Starting cluster driver and worker..."
python cluster/driver/cluster_scheduler.py &
DRIVER_PID=\$!
echo \$DRIVER_PID > cluster/driver.pid

python cluster/worker/cluster_worker.py &
WORKER_PID=\$!
echo \$WORKER_PID > cluster/worker.pid

echo ""
echo "✅ Cluster started on i7!"
echo "Driver PID: \$DRIVER_PID"
echo "Worker PID: \$WORKER_PID"
echo ""
echo "📊 Monitor from Mac M4 with: ./monitor_cluster.sh"
echo "🛑 Stop with: ./stop_cluster.sh"
echo ""
echo "📝 Submit jobs from Mac M4 with: ./submit_job.sh"
EOF

# Stop cluster script (stops i7 processes)
cat > stop_cluster.sh << EOF
#!/bin/bash
# Stop the backtesting cluster on i7

echo "🛑 Stopping Backtesting Cluster on i7..."

# Stop driver and worker on i7
ssh $WORKER_USER@$WORKER_HOST "
    # Stop driver
    if [ -f /home/$WORKER_USER/ai-trading-machine/cluster/driver.pid ]; then
        DRIVER_PID=\$(cat /home/$WORKER_USER/ai-trading-machine/cluster/driver.pid)
        kill \$DRIVER_PID 2>/dev/null && echo 'Stopped driver (PID: \$DRIVER_PID)' || echo 'Driver not running'
        rm /home/$WORKER_USER/ai-trading-machine/cluster/driver.pid
    fi

    # Stop worker
    if [ -f /home/$WORKER_USER/ai-trading-machine/cluster/worker.pid ]; then
        WORKER_PID=\$(cat /home/$WORKER_USER/ai-trading-machine/cluster/worker.pid)
        kill \$WORKER_PID 2>/dev/null && echo 'Stopped worker (PID: \$WORKER_PID)' || echo 'Worker not running'
        rm /home/$WORKER_USER/ai-trading-machine/cluster/worker.pid
    fi

    # Stop Redis
    pkill redis-server 2>/dev/null && echo 'Stopped Redis' || echo 'Redis not running'
"

echo "✅ Cluster stopped on i7"
EOF

# Monitor cluster script
cat > monitor_cluster.sh << EOF
#!/bin/bash
# Monitor cluster status

echo "📊 Backtesting Cluster Status"
echo "============================"
echo "Time: \$(date)"
echo ""

# Check processes
echo "🔄 Processes:"
if pgrep -f "cluster_scheduler.py" > /dev/null; then
    echo "✅ Driver: Running"
else
    echo "❌ Driver: Not running"
fi

if pgrep -f "cluster_worker.py" > /dev/null; then
    echo "✅ Worker: Running"
else
    echo "❌ Worker: Not running"
fi

if pgrep redis-server > /dev/null; then
    echo "✅ Redis: Running"
else
    echo "❌ Redis: Not running"
fi

echo ""

# Check cluster status
if [ -f cluster/driver/status/cluster_status.json ]; then
    echo "📈 Cluster Metrics:"
    python3 -c "
import json
with open('cluster/driver/status/cluster_status.json') as f:
    status = json.load(f)
    print(f'Workers: {len(status.get(\"workers\", {}))}')
    print(f'Active Jobs: {status.get(\"active_jobs\", 0)}')
    print(f'Pending Jobs: {status.get(\"pending_jobs\", 0)}')
    print(f'Driver CPU: {status.get(\"driver_cpu\", 0):.1f}%')
    print(f'Driver Memory: {status.get(\"driver_memory\", 0):.1f}%')
"
else
    echo "❌ No cluster status available"
fi

echo ""

# Check worker status
echo "👷 Worker Node Status:"
ssh $WORKER_USER@$WORKER_HOST "
    echo 'Host: $WORKER_HOST'
    echo 'CPU: \$(top -bn1 | grep \"Cpu(s)\" | sed \"s/.*, *\([0-9.]*\)%* id.*/\1/\" | awk '{print 100 - \$1\"%\"}')"
    echo 'Memory: \$(free -h | grep \"^Mem:\" | awk '{print \$3 \"/\" \$2 \" (\" \$4 \" free)\"}')"
    echo 'Active Backtests: \$(pgrep -f run_local_backtest | wc -l)'
" 2>/dev/null || echo "❌ Cannot connect to worker"

echo ""

# Show recent jobs
echo "📋 Recent Jobs:"
ls -la cluster/driver/results/ 2>/dev/null | tail -5 || echo "No completed jobs yet"
EOF

# Submit job script
cat > submit_job.sh << EOF
#!/bin/bash
# Submit a backtest job to the cluster

STRATEGIES=\${1:-"rsi,macd,momentum"}
SYMBOLS=\${2:-"RELIANCE,HDFC,TCS,INFY"}
START_DATE=\${3:-"2020-01-01"}
END_DATE=\${4:-"2024-12-31"}

echo "📝 Submitting backtest job to cluster..."
echo "Strategies: \$STRATEGIES"
echo "Symbols: \$SYMBOLS"
echo "Date Range: \$START_DATE to \$END_DATE"
echo ""

# Create job submission script
cat > /tmp/submit_job.py << 'PYTHON_EOF'
import sys
sys.path.append('cluster/driver')
from cluster_scheduler import ClusterScheduler

scheduler = ClusterScheduler()
job_id = scheduler.submit_job(
    strategies=sys.argv[1].split(','),
    symbols=sys.argv[2].split(','),
    start_date=sys.argv[3],
    end_date=sys.argv[4]
)
print(f"Job submitted: {job_id}")
PYTHON_EOF

python /tmp/submit_job.py "\$STRATEGIES" "\$SYMBOLS" "\$START_DATE" "\$END_DATE"
rm /tmp/submit_job.py

echo ""
echo "📊 Monitor progress with: ./monitor_cluster.sh"
echo "📁 Results will be in: cluster/driver/results/"
EOF

# Make scripts executable
chmod +x start_cluster.sh stop_cluster.sh monitor_cluster.sh submit_job.sh

# Copy worker files to i7
echo -e "${YELLOW}📤 Deploying worker components to i7 node...${NC}"
scp cluster/config/cluster.yaml "$WORKER_USER@$WORKER_HOST:/home/$WORKER_USER/ai-trading-machine/cluster/config/"
scp cluster/worker/cluster_worker.py "$WORKER_USER@$WORKER_HOST:/home/$WORKER_USER/ai-trading-machine/cluster/worker/"

# Update ClaudBot for cluster commands
echo -e "${YELLOW}🤖 Configuring ClaudBot for cluster control...${NC}"

# Add cluster intents to ClaudBot
CLUSTER_INTENTS='
  start_cluster:
    patterns:
      - "start.*cluster"
      - "launch.*cluster"
      - "begin.*cluster"
    template: "start_cluster.md"
    priority: "high"
    safe_auto_execute: false
    requires_approval: true
    default_params: {}
    commands:
      - cmd: "./start_cluster.sh"

  stop_cluster:
    patterns:
      - "stop.*cluster"
      - "shutdown.*cluster"
      - "end.*cluster"
    template: "stop_cluster.md"
    priority: "high"
    safe_auto_execute: true
    required_params: []
    commands:
      - cmd: "./stop_cluster.sh"

  monitor_cluster:
    patterns:
      - "monitor.*cluster"
      - "cluster.*status"
      - "check.*cluster"
    template: "monitor_cluster.md"
    priority: "high"
    safe_auto_execute: true
    required_params: []
    commands:
      - cmd: "./monitor_cluster.sh"

  submit_cluster_job:
    patterns:
      - "submit.*cluster.*job"
      - "run.*cluster.*backtest"
      - "cluster.*backtest"
    template: "submit_cluster_job.md"
    priority: "medium"
    safe_auto_execute: false
    requires_approval: true
    default_params:
      strategies: "rsi,macd,momentum"
      symbols: "RELIANCE,HDFC,TCS,INFY"
      start_date: "2020-01-01"
      end_date: "2024-12-31"
    commands:
      - cmd: "./submit_job.sh {STRATEGIES} {SYMBOLS} {START_DATE} {END_DATE}"
'

# Append to existing intent patterns
echo "$CLUSTER_INTENTS" >> claudbot/config/intent_patterns.yaml

# Create cluster command templates
cat > claudbot/templates/start_cluster.md << 'EOF'
# Start Backtesting Cluster

Launch the distributed backtesting cluster with Mac M4 driver and i7 worker node.

## Commands to Execute:
1. Start Redis job queue
2. Launch cluster driver on Mac M4
3. Start worker node on i7 thin client
4. Initialize monitoring and communication

## Architecture:
- **Driver (Mac M4)**: Job scheduling, result aggregation, monitoring
- **Worker (i7)**: Backtest execution, status reporting
- **Queue**: Redis-based job distribution
- **Communication**: Heartbeat monitoring, result collection

## Resource Requirements:
- Mac M4: Minimal (driver overhead)
- i7 Node: 16GB RAM, 4 CPU cores, 100GB storage
- Network: Stable connection between machines

## Safety Notes:
- Requires manual approval due to resource usage
- Monitor with "monitor cluster"
- Emergency stop with "stop cluster"
EOF

cat > claudbot/templates/monitor_cluster.md << 'EOF'
# Monitor Cluster Status

Check real-time status of the backtesting cluster.

## Commands to Execute:
1. Check driver and worker processes
2. Query Redis job queue status
3. Monitor resource usage on both nodes
4. Display active jobs and pending queue

## Expected Output:
- Process status (driver, worker, Redis)
- Worker count and health
- Active/pending job counts
- Resource utilization (CPU, memory)
- Recent completed jobs
EOF

cat > claudbot/templates/submit_cluster_job.md << 'EOF'
# Submit Cluster Job

Submit a backtest job to the distributed cluster.

## Parameters:
- strategies: Comma-separated strategy names (default: rsi,macd,momentum)
- symbols: Comma-separated symbols (default: RELIANCE,HDFC,TCS,INFY)
- start_date: Start date (default: 2020-01-01)
- end_date: End date (default: 2024-12-31)

## Commands to Execute:
1. Create job specification
2. Submit to Redis job queue
3. Job gets assigned to available worker
4. Results collected automatically

## Job Distribution:
- Jobs queued in Redis
- Automatically assigned to available workers
- Load balanced across cluster nodes
- Results aggregated on driver

## Safety Notes:
- Requires approval for resource usage
- Monitor progress with "monitor cluster"
- Results saved to cluster/driver/results/
EOF

cat > claudbot/templates/stop_cluster.md << 'EOF'
# Stop Backtesting Cluster

Gracefully shutdown the distributed cluster.

## Commands to Execute:
1. Stop accepting new jobs
2. Wait for active jobs to complete
3. Shutdown worker nodes
4. Stop driver and Redis
5. Save final status

## Safety Notes:
- Allows running jobs to complete
- Preserves all results
- Clean shutdown of all components
EOF

echo -e "${GREEN}✅ Cluster setup complete!${NC}"
echo ""
echo -e "${BLUE}🎯 Cluster Architecture:${NC}"
echo "======================"
echo "Driver (Mac M4):     Job scheduler, result collector, monitoring"
echo "Worker (i7 Node):    Backtest execution engine"
echo "Queue (Redis):       Job distribution and status tracking"
echo ""
echo -e "${YELLOW}🚀 Usage:${NC}"
echo "========"
echo ""
echo "Start Cluster:"
echo "  ./start_cluster.sh"
echo "  # or: 'start cluster' (ClaudBot)"
echo ""
echo "Submit Jobs:"
echo "  ./submit_job.sh"
echo "  ./submit_job.sh 'rsi,macd' 'RELIANCE,TCS' '2020-01-01' '2024-12-31'"
echo "  # or: 'submit cluster job' (ClaudBot)"
echo ""
echo "Monitor:"
echo "  ./monitor_cluster.sh"
echo "  # or: 'monitor cluster' (ClaudBot)"
echo ""
echo "Stop Cluster:"
echo "  ./stop_cluster.sh"
echo "  # or: 'stop cluster' (ClaudBot)"
echo ""
echo -e "${GREEN}📁 Results: cluster/driver/results/${NC}"
echo -e "${GREEN}📊 Logs: cluster/driver/logs/ and cluster/worker/logs/${NC}"
echo ""
echo -e "${BLUE}🎉 Distributed backtesting cluster ready!${NC}"
