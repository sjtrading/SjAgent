#!/bin/bash
# Mac M4 + i7 Cluster Validation Script
# Run this from your Mac terminal

I7_IP="192.168.29.173"
I7_USER="sivarajumalladi"

echo "🔍 VALIDATION: Mac M4 + i7 Backtesting Cluster"
echo "=============================================="
echo ""

echo "1️⃣ Testing Network Connectivity..."
echo "   Pinging i7 at $I7_IP..."
if ping -c 3 -t 5 $I7_IP >/dev/null 2>&1; then
    echo "   ✅ Network: i7 is reachable"
else
    echo "   ❌ Network: Cannot reach i7 at $I7_IP"
    echo "   🔧 Check: Is i7 powered on? Same network? Firewall blocking ping?"
    exit 1
fi
echo ""

echo "2️⃣ Testing SSH Connection..."
echo "   Connecting to i7 via SSH..."
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $I7_USER@$I7_IP "echo 'SSH test successful'" >/dev/null 2>&1; then
    echo "   ✅ SSH: Passwordless authentication working"
else
    echo "   ❌ SSH: Connection failed"
    echo "   🔧 Check: SSH keys copied? i7 SSH service running?"
    echo "   💡 Try: ssh-copy-id $I7_USER@$I7_IP"
    exit 1
fi
echo ""

echo "3️⃣ Checking i7 System Prerequisites..."
echo "   Testing Python, Poetry, Redis..."
SSH_TEST=$(ssh -o ConnectTimeout=5 $I7_USER@$I7_IP "
python3 --version >/dev/null 2>&1 && echo 'python3:OK' || echo 'python3:FAIL'
poetry --version >/dev/null 2>&1 && echo 'poetry:OK' || echo 'poetry:FAIL'
redis-cli ping 2>/dev/null | grep -q PONG && echo 'redis:OK' || echo 'redis:FAIL'
free -h | grep -q Swap && echo 'swap:OK' || echo 'swap:FAIL'
")

echo "$SSH_TEST" | while read line; do
    if [[ $line == *"OK" ]]; then
        echo "   ✅ ${line//:OK/} installed"
    else
        echo "   ❌ ${line//:FAIL/} missing"
    fi
done

# Count failures
FAIL_COUNT=$(echo "$SSH_TEST" | grep -c "FAIL")
if [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo "   🔧 Fix missing prerequisites on i7:"
    echo "      sudo apt update && sudo apt install python3 python3-pip python3-venv redis-server htop iotop"
    echo "      curl -sSL https://install.python-poetry.org | python3 -"
    echo "      sudo fallocate -l 32G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
    exit 1
fi
echo ""

echo "4️⃣ Checking Project Setup..."
echo "   Testing ai-trading-machine project on i7..."
PROJECT_TEST=$(ssh -o ConnectTimeout=5 $I7_USER@$I7_IP "
if [ -d ~/ai-trading-machine ]; then
    cd ~/ai-trading-machine
    if [ -f pyproject.toml ]; then echo 'project:OK'; else echo 'project:FAIL'; fi
    if poetry check >/dev/null 2>&1; then echo 'deps:OK'; else echo 'deps:FAIL'; fi
else
    echo 'project:MISSING'
fi
")

echo "$PROJECT_TEST" | while read line; do
    case $line in
        "project:OK")
            echo "   ✅ Project directory exists";;
        "project:MISSING")
            echo "   ❌ Project missing - clone repository to i7";;
        "project:FAIL")
            echo "   ❌ Project incomplete - missing pyproject.toml";;
        "deps:OK")
            echo "   ✅ Dependencies installed";;
        "deps:FAIL")
            echo "   ❌ Dependencies not installed - run 'poetry install' on i7";;
    esac
done

if echo "$PROJECT_TEST" | grep -q "MISSING\|FAIL"; then
    echo ""
    echo "   🔧 Setup project on i7:"
    echo "      git clone <your-repo> ~/ai-trading-machine"
    echo "      cd ~/ai-trading-machine && poetry install --no-dev"
    exit 1
fi
echo ""

echo "5️⃣ Testing Cluster Components..."
echo "   Checking cluster scripts..."
SCRIPT_TEST=$(ssh -o ConnectTimeout=5 $I7_USER@$I7_IP "
cd ~/ai-trading-machine 2>/dev/null || exit 1
[ -f setup_cluster_client_server.sh ] && echo 'setup_script:OK' || echo 'setup_script:MISSING'
[ -d cluster ] && echo 'cluster_dir:OK' || echo 'cluster_dir:MISSING'
[ -f cluster/driver/cluster_scheduler.py ] && echo 'scheduler:OK' || echo 'scheduler:MISSING'
[ -f cluster/worker/cluster_worker.py ] && echo 'worker:OK' || echo 'worker:MISSING'
")

echo "$SCRIPT_TEST" | while read line; do
    case $line in
        "setup_script:OK")
            echo "   ✅ Setup script present";;
        "setup_script:MISSING")
            echo "   ❌ Setup script missing - copy from Mac";;
        "cluster_dir:OK")
            echo "   ✅ Cluster directory exists";;
        "cluster_dir:MISSING")
            echo "   ❌ Cluster directory missing - run setup script";;
        "scheduler:OK")
            echo "   ✅ Scheduler component ready";;
        "scheduler:MISSING")
            echo "   ❌ Scheduler missing";;
        "worker:OK")
            echo "   ✅ Worker component ready";;
        "worker:MISSING")
            echo "   ❌ Worker missing";;
    esac
done

if echo "$SCRIPT_TEST" | grep -q "MISSING"; then
    echo ""
    echo "   🔧 Deploy cluster components:"
    echo "      Copy setup_cluster_client_server.sh to i7"
    echo "      Run: chmod +x setup_cluster_client_server.sh && ./setup_cluster_client_server.sh"
    exit 1
fi
echo ""

echo "🎉 VALIDATION COMPLETE!"
echo "======================"
echo "✅ Network connectivity: Working"
echo "✅ SSH authentication: Working"
echo "✅ System prerequisites: Installed"
echo "✅ Project setup: Complete"
echo "✅ Cluster components: Ready"
echo ""
echo "🚀 Ready to start cluster!"
echo "   Run: ./start_cluster.sh"
echo "   Monitor: ./monitor_cluster.sh"
echo "   Test: ./submit_job.sh 'rsi' 'RELIANCE' '2020-01-01' '2020-12-31'"
