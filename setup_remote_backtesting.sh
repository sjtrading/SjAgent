#!/bin/bash
# Remote Backtesting Setup - i7 Thin Client from Mac M4
# Control backtesting on remote i7 machine via SSH and ClaudBot

set -e

echo "🔗 Setting up Remote Backtesting (Mac M4 → i7 Thin Client)"
echo "=========================================================="

# Configuration
I7_HOST=${I7_HOST:-"i7-thin-client.local"}  # Change this to your i7's IP/hostname
I7_USER=${I7_USER:-"backtest"}             # User on i7 machine
PROJECT_PATH=${PROJECT_PATH:-"/home/$I7_USER/ai-trading-machine"}

# Test SSH connection
echo "🔑 Testing SSH connection to i7 thin client..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$I7_USER@$I7_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "❌ SSH connection failed. Please ensure:"
    echo "   1. SSH key authentication is set up"
    echo "   2. i7 machine is accessible at $I7_HOST"
    echo "   3. User $I7_USER exists on i7 machine"
    echo ""
    echo "Setup SSH keys if needed:"
    echo "   ssh-keygen -t ed25519 -C 'backtesting@mac-m4'"
    echo "   ssh-copy-id $I7_USER@$I7_HOST"
    exit 1
fi

echo "✅ SSH connection verified"

# Create remote setup script
cat > remote_setup.sh << EOF
#!/bin/bash
# Setup script to run on i7 thin client

set -e

echo "🚀 Setting up i7 Thin Client for Backtesting"
echo "==========================================="

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \\
    htop iotop sysstat python3-psutil \\
    python3-pip python3-venv \\
    git curl wget \\
    build-essential

# Setup Python environment
echo "🐍 Setting up Python environment..."
cd $PROJECT_PATH

# Install Poetry if not present
if ! command -v poetry &> /dev/null; then
    curl -sSL https://install.python-poetry.org | python3 -
    export PATH="\$HOME/.local/bin:\$PATH"
fi

# Install dependencies
poetry install --no-dev

# Setup directories
mkdir -p logs results temp/backtest_chunks

# Setup swap space
echo "💾 Setting up swap space..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 32G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "✅ 32GB swap space enabled"
fi

# Create remote monitoring script
cat > monitor_remote.sh << 'REMOTE_EOF'
#!/bin/bash
# Remote monitoring script for i7 thin client

echo "📊 i7 Thin Client Status - $(date)"
echo "=================================="

echo "🔄 Backtest Processes:"
ps aux | grep -E "run_local_backtest|run_standardized_backtest" | grep -v grep | \\
    awk '{print "  PID " $2 ": " $13 " (Runtime: " $10 ")"}' || echo "  No active backtests"

echo ""
echo "💾 System Resources:"
echo "  CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2 " (" $4 " free)"}')"
echo "  Swap: $(free -h | grep '^Swap:' | awk '{print $3 "/" $2}')"
echo "  Disk: $(df -h . | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"

echo ""
echo "📁 Recent Results:"
ls -la results/local_backtest_* 2>/dev/null | head -3 || echo "  No results yet"

echo ""
echo "📋 Recent Logs:"
tail -5 logs/local_backtest.log 2>/dev/null || echo "  No log file yet"
REMOTE_EOF

chmod +x monitor_remote.sh

# Create remote backtest runner
cat > run_backtest_remote.sh << 'REMOTE_EOF'
#!/bin/bash
# Remote backtest runner for i7 thin client

STRATEGIES=${1:-"rsi,macd,momentum"}
SYMBOLS=${2:-"RELIANCE,HDFC,TCS,INFY"}
START_DATE=${3:-"2020-01-01"}
END_DATE=${4:-"2024-12-31"}
WORKERS=${5:-4}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="results/local_backtest_\${TIMESTAMP}.json"

echo "🎯 Starting Remote Backtest on i7 Thin Client"
echo "=============================================="
echo "Strategies: \$STRATEGIES"
echo "Symbols: \$SYMBOLS"
echo "Date Range: \$START_DATE to \$END_DATE"
echo "Workers: \$WORKERS"
echo "Output: \$OUTPUT_FILE"
echo ""

# Run backtest
poetry run python scripts/backtesting/run_local_backtest.py \\
    --strategies \$STRATEGIES \\
    --symbols \$SYMBOLS \\
    --start-date \$START_DATE \\
    --end-date \$END_DATE \\
    --max-workers \$WORKERS \\
    --output \$OUTPUT_FILE

echo ""
echo "✅ Backtest completed! Results saved to \$OUTPUT_FILE"
REMOTE_EOF

