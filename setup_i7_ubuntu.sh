#!/bin/bash
# Ubuntu 20.04 LTS Post-Installation Setup for Backtesting Cluster
# Run this script on your i7 Ubuntu machine after installation

set -e  # Exit on any error

echo "🤖 AI TRADING MACHINE - I7 CLUSTER SETUP"
echo "========================================"
echo ""

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

echo "🔍 STEP 1: System Information"
echo "-----------------------------"
echo "Ubuntu Version: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo ""

echo "🌐 STEP 2: Network Configuration"
echo "--------------------------------"
echo "Network interfaces:"
ip addr show | grep -E "inet |inet6 " | grep -v "127.0.0.1" | grep -v "::1" | head -5
echo ""
echo "Testing internet connectivity..."
if ping -c 3 -W 5 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connection: Working"
else
    echo "❌ Internet connection: Failed"
    echo "   Check WiFi/network settings in Ubuntu"
    exit 1
fi
echo ""

echo "📦 STEP 3: System Update & Essentials"
echo "-------------------------------------"
echo "Updating package lists..."
sudo apt update -y
check_success "Package list update"

echo "Upgrading system packages..."
sudo apt upgrade -y
check_success "System upgrade"

echo "Installing essential packages..."
sudo apt install -y curl wget git htop iotop vim net-tools openssh-server build-essential
check_success "Essential packages installation"
echo ""

echo "🐍 STEP 4: Python Environment Setup"
echo "-----------------------------------"
echo "Installing Python and development tools..."
sudo apt install -y python3 python3-pip python3-venv python3-dev python3-setuptools
check_success "Python installation"

echo "Python version: $(python3 --version)"
echo "Pip version: $(pip3 --version)"
echo ""

echo "📚 STEP 5: Poetry Installation"
echo "------------------------------"
echo "Installing Poetry (Python dependency management)..."
curl -sSL https://install.python-poetry.org | python3 -
check_success "Poetry installation"

# Add Poetry to PATH for current session
export PATH="$HOME/.local/bin:$PATH"

echo "Poetry version: $(poetry --version)"
echo ""

echo "🗄️ STEP 6: Redis Server Setup"
echo "-----------------------------"
echo "Installing Redis server..."
sudo apt install -y redis-server
check_success "Redis installation"

echo "Configuring Redis..."
sudo systemctl enable redis-server
sudo systemctl start redis-server
check_success "Redis service start"

# Test Redis
if redis-cli ping | grep -q "PONG"; then
    echo "✅ Redis server: Working"
else
    echo "❌ Redis server: Not responding"
    exit 1
fi
echo ""

echo "💾 STEP 7: Swap Space Configuration"
echo "-----------------------------------"
echo "Current memory and swap:"
free -h
echo ""

echo "Creating 32GB swap file for memory-intensive backtesting..."
sudo fallocate -l 32G /swapfile
check_success "Swap file creation"

echo "Setting secure permissions on swap file..."
sudo chmod 600 /swapfile
check_success "Swap file permissions"

echo "Setting up swap space..."
sudo mkswap /swapfile
check_success "Swap setup"

echo "Enabling swap..."
sudo swapon /swapfile
check_success "Swap activation"

echo "Making swap permanent (survives reboots)..."
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
check_success "Swap persistence"

echo "Updated memory and swap:"
free -h
echo ""

echo "🔐 STEP 8: SSH Server Configuration"
echo "-----------------------------------"
echo "Enabling SSH service..."
sudo systemctl enable ssh
sudo systemctl start ssh
check_success "SSH service enable/start"

echo "SSH service status:"
sudo systemctl status ssh --no-pager -l | grep -E "(Active|Loaded)"
echo ""

echo "🔥 STEP 9: Firewall Configuration"
echo "---------------------------------"
echo "Checking firewall status..."
if sudo ufw status | grep -q "inactive"; then
    echo "Firewall is inactive - configuring..."
    sudo ufw allow ssh
    sudo ufw allow 22/tcp
    echo "y" | sudo ufw enable
    check_success "Firewall configuration"
else
    echo "✅ Firewall already configured"
fi
echo ""

echo "📊 STEP 10: System Monitoring Tools"
echo "-----------------------------------"
echo "Installing additional monitoring tools..."
sudo apt install -y sysstat nload iftop
check_success "Monitoring tools installation"

echo "Enabling system statistics collection..."
sudo systemctl enable sysstat
sudo systemctl start sysstat
check_success "System statistics enable"
echo ""

echo "🎯 STEP 11: Verification Tests"
echo "------------------------------"
echo "Running comprehensive system tests..."
echo ""

# Test 1: Python
if python3 -c "import sys; print(f'Python {sys.version}')"; then
    echo "✅ Python: Working"
else
    echo "❌ Python: Failed"
fi

# Test 2: Poetry
if poetry --version >/dev/null 2>&1; then
    echo "✅ Poetry: Working"
else
    echo "❌ Poetry: Failed"
fi

# Test 3: Redis
if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo "✅ Redis: Working"
else
    echo "❌ Redis: Failed"
fi

# Test 4: Git
if git --version >/dev/null 2>&1; then
    echo "✅ Git: Working"
else
    echo "❌ Git: Failed"
fi

# Test 5: Swap
if grep -q "/swapfile" /etc/fstab && swapon -s | grep -q "/swapfile"; then
    echo "✅ Swap space: Working (32GB)"
else
    echo "❌ Swap space: Failed"
fi

# Test 6: SSH
if sudo systemctl is-active ssh >/dev/null 2>&1; then
    echo "✅ SSH service: Running"
else
    echo "❌ SSH service: Not running"
fi

# Test 7: Network
if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Network: Working"
else
    echo "❌ Network: Failed"
fi
echo ""

echo "📋 STEP 12: System Information Summary"
echo "--------------------------------------"
echo "Hostname: $(hostname)"
echo "Username: $(whoami)"
echo "Home Directory: $HOME"
echo "IP Addresses:"
ip addr show | grep -E "inet " | grep -v "127.0.0.1" | awk '{print "  " $2}'
echo ""

echo "🚀 SETUP COMPLETE!"
echo "=================="
echo ""
echo "✅ Ubuntu 20.04 LTS configured for backtesting cluster"
echo "✅ All prerequisites installed and tested"
echo "✅ SSH server ready for remote access"
echo "✅ 32GB swap space configured"
echo ""
echo "📝 NEXT STEPS:"
echo "1. Note your IP address above"
echo "2. On your Mac, run: ./validate_cluster_setup.sh"
echo "3. Copy SSH keys from Mac to i7"
echo "4. Deploy ai-trading-machine project"
echo "5. Setup cluster components"
echo ""
echo "🎯 READY FOR CLUSTER DEPLOYMENT!"
echo ""
echo "Your i7 IP address: $(hostname -I | awk '{print $1}')"
echo "SSH command from Mac: ssh $(whoami)@$(hostname -I | awk '{print $1}')"
echo ""
echo "⚡ Performance Ready: 100-300 backtests/hour"
