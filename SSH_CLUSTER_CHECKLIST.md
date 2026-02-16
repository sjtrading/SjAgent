# SSH & Cluster Setup Checklist

## ✅ Ubuntu Setup Complete
- [x] Ubuntu 20.04 LTS installed on i7
- [x] setup_i7_ubuntu.sh script run successfully
- [x] All system prerequisites installed
- [x] IP address noted (e.g., 192.168.29.173)

## 🔄 Current Phase: SSH & Cluster Setup (20 minutes)

### On Mac M4:
- [ ] **Navigate to project**: `cd ai-trading-machine`
- [ ] **Run automated setup**: `./setup_ssh_cluster.sh`
- [ ] **Enter i7 IP address** when prompted (from Ubuntu setup)
- [ ] **Wait for completion** (10-15 minutes)

### Automated Setup Does:
- [ ] SSH key validation
- [ ] Network connectivity test
- [ ] SSH key deployment to i7
- [ ] Passwordless SSH verification
- [ ] I7 system validation (Python, Poetry, Redis, swap)
- [ ] Project deployment to i7 via rsync
- [ ] Dependency installation on i7
- [ ] Cluster component setup
- [ ] Redis server start
- [ ] Final validation tests

### Expected Output:
```
✅ SSH key copied successfully
✅ SSH: Passwordless authentication working
✅ python3 ready
✅ poetry ready
✅ redis ready
✅ swap ready
✅ ssh ready
✅ memory ready
✅ Project files copied successfully
✅ Dependencies installation
✅ project verified
✅ src verified
✅ deps verified
✅ imports verified
✅ Cluster setup
✅ scheduler ready
✅ worker ready
✅ start ready
✅ monitor ready
✅ submit ready
✅ Redis: Responding correctly
✅ start executable
✅ monitor executable
✅ submit executable
```

## 🎯 Next Phase: Testing & First Backtest (10 minutes)

### After Setup Completes:
- [ ] **Start cluster**: `./start_cluster.sh`
- [ ] **Monitor status**: `./monitor_cluster.sh`
- [ ] **Submit test job**: `./submit_job.sh 'rsi' 'RELIANCE' '2020-01-01' '2020-12-31'`
- [ ] **Watch progress**: `./monitor_cluster.sh` (updates every 5 seconds)
- [ ] **Check results**: `ssh sivarajumalladi@[i7-ip] 'ls -la ~/ai-trading-machine/cluster/driver/results/'`

### Success Indicators:
- [ ] Cluster starts without errors
- [ ] Job submitted successfully
- [ ] Worker processes start on i7
- [ ] Results appear in results directory
- [ ] Performance: 100-300 backtests/hour

## 📊 Performance Expectations

### Cluster Performance:
- **Job Submission**: <1 second
- **Job Processing**: 10-30 seconds per backtest
- **Throughput**: 100-300 jobs/hour
- **Memory Usage**: 8-12GB per job on i7
- **CPU Usage**: 80-95% on i7 during processing

### Network Usage:
- **SSH Setup**: Minimal (<100KB)
- **Job Submission**: <1KB per job
- **Result Transfer**: <10KB per job
- **Monitoring**: <1KB/minute

## 🚨 Troubleshooting

### SSH Issues:
```bash
# Test SSH manually
ssh sivarajumalladi@[i7-ip] 'echo "test"'

# Copy keys manually
ssh-copy-id sivarajumalladi@[i7-ip]

# Check i7 SSH service
ssh sivarajumalladi@[i7-ip] 'sudo systemctl status ssh'
```

### Network Issues:
```bash
# Test connectivity
ping [i7-ip]

# Check i7 network
ssh sivarajumalladi@[i7-ip] 'ip addr show'
```

### Project Issues:
```bash
# Check project on i7
ssh sivarajumalladi@[i7-ip] 'ls -la ~/ai-trading-machine'

# Reinstall dependencies
ssh sivarajumalladi@[i7-ip] 'cd ~/ai-trading-machine && poetry install --no-dev'
```

### Cluster Issues:
```bash
# Check cluster components
ssh sivarajumalladi@[i7-ip] 'ls -la ~/ai-trading-machine/cluster/'

# Restart Redis
ssh sivarajumalladi@[i7-ip] 'sudo systemctl restart redis-server'

# Check Redis
ssh sivarajumalladi@[i7-ip] 'redis-cli ping'
```

## 📞 Emergency Commands

### If Setup Fails:
```bash
# Clean restart
./setup_ssh_cluster.sh  # Run again

# Manual project copy
rsync -avz ./ sivarajumalladi@[i7-ip]:~/ai-trading-machine/

# Manual dependency install
ssh sivarajumalladi@[i7-ip] 'cd ~/ai-trading-machine && poetry install --no-dev'
```

### If Cluster Won't Start:
```bash
# Kill existing processes
ssh sivarajumalladi@[i7-ip] 'pkill -f cluster'

# Restart Redis
ssh sivarajumalladi@[i7-ip] 'sudo systemctl restart redis-server'

# Start cluster manually
./start_cluster.sh
```

## 🎉 Final Result

### Successful Setup Provides:
- **Mac M4**: Job submission and monitoring client
- **i7 Ubuntu**: High-performance backtesting server
- **Performance**: 100-300 backtests/hour
- **Cost**: $0 cloud costs
- **Reliability**: Local, dedicated hardware
- **Monitoring**: Real-time status via scripts

### Daily Usage:
```bash
# Start your backtesting session
./start_cluster.sh
./submit_job.sh "rsi,macd,momentum" "RELIANCE,TCS,HDFC" "2020-01-01" "2024-12-31"
./monitor_cluster.sh

# Get results
ssh sivarajumalladi@[i7-ip] "ls -la ~/ai-trading-machine/cluster/driver/results/"
```

---
**Total Setup Time: 30 minutes | Daily Usage: 5 minutes | Performance: 100-300 jobs/hour**

**Ready to run `./setup_ssh_cluster.sh`?** 🚀