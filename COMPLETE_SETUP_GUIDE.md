# Complete Setup Guide: Mac M4 + i7 Thin Client Backtesting Cluster

## Overview
This guide will walk you through setting up a distributed backtesting cluster where your Mac M4 acts as the client (control interface) and your i7 thin client serves as the server (running both the cluster driver and worker). This is perfect for running memory-intensive backtesting without cloud costs.

**Time Required**: 45-60 minutes
**Difficulty**: Beginner to Intermediate
**Prerequisites**: Basic command line knowledge

## Table of Contents
1. [System Requirements](#system-requirements)
2. [Network Setup](#network-setup)
3. [SSH Configuration](#ssh-configuration)
4. [i7 Thin Client Setup](#i7-thin-client-setup)
5. [Project Deployment](#project-deployment)
6. [Cluster Configuration](#cluster-configuration)
7. [Testing & Verification](#testing--verification)
8. [Troubleshooting](#troubleshooting)
9. [Daily Operations](#daily-operations)

---

## System Requirements

### Mac M4 (Client Machine)
- **OS**: macOS 12.0 or later
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 10GB free space
- **Network**: Same local network as i7
- **Software**: Terminal application, internet connection

### i7 Thin Client (Server Machine)
- **OS**: Ubuntu 20.04 LTS or Debian 11 (or compatible Linux)
- **CPU**: Intel i7 or equivalent (4+ cores recommended)
- **RAM**: 16GB minimum (32GB recommended for large backtests)
- **Storage**: 100GB+ free space (SSD preferred)
- **Network**: Ethernet connection (WiFi may work but not recommended)

### Network Requirements
- Both machines on the same local network
- SSH access between machines
- No firewall blocking SSH (port 22)
- Stable network connection

---

## Network Setup

### Step 1: Connect Both Machines to Same Network
1. Ensure both Mac M4 and i7 are connected to the same WiFi network or Ethernet
2. Note the i7's IP address or hostname:
   ```bash
   # On i7, check IP address
   ip addr show | grep "inet " | grep -v 127.0.0.1
   # Or use hostname
   hostname
   ```

### Step 2: Test Basic Connectivity
```bash
# On Mac M4, ping the i7
ping 192.168.29.173  # Your Windows host IP address
# Or if using IP address:
ping 192.168.1.100  # Replace with actual IP
```

**Expected Result**: Successful ping responses (press Ctrl+C to stop)

---

## SSH Configuration

SSH (Secure Shell) allows secure communication between your Mac M4 and i7.

### Step 1: Install OpenSSH on i7 (if not installed)
```bash
# On i7, install SSH server
sudo apt update
sudo apt install -y openssh-server

# Start and enable SSH service
sudo systemctl start ssh
sudo systemctl enable ssh

# Check SSH status
sudo systemctl status ssh
```

### Step 2: Create SSH Key Pair on Mac M4
```bash
# On Mac M4, generate SSH key
ssh-keygen -t ed25519 -C "backtesting-cluster@mac-m4"

# Press Enter for all prompts (use default locations)
```

### Step 3: SSH Key Setup (Automated)
```bash
# SSH key copying is now automated by the setup script
# The ./setup_ssh_cluster.sh script handles this automatically
# No manual ssh-copy-id needed!
```

### Step 4: Test SSH Connection (Automated)
```bash
# SSH testing is also automated by the setup script
# Run ./setup_ssh_cluster.sh to test everything automatically
```
ssh backtest@192.168.29.173 "whoami && pwd"
```

**Expected Result**: Successful connection without password prompt

### Step 5: Configure SSH for Better Performance (Optional)
```bash
# On Mac M4, create SSH config for easier connections
echo "
Host i7
    HostName 192.168.29.173
    User backtest
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
" >> ~/.ssh/config

# Test the alias
ssh i7 "echo 'Connected via alias'"
```

---

## i7 Thin Client Setup

### Step 1: Update System
```bash
# On i7, update package lists and upgrade system
sudo apt update
sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git htop iotop sysstat vim nano
```

### Step 2: Install Python 3.8+
```bash
# Check current Python version
python3 --version

# Install Python 3.8+ if needed
sudo apt install -y python3 python3-pip python3-venv python3-dev

# Install pip for Python 3
sudo apt install -y python3-pip

# Verify installation
python3 --version
pip3 --version
```

### Step 3: Install Poetry (Python Package Manager)
```bash
# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# Add Poetry to PATH (add to ~/.bashrc if needed)
export PATH="$HOME/.local/bin:$PATH"

# Verify installation
poetry --version
```

### Step 4: Install Redis (Job Queue)
```bash
# Install Redis server
sudo apt install -y redis-server

# Start and enable Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test Redis
redis-cli ping
```

**Expected Result**: `PONG`

### Step 5: Setup Swap Space (Memory Optimization)
```bash
# Check current swap
free -h

# Create 32GB swap file
sudo fallocate -l 32G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify swap
free -h
```

**Expected Result**: 32GB+ swap space available

### Step 6: Install System Monitoring Tools
```bash
# Install additional monitoring tools
sudo apt install -y python3-psutil lm-sensors

# Test monitoring
python3 -c "import psutil; print(f'CPU: {psutil.cpu_percent()}%, Memory: {psutil.virtual_memory().percent}%')"
```

### Step 7: Configure System Limits (Optional but Recommended)
```bash
# Increase file limits for better performance
echo "
* soft nofile 65536
* hard nofile 65536
" | sudo tee -a /etc/security/limits.conf

# Configure sysctl for better memory management
echo "
vm.swappiness = 10
vm.vfs_cache_pressure = 50
" | sudo tee -a /etc/sysctl.conf

# Apply sysctl changes
sudo sysctl -p
```

---

## Project Deployment

### Automated Setup via Node.js Communication Layer

**Skip manual setup** - Use the automated SSH cluster setup script instead:

```bash
# On Mac M4, run the automated setup (handles everything)
./setup_ssh_cluster.sh

# This script will:
# - Deploy SSH keys automatically
# - Transfer project files via rsync
# - Install dependencies on i7
# - Setup cluster components
# - Configure Node.js SjAgent communication layer
# - Start Redis server
```

### Manual Setup (Alternative - Not Recommended)

If you prefer manual setup, follow these steps on the i7:

#### Step 1: Clone Repository on i7
```bash
# On i7, create project directory
mkdir -p ~/ai-trading-machine
cd ~/ai-trading-machine

# Clone the repository (replace with your repo URL)
git clone https://github.com/yourusername/ai-trading-machine.git .

# If you have the code locally, copy it via SCP
# scp -r /path/to/local/project backtest@192.168.29.173:~/
```

#### Step 2: Install Python Dependencies
```bash
# On i7, navigate to project directory
cd ~/ai-trading-machine

# Install dependencies with Poetry
poetry install --no-dev

# Verify installation
poetry run python --version
poetry run python -c "import numpy, pandas; print('Dependencies OK')"
```

#### Step 3: Configure Project
```bash
# Copy configuration files if needed
cp config/universe_symbols.json config/universe_symbols.json.backup 2>/dev/null || echo "No universe config found"

# Check if config files exist
ls -la config/
```

#### Step 4: Test Basic Functionality
```bash
# Test basic imports
poetry run python -c "
import sys
sys.path.append('src')
from domain.backtesting.backtest_config import BacktestConfig
print('✅ Basic imports working')
"

# Test backtesting script
poetry run python scripts/backtesting/run_local_backtest.py --help
```

---

## Cluster Configuration

### Step 1: Run Cluster Setup from Mac M4
```bash
# On Mac M4, navigate to project directory
cd /path/to/your/ai-trading-machine

# Run the cluster setup script
./setup_cluster_client_server.sh
```

### Step 2: Verify Setup
```bash
# Check that scripts were created
ls -la | grep -E "(start|stop|monitor|submit)_cluster"

# Check ClaudBot configuration
cat claudbot/config/intent_patterns.yaml | grep -A 5 "start_cluster"
```

### Step 3: Configure Environment Variables (Optional)
```bash
# On Mac M4, set environment variables if needed
export WORKER_HOST="192.168.29.173"  # Your Windows host IP address
export WORKER_USER="backtest"              # SSH username
export CLUSTER_PORT="6379"                 # Redis port

# Or create a .env file
echo "
WORKER_HOST=192.168.29.173
WORKER_USER=backtest
CLUSTER_PORT=6379
" > .env
```

---

## Testing & Verification

### Step 1: Start the Cluster
```bash
# On Mac M4, start the cluster on i7
./start_cluster.sh
```

**Expected Output**:
```
🚀 Starting Backtesting Cluster on i7 Server...
===============================================
Started driver (PID: 1234)
Started worker (PID: 5678)
✅ Cluster started on i7 server!
```

### Step 2: Monitor Cluster Status
```bash
# Check cluster status
./monitor_cluster.sh
```

**Expected Output**:
```
📊 Backtesting Cluster Status (i7 Server)
=======================================
Time: [current time]

🔄 Processes on i7:
✅ Driver: Running
✅ Worker: Running
✅ Redis: Running

📈 Cluster Metrics:
Workers: 1
Active Jobs: 0
Pending Jobs: 0
CPU: 5.2%
Memory: 15.3%
```

### Step 3: Submit Test Job
```bash
# Submit a small test job
./submit_job.sh "rsi" "RELIANCE" "2020-01-01" "2020-12-31"
```

### Step 4: Monitor Job Progress
```bash
# Watch progress
watch -n 5 ./monitor_cluster.sh
```

### Step 5: Check Results
```bash
# Check if results were created on i7
ssh i7 "ls -la ~/ai-trading-machine/cluster/driver/results/"
```

### Step 6: Stop the Cluster
```bash
# Gracefully stop the cluster
./stop_cluster.sh
```

---

## Troubleshooting

### SSH Connection Issues
```bash
# Test basic connectivity
ping 192.168.29.173

# Check SSH service on i7
ssh i7 "sudo systemctl status ssh"

# Regenerate SSH keys if needed
rm ~/.ssh/id_ed25519*
ssh-keygen -t ed25519 -C "backtesting-cluster@mac-m4"
ssh-copy-id backtest@192.168.29.173
```

### Redis Issues
```bash
# Check Redis status on i7
ssh i7 "sudo systemctl status redis-server"

# Test Redis connectivity
ssh i7 "redis-cli ping"

# Restart Redis if needed
ssh i7 "sudo systemctl restart redis-server"
```

### Python/Poetry Issues
```bash
# Check Python version on i7
ssh i7 "python3 --version"

# Reinstall Poetry if needed
ssh i7 "curl -sSL https://install.python-poetry.org | python3 -"

# Reinstall dependencies
ssh i7 "cd ~/ai-trading-machine && poetry install --no-dev"
```

### Memory Issues
```bash
# Check memory usage on i7
ssh i7 "free -h"

# Check swap usage
ssh i7 "swapon -s"

# Monitor processes
ssh i7 "htop"
```

### Permission Issues
```bash
# Fix permissions on i7
ssh i7 "chmod +x ~/ai-trading-machine/cluster/driver/cluster_scheduler.py"
ssh i7 "chmod +x ~/ai-trading-machine/cluster/worker/cluster_worker.py"

# Check file ownership
ssh i7 "ls -la ~/ai-trading-machine/cluster/"
```

### Network Issues
```bash
# Check network configuration
ssh i7 "ip addr show"

# Test DNS resolution
ssh i7 "nslookup google.com"

# Check firewall
ssh i7 "sudo ufw status"
```

---

## Daily Operations

### Starting Your Workflow
```bash
# 1. Start the cluster
./start_cluster.sh

# 2. Submit jobs
./submit_job.sh "rsi,macd,momentum" "RELIANCE,TCS,HDFC,INFY" "2020-01-01" "2024-12-31"

# 3. Monitor progress
./monitor_cluster.sh

# 4. Check results
ssh i7 "ls -la ~/ai-trading-machine/cluster/driver/results/"
```

### Using ClaudBot (Optional)
If you have ClaudBot set up:
```
"start cluster"              # Launch cluster
"submit cluster job"         # Submit backtest
"monitor cluster"            # Check status
"stop cluster"               # Shutdown
```

### Retrieving Results (Automated via Node.js)
```bash
# Results are automatically available through the Node.js communication layer:
# - Web Dashboard: http://localhost:3000 (real-time results)
# - REST API: http://localhost:3000/api/jobs (JSON results)
# - WebSocket: Real-time result streaming

# Manual retrieval (if needed):
scp backtest@172.18.93.7:~/ai-trading-machine/cluster/driver/results/job_*.json ./results/

# Or view results directly on i7
ssh i7 "cat ~/ai-trading-machine/cluster/driver/results/job_*.json | head -50"
```

### Maintenance Tasks
```bash
# Update system on i7
ssh i7 "sudo apt update && sudo apt upgrade -y"

# Clean old results (keep last 10)
ssh i7 "cd ~/ai-trading-machine/cluster/driver/results && ls -t | tail -n +11 | xargs rm -f"

# Check disk space
ssh i7 "df -h"

# Monitor logs
ssh i7 "tail -50 ~/ai-trading-machine/cluster/driver/logs/cluster_driver.log"
```

---

## Performance Optimization

### Memory Management
- The system uses chunked processing to prevent memory exhaustion
- 32GB swap space provides additional virtual memory
- Monitor memory usage with `htop` on i7

### CPU Optimization
- Worker is configured for 4 concurrent jobs (adjustable)
- CPU affinity can be set for consistent performance
- Monitor CPU usage during backtests

### Network Optimization
- Use Ethernet instead of WiFi for better stability
- SSH connection multiplexing reduces latency
- Results are compressed for faster transfer

### Storage Optimization
- Use SSD storage on i7 for better I/O performance
- Regular cleanup of old results and logs
- Monitor disk usage to prevent space issues

---

## Security Considerations

### SSH Security
- Use strong SSH keys (Ed25519 recommended)
- Disable password authentication after key setup
- Regularly rotate SSH keys

### Network Security
- Keep both machines on private network
- Use firewall rules to restrict access
- Monitor for unauthorized access attempts

### Data Security
- Results contain sensitive trading data
- Use encrypted connections for data transfer
- Regularly backup important results

---

## Support and Resources

### Log Files
```bash
# Driver logs (on i7)
ssh i7 "tail -f ~/ai-trading-machine/cluster/driver/logs/cluster_driver.log"

# Worker logs (on i7)
ssh i7 "tail -f ~/ai-trading-machine/cluster/worker/logs/worker_*.log"

# System logs
ssh i7 "sudo journalctl -u redis-server -f"
```

### Common Issues
1. **SSH connection fails**: Check network connectivity and SSH service
2. **Redis not responding**: Restart Redis service on i7
3. **Jobs not processing**: Check cluster status and worker processes
4. **Memory errors**: Monitor RAM usage and increase swap if needed
5. **Permission denied**: Fix file permissions on i7

### Getting Help
1. Check the troubleshooting section above
2. Review log files for error messages
3. Test individual components (SSH, Redis, Python)
4. Verify all prerequisites are installed

---

## Summary

You now have a complete distributed backtesting cluster:

- **Mac M4**: Client interface for job submission and monitoring
- **i7 Thin Client**: Server running driver + worker for backtest execution
- **Redis**: Job queue for distributed processing
- **SSH**: Secure communication between machines

**Next Steps**:
1. Run `./setup_cluster_client_server.sh` on Mac M4
2. Start with `./start_cluster.sh`
3. Submit your first job with `./submit_job.sh`
4. Monitor progress with `./monitor_cluster.sh`

The system is designed to handle memory-intensive backtesting workloads while keeping your Mac M4 responsive for other tasks. Enjoy your new distributed computing setup! 🚀