chmod +x run_backtest_remote.sh

echo "✅ i7 Thin Client setup complete!"
echo ""
echo "🎯 Remote Usage:"
echo "================"
echo "From your Mac M4:"
echo "  ./remote_run_backtest.sh              # Quick run"
echo "  ./remote_monitor.sh                   # Check status"
echo "  ./remote_get_results.sh              # Download results"
echo ""
echo "Or use ClaudBot commands:"
echo "  'start remote backtest'              # Launch batch"
echo "  'monitor remote backtest'            # Check status"
echo "  'get remote results'                 # Download latest"
EOF

# Copy setup script to i7 machine
echo "📤 Copying setup script to i7 machine..."
scp remote_setup.sh "$I7_USER@$I7_HOST:~/"

# Run setup on i7 machine
echo "⚙️ Running setup on i7 thin client..."
ssh "$I7_USER@$I7_HOST" "chmod +x remote_setup.sh && ./remote_setup.sh"

# Create local control scripts
echo "💻 Creating local control scripts on Mac M4..."

cat > remote_run_backtest.sh << EOF
#!/bin/bash
# Control script on Mac M4 to run backtests on i7 thin client

STRATEGIES=\${1:-"rsi,macd,momentum"}
SYMBOLS=\${2:-"RELIANCE,HDFC,TCS,INFY"}
START_DATE=\${3:-"2020-01-01"}
END_DATE=\${4:-"2024-12-31"}
WORKERS=\${5:-4}

echo "🚀 Launching backtest on i7 thin client..."
echo "Strategies: \$STRATEGIES"
echo "Symbols: \$SYMBOLS"
echo "Date Range: \$START_DATE to \$END_DATE"
echo "Workers: \$WORKERS"
echo ""

ssh "$I7_USER@$I7_HOST" "cd $PROJECT_PATH && ./run_backtest_remote.sh '\$STRATEGIES' '\$SYMBOLS' '\$START_DATE' '\$END_DATE' '\$WORKERS'"

echo ""
echo "📊 Use './remote_monitor.sh' to check progress"
echo "📁 Use './remote_get_results.sh' to download results"
EOF

cat > remote_monitor.sh << EOF
#!/bin/bash
# Monitor backtest progress on i7 thin client from Mac M4

echo "📊 Remote Backtest Status (i7 Thin Client)"
echo "=========================================="
echo "Host: $I7_HOST"
echo "User: $I7_USER"
echo "Time: \$(date)"
echo ""

ssh "$I7_USER@$I7_HOST" "cd $PROJECT_PATH && ./monitor_remote.sh"
EOF

cat > remote_get_results.sh << EOF
#!/bin/bash
# Download latest results from i7 thin client

echo "📁 Downloading latest results from i7 thin client..."

# Find latest result file
LATEST_RESULT=\$(ssh "$I7_USER@$I7_HOST" "cd $PROJECT_PATH && ls -t results/local_backtest_*.json 2>/dev/null | head -1")

if [ -z "\$LATEST_RESULT" ]; then
    echo "❌ No result files found on remote machine"
    exit 1
fi

echo "Found latest result: \$LATEST_RESULT"

# Download file
LOCAL_FILE="results/\$(basename \$LATEST_RESULT)"
scp "$I7_USER@$I7_HOST:$PROJECT_PATH/\$LATEST_RESULT" "\$LOCAL_FILE"

echo "✅ Downloaded to: \$LOCAL_FILE"
echo "📊 File size: \$(ls -lh \$LOCAL_FILE | awk '{print \$5}')"
EOF

cat > remote_stop_backtest.sh << EOF
#!/bin/bash
# Emergency stop for remote backtests

echo "🛑 Stopping all backtest processes on i7 thin client..."

ssh "$I7_USER@$I7_HOST" "pkill -f run_local_backtest; pkill -f run_standardized_backtest"

echo "✅ Backtest processes stopped"
EOF

# Make scripts executable
chmod +x remote_*.sh

# Update ClaudBot configuration for remote commands
echo "🤖 Updating ClaudBot for remote backtesting..."

