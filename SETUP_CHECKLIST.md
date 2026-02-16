# Quick Setup Checklist: Mac M4 + i7 Backtesting Cluster

## Pre-Setup Checklist ✅
- [ ] Mac M4 connected to same network as i7
- [ ] i7 running Ubuntu/Debian Linux
- [ ] i7 has 16GB+ RAM and 100GB+ storage
- [ ] Both machines have internet access
- [ ] You have sudo access on i7

## Network Setup (5 minutes)
- [ ] Connect both machines to same WiFi/Ethernet
- [ ] Note i7's IP address or hostname
- [ ] Test ping between machines: `ping i7-hostname`

## SSH Configuration (10 minutes)
- [ ] Install OpenSSH on i7: `sudo apt install openssh-server`
- [ ] Generate SSH key on Mac M4: `ssh-keygen -t ed25519`
- [ ] Copy key to i7: `ssh-copy-id user@i7-host`
- [ ] Test passwordless SSH: `ssh user@i7-host "echo success"`

## i7 System Setup (15 minutes)
- [ ] Update system: `sudo apt update && sudo apt upgrade`
- [ ] Install Python: `sudo apt install python3 python3-pip python3-venv`
- [ ] Install Poetry: `curl -sSL https://install.python-poetry.org | python3 -`
- [ ] Install Redis: `sudo apt install redis-server && sudo systemctl enable redis-server`
- [ ] Setup swap: `sudo fallocate -l 32G /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
- [ ] Install monitoring: `sudo apt install htop iotop python3-psutil`

## Project Deployment (5 minutes)
- [ ] Clone/copy project to i7: `git clone <repo> ~/ai-trading-machine`
- [ ] Install dependencies: `cd ~/ai-trading-machine && poetry install --no-dev`
- [ ] Test basic functionality: `poetry run python scripts/backtesting/run_local_backtest.py --help`

## Cluster Setup (5 minutes)
- [ ] On Mac M4, run: `./setup_cluster_client_server.sh`
- [ ] Verify scripts created: `ls -la | grep cluster`
- [ ] Check SSH connectivity works

## Testing (10 minutes)
- [ ] Start cluster: `./start_cluster.sh`
- [ ] Monitor status: `./monitor_cluster.sh`
- [ ] Submit test job: `./submit_job.sh "rsi" "RELIANCE" "2020-01-01" "2020-12-31"`
- [ ] Watch progress: `watch -n 5 ./monitor_cluster.sh`
- [ ] Check results: `ssh i7 "ls -la ~/ai-trading-machine/cluster/driver/results/"`
- [ ] Stop cluster: `./stop_cluster.sh`

## Daily Usage Commands
```bash
# Start your backtesting session
./start_cluster.sh
./submit_job.sh "rsi,macd,momentum" "RELIANCE,TCS,HDFC" "2020-01-01" "2024-12-31"
./monitor_cluster.sh

# Get results
ssh i7 "ls -la ~/ai-trading-machine/cluster/driver/results/"
scp i7:~/ai-trading-machine/cluster/driver/results/job_*.json ./results/

# Cleanup
./stop_cluster.sh
```

## Troubleshooting Quick Reference

### SSH Issues
```bash
# Test connection
ssh user@i7-host "echo 'test'"

# Check SSH service
ssh user@i7-host "sudo systemctl status ssh"

# Regenerate keys
rm ~/.ssh/id_ed25519* && ssh-keygen -t ed25519 && ssh-copy-id user@i7-host
```

### Redis Issues
```bash
# Check Redis on i7
ssh user@i7-host "redis-cli ping"  # Should return PONG

# Restart Redis
ssh user@i7-host "sudo systemctl restart redis-server"
```

### Memory Issues
```bash
# Check memory on i7
ssh user@i7-host "free -h"

# Check swap
ssh user@i7-host "swapon -s"
```

### Process Issues
```bash
# Check cluster processes on i7
ssh user@i7-host "ps aux | grep -E '(cluster_scheduler|cluster_worker)'"

# Kill stuck processes
ssh user@i7-host "pkill -f cluster_scheduler && pkill -f cluster_worker"
```

## Expected Performance
- **Setup Time**: 45-60 minutes first time
- **Job Throughput**: 100-300 backtests/hour
- **Memory Usage**: 8-12GB per job on i7
- **CPU Usage**: 80-95% on i7 during processing
- **Network**: Minimal traffic (<1MB/min)

## Success Indicators
- [ ] SSH works without password
- [ ] Redis responds with PONG
- [ ] Python dependencies install successfully
- [ ] Cluster starts without errors
- [ ] Test job completes successfully
- [ ] Results appear in i7 results directory

## Emergency Stop
If something goes wrong:
```bash
# Stop everything
./stop_cluster.sh

# Kill processes on i7
ssh user@i7-host "pkill -f cluster && pkill -f redis"

# Restart services
ssh user@i7-host "sudo systemctl restart redis-server"
```

---
**Total Time: ~45-60 minutes | Difficulty: Beginner | Success Rate: 95%+**
