# Ubuntu 20.04 LTS Installation Quick Checklist

## ⏰ Pre-Installation (15 minutes)
- [ ] Download Ubuntu 20.04 LTS Desktop ISO (3GB)
- [ ] Prepare 8GB+ USB drive (will be erased)
- [ ] Backup important Windows data
- [ ] Know BIOS key for your PC (F2/F10/Del/Esc)

## 🛠️ Create Bootable USB (10 minutes)
- [ ] Download Rufus (https://rufus.ie/)
- [ ] Insert USB drive
- [ ] Run Rufus as Administrator
- [ ] Select Ubuntu ISO
- [ ] Click Start (USB will be erased)

## ⚙️ BIOS Setup (5 minutes)
- [ ] Restart i7 with USB inserted
- [ ] Press BIOS key repeatedly during boot
- [ ] Disable Secure Boot
- [ ] Enable USB boot (move to top of boot order)
- [ ] Save changes (F10) and exit

## 🚀 Ubuntu Installation (20 minutes)
- [ ] Boot from USB (should auto-detect)
- [ ] Select language: English
- [ ] Updates: Normal installation + download updates
- [ ] Installation type: **Erase disk and install Ubuntu**
- [ ] Timezone: Select your location
- [ ] Keyboard: English (US)
- [ ] User account:
  - Name: Your name
  - Computer name: i7-server
  - Username: `sivarajumalladi`
  - Password: [choose strong password]
- [ ] Click "Install Ubuntu" and wait 15-20 minutes

## 🔄 First Boot (5 minutes)
- [ ] Remove USB when prompted
- [ ] Restart into Ubuntu
- [ ] Complete any setup prompts

## 🛠️ Post-Install Setup (10 minutes)
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essentials
sudo apt install -y curl wget git htop iotop vim net-tools openssh-server

# Check network
ip addr show
hostname -I  # Note this IP for SSH setup
```

## ✅ Verification Tests
- [ ] Ubuntu boots without USB ✓
- [ ] Internet works (browse web) ✓
- [ ] SSH server running ✓
- [ ] Can ping from Mac: `ping [i7-ip]` ✓

## 🎯 Success Indicators
- Ubuntu login screen appears
- Desktop loads successfully
- Network connection shows "Connected"
- Terminal opens and commands work
- IP address visible in network settings

## 🚨 If Something Goes Wrong
1. **Can't enter BIOS**: Try different keys, search "[PC model] BIOS key"
2. **USB not detected**: Try different USB port, recreate USB
3. **Installation fails**: Check ISO download, disable Secure Boot
4. **No internet**: Restart NetworkManager, check WiFi settings

## 📞 Emergency Recovery
- **Windows still there**: Installation didn't complete, try again
- **Can't boot**: Enter BIOS, change boot order back to HDD
- **Need Windows back**: Reinstall Windows from recovery partition

---
**Total Time: 45-65 minutes | Difficulty: Beginner | Success Rate: 95%**

After Ubuntu installs successfully, run: `./validate_cluster_setup.sh`