# Add remote backtesting intents to ClaudBot
REMOTE_INTENTS='
  start_remote_backtest:
    patterns:
      - "start.*remote.*backtest"
      - "run.*remote.*backtest"
      - "launch.*remote.*backtest"
    template: "start_remote_backtest.md"
    priority: "medium"
    safe_auto_execute: false
    requires_approval: true
    default_params:
      strategies: "rsi,macd,momentum"
      symbols: "RELIANCE,HDFC,TCS,INFY"
      start_date: "2020-01-01"
      end_date: "2024-12-31"
      workers: "4"
    commands:
      - cmd: "./remote_run_backtest.sh {STRATEGIES} {SYMBOLS} {START_DATE} {END_DATE} {WORKERS}"

  monitor_remote_backtest:
    patterns:
      - "monitor.*remote.*backtest"
      - "check.*remote.*backtest"
      - "remote.*backtest.*status"
    template: "monitor_remote_backtest.md"
    priority: "high"
    safe_auto_execute: true
    required_params: []
    commands:
      - cmd: "./remote_monitor.sh"

  get_remote_results:
    patterns:
      - "get.*remote.*results"
      - "download.*remote.*results"
      - "fetch.*remote.*backtest"
    template: "get_remote_results.md"
    priority: "medium"
    safe_auto_execute: true
    required_params: []
    commands:
      - cmd: "./remote_get_results.sh"

  stop_remote_backtest:
    patterns:
      - "stop.*remote.*backtest"
      - "kill.*remote.*backtest"
      - "terminate.*remote.*backtest"
    template: "stop_remote_backtest.md"
    priority: "high"
    safe_auto_execute: true
    required_params: []
    commands:
      - cmd: "./remote_stop_backtest.sh"
'

# Append to existing intent patterns
echo "$REMOTE_INTENTS" >> claudbot/config/intent_patterns.yaml

# Create templates for remote commands
cat > claudbot/templates/start_remote_backtest.md << 'EOF'
# Start Remote Backtest

Launch backtesting batch on i7 thin client from Mac M4.

## Parameters:
- strategies: Comma-separated strategy names (default: rsi,macd,momentum)
- symbols: Comma-separated symbols (default: RELIANCE,HDFC,TCS,INFY)
- start_date: Start date (default: 2020-01-01)
- end_date: End date (default: 2024-12-31)
- workers: Max workers (default: 4)

## Commands to Execute:
1. SSH to i7 thin client
2. Launch optimized backtest
3. Monitor via separate command

## Resource Requirements:
- i7 Thin Client: 16GB RAM, 4 CPU cores
- Network: Stable SSH connection
- Storage: 50GB+ available

## Safety Notes:
- Requires manual approval due to resource usage
- Monitor with "monitor remote backtest"
- Emergency stop with "stop remote backtest"
EOF

cat > claudbot/templates/monitor_remote_backtest.md << 'EOF'
# Monitor Remote Backtest

Check status of backtesting running on i7 thin client.

## Commands to Execute:
1. SSH to i7 thin client
2. Check running processes
3. Monitor system resources
4. Show recent logs

## Expected Output:
- Active backtest processes
- CPU/Memory usage
- Recent log entries
- Available results
EOF

cat > claudbot/templates/get_remote_results.md << 'EOF'
# Get Remote Results

Download latest backtest results from i7 thin client.

## Commands to Execute:
1. Find latest result file on remote
2. Download via SCP
3. Verify download success

## Output:
- Local path to downloaded results
- File size and timestamp
EOF

cat > claudbot/templates/stop_remote_backtest.md << 'EOF'
# Stop Remote Backtest

Emergency stop all backtest processes on i7 thin client.

## Commands to Execute:
1. SSH to i7 thin client
2. Kill backtest processes
3. Confirm termination

## Safety Notes:
- Gracefully terminates running processes
- Preserves completed results
- Use for emergency situations
EOF

echo "✅ Remote backtesting setup complete!"
echo ""
echo "🎯 Usage from Mac M4:"
echo "===================="
echo ""
echo "Direct Commands:"
echo "  ./remote_run_backtest.sh              # Launch backtest"
echo "  ./remote_monitor.sh                   # Check status"
echo "  ./remote_get_results.sh               # Download results"
echo "  ./remote_stop_backtest.sh             # Emergency stop"
echo ""
echo "ClaudBot Commands:"
echo "  'start remote backtest'               # Launch batch"
echo "  'monitor remote backtest'             # Check status"
echo "  'get remote results'                  # Download latest"
echo "  'stop remote backtest'                # Emergency stop"
echo ""
echo "📊 Monitoring:"
echo "=============="
echo "- Use './remote_monitor.sh' for real-time status"
echo "- ClaudBot sends Telegram notifications"
echo "- Results auto-downloaded on completion"
echo ""
echo "🔧 Configuration:"
echo "================="
echo "Edit these variables in remote_setup.sh if needed:"
echo "  I7_HOST=$I7_HOST"
echo "  I7_USER=$I7_USER"
echo "  PROJECT_PATH=$PROJECT_PATH"
echo ""
echo "🚀 Ready to run remote backtesting! 🎉"