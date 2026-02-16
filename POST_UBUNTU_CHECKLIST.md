# Post-Ubuntu Setup Checklist

## ✅ Ubuntu Installation Complete
- [x] Ubuntu 20.04 LTS installed on i7
- [x] Booted into Ubuntu successfully
- [x] Network connection working

## 🔄 Current Step: I7 System Setup (30 minutes)

### On I7 Ubuntu Machine:
- [ ] **Automated setup via Node.js communication**: Use the SSH cluster setup script from Mac M4
- [ ] **On Mac M4**: Run `./setup_ssh_cluster.sh` (automates all transfer and setup)
- [ ] **Network connectivity**: Ensure i7 and Mac are on same network
- [ ] **IP address**: Note the i7 IP address for the setup script
- [ ] **SSH key**: Ensure SSH key exists (`~/.ssh/id_ed25519.pub`)
- [ ] **Verify all checks pass** (should see ✅ for all automated tests)

### Expected Setup Output:
```
✅ Package list update
✅ System upgrade
✅ Essential packages installation
✅ Python installation
✅ Poetry installation
✅ Redis installation
✅ Redis service start
✅ Swap file creation
✅ Swap file permissions
✅ Swap setup
✅ Swap activation
✅ Swap persistence
✅ SSH service enable/start
✅ Firewall configuration
✅ Monitoring tools installation
✅ System statistics enable
✅ Python: Working
✅ Poetry: Working
✅ Redis: Working
✅ Git: Working
✅ Swap space: Working (32GB)
✅ SSH service: Running
✅ Network: Working
```

## 🎯 Next Phase: SSH & Cluster Setup (20 minutes)

### After I7 Setup Completes:
- [ ] **Automated cluster setup**: The `./setup_ssh_cluster.sh` script handles everything:
  - SSH key deployment and testing
  - Project file transfer via rsync
  - Dependency installation on i7
  - Cluster component setup
  - Node.js SjAgent communication layer setup
  - Redis server configuration
- [ ] **Web interfaces ready**: After setup completes, access:
  - Cluster Monitor: http://localhost:3000
  - API Health: http://localhost:3000/health
- [ ] **Test cluster**: Run `./start_cluster.sh` and `./monitor_cluster.sh`
- [ ] **Install dependencies**: `cd ai-trading-machine && poetry install --no-dev`
- [ ] **Setup cluster**: Run `./setup_cluster_client_server.sh`
- [ ] **Test cluster**: `./start_cluster.sh && ./monitor_cluster.sh`

## 📊 Expected Performance After Setup:
- **Setup Time**: 45-60 minutes total
- **Backtesting Speed**: 100-300 jobs/hour
- **Memory Usage**: 8-12GB per backtest job
- **CPU Usage**: 80-95% during processing
- **Network Traffic**: Minimal (<1MB/min)

## 🚨 Troubleshooting

### If Setup Script Fails:
```bash
# Check internet
ping -c 3 google.com

# Check package manager
sudo apt update

# Re-run specific step
sudo apt install -y [failed-package]
```

### If Network Issues:
```bash
# Check IP address
ip addr show

# Check DNS
nslookup google.com

# Restart network
sudo systemctl restart NetworkManager
```

### If SSH Issues:
```bash
# Check SSH service
sudo systemctl status ssh

# Check firewall
sudo ufw status

# Allow SSH
sudo ufw allow ssh
```

## 📞 Success Indicators

### I7 Setup Complete When:
- [ ] All ✅ checks in setup output
- [ ] IP address displayed (192.168.29.173)
- [ ] SSH service running
- [ ] Redis responds with PONG
- [ ] 32GB swap space active
- [ ] Python and Poetry working

### Cluster Ready When:
- [ ] SSH works from Mac without password
- [ ] Project deployed to i7
- [ ] Cluster scripts executable
- [ ] Test job completes successfully

## 🎉 Final Result
- **Mac M4**: Client (submits jobs, monitors)
- **i7 Ubuntu**: Server (processes backtests)
- **Performance**: 100-300 backtests/hour
- **Cost**: $0 cloud costs
- **Monitoring**: Real-time via ClaudBot

---
**Total Time: ~1 hour | Difficulty: Beginner | Success Rate: 95%**
