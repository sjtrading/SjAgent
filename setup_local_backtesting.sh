#!/bin/bash
# Local Backtesting Setup Script - Optimized for i7/16GB, Zero Cloud Cost
# Integrates with ClaudBot for monitoring and control

set -e

echo "🚀 Setting up Local Backtesting Environment (i7/16GB Optimized)"
echo "============================================================"

# Create necessary directories
mkdir -p logs results temp/backtest_chunks

# Setup swap space for memory management
echo "💾 Setting up swap space for memory management..."
if [ ! -f /swapfile ]; then
    sudo fallocate -l 32G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "✅ 32GB swap space enabled"
else
    echo "✅ Swap space already configured"
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y htop iotop sysstat python3-psutil

# Setup Python environment
echo "🐍 Setting up Python environment..."
poetry install --no-dev

# Configure ClaudBot for backtesting monitoring
echo "🤖 Configuring ClaudBot for backtesting monitoring..."

# Start ClaudBot services
echo "🔄 Starting ClaudBot monitoring services..."
poetry run python claudbot/agent_watcher.py &
echo $! > temp/claudbot_watcher.pid

poetry run python claudbot/telegram_bot.py &
echo $! > temp/claudbot_telegram.pid

echo "✅ ClaudBot services started"

# Create convenience scripts
cat > run_backtest_local.sh << 'EOF'
#!/bin/bash
# Convenience script for running local backtests

STRATEGIES=${1:-"rsi,macd,momentum,bollinger_bands"}
SYMBOLS=${2:-"RELIANCE,HDFC,TCS,INFY"}
START_DATE=${3:-"2020-01-01"}
END_DATE=${4:-"2024-12-31"}
WORKERS=${5:-4}

echo "🎯 Starting Local Backtest"
echo "Strategies: $STRATEGIES"
echo "Symbols: $SYMBOLS"
echo "Date Range: $START_DATE to $END_DATE"
echo "Workers: $WORKERS"
echo ""

poetry run python scripts/backtesting/run_local_backtest.py \
    --strategies $STRATEGIES \
    --symbols $SYMBOLS \
    --start-date $START_DATE \
    --end-date $END_DATE \
    --max-workers $WORKERS \
    --telegram-notifications \
    --output results/local_backtest_$(date +%Y%m%d_%H%M%S).json
EOF

chmod +x run_backtest_local.sh

cat > monitor_backtest.sh << 'EOF'
#!/bin/bash
# Monitor backtest progress

echo "📊 Backtest Monitoring Dashboard"
echo "================================"

echo "🔄 Running Processes:"
ps aux | grep -E "run_local_backtest|run_standardized_backtest" | grep -v grep | \
    awk '{print "  PID " $2 ": " $13 " (Runtime: " $10 ")"}' || echo "  No backtest processes running"

echo ""
echo "📈 Recent Performance:"
tail -10 logs/local_backtest.log 2>/dev/null || echo "  No log file found"

echo ""
echo "💾 System Resources:"
echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
echo "  CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo "  Disk: $(df -h . | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"

echo ""
echo "📁 Results:"
ls -la results/local_backtest_* 2>/dev/null | head -5 || echo "  No results found"
EOF

chmod +x monitor_backtest.sh

# Create systemd service for automated monitoring (optional)
cat > backtest-monitor.service << 'EOF'
[Unit]
Description=Local Backtest Monitor
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/Documents/GitHub/ai-trading-machine
ExecStart=/usr/bin/bash -c 'while true; do ./monitor_backtest.sh >> logs/monitor.log 2>&1; sleep 300; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Setup complete!"
echo ""
echo "🎯 Usage Examples:"
echo "=================="
echo ""
echo "1. Quick backtest:"
echo "   ./run_backtest_local.sh"
echo ""
echo "2. Custom backtest:"
echo "   ./run_backtest_local.sh 'rsi,macd' 'RELIANCE,TCS' '2023-01-01' '2024-12-31' 2"
echo ""
echo "3. Monitor progress:"
echo "   ./monitor_backtest.sh"
echo ""
echo "4. ClaudBot commands:"
echo "   - 'monitor backtest' - Check status"
echo "   - 'start local backtest' - Launch batch"
echo "   - 'stop backtest' - Emergency stop"
echo "   - 'optimize backtest memory' - Memory tips"
echo ""
echo "5. Telegram notifications:"
echo "   - Automatic progress updates every 5 minutes"
echo "   - Completion/failure alerts"
echo "   - Performance summaries"
echo ""
echo "💡 Memory Optimization Tips:"
echo "============================"
echo "- Use 2-4 workers max for i7"
echo "- Process in chunks of 25-50 strategies"
echo "- Monitor with htop during runs"
echo "- 32GB swap prevents out-of-memory crashes"
echo ""
echo "🚨 Emergency Controls:"
echo "======================"
echo "- Ctrl+C in terminal to stop current run"
echo "- 'stop backtest' via ClaudBot"
echo "- pkill -f run_local_backtest"
echo ""
echo "Ready to run backtests locally! 🎉"
