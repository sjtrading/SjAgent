# Ubuntu Installation Guide for i7 Windows Machine

## 📋 Prerequisites Checklist
- [ ] **USB Drive**: 8GB+ USB flash drive for Ubuntu ISO
- [ ] **Ubuntu ISO**: Download Ubuntu 22.04 LTS Desktop
- [ ] **Backup**: Backup important Windows data
- [ ] **BIOS Access**: Know how to enter BIOS (usually F2, F10, or Del)
- [ ] **Power**: Ensure stable power supply during installation

## 📥 Step 1: Download Ubuntu ISO

### Download Options:
1. **Ubuntu 20.04 LTS Desktop** (Recommended)
   - Size: ~3GB
   - Download: https://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso
   - Why: LTS = Long Term Support (5 years), stable for server use

2. **Ubuntu Server 20.04 LTS** (Alternative for headless server)
   - Size: ~1GB
   - Download: https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso
   - Why: Command-line only, smaller, perfect for backtesting server

### Download Command (on any machine):
```bash
# Ubuntu Desktop
wget https://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso

# Ubuntu Server
wget https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso
```

## 🛠️ Step 2: Create Bootable USB

### On Windows (using Rufus - Recommended):
1. Download Rufus: https://rufus.ie/
2. Insert USB drive
3. Run Rufus as Administrator
4. Select Ubuntu ISO file
5. Click "Start" - this will erase USB drive

### On Mac (using Terminal):
```bash
# Find USB drive identifier
diskutil list

# Unmount USB (replace disk2 with your USB identifier)
diskutil unmountDisk /dev/disk2

# Create bootable USB (replace disk2 and path to ISO)
sudo dd if=/path/to/ubuntu-20.04.6-desktop-amd64.iso of=/dev/rdisk2 bs=1m
```

## ⚙️ Step 3: BIOS/UEFI Setup

### Enter BIOS:
- Restart i7 Windows machine
- Press BIOS key repeatedly during boot:
  - **Common keys**: F2, F10, F12, Del, Esc
  - **Look for**: "Setup", "BIOS", or manufacturer logo
  - **If unsure**: Google "[your PC model] enter BIOS"

### BIOS Settings to Change:
1. **Disable Secure Boot**
   - Security → Secure Boot → Disabled
   - (Required for Ubuntu installation)

2. **Enable USB Boot**
   - Boot → Boot Order → Move USB to top
   - Or: Boot → USB Device Priority → Enable

3. **Enable CSM/Legacy Support** (if available)
   - Boot → CSM Support → Enabled
   - (Helps with compatibility)

4. **Save and Exit**
   - F10 + Enter (usually) to save changes

## 🚀 Step 4: Install Ubuntu

### Boot from USB:
1. Insert bootable USB into i7
2. Restart i7
3. Enter BIOS again if needed
4. Select USB drive from boot menu
5. Ubuntu should start loading...

### Installation Process:

#### For Ubuntu Desktop:
1. **Language**: Select English (or your preference)
2. **Updates**: "Normal installation" + "Download updates"
3. **Installation Type**: **"Erase disk and install Ubuntu"**
   - ⚠️ **This will delete Windows!**
   - Alternative: "Install alongside Windows" (dual boot)
4. **Location**: Select your timezone
5. **Keyboard**: English (US) or your layout
6. **User Setup**:
   - Name: Your name
   - Computer name: i7-server (or similar)
   - Username: `sivarajumalladi` (same as your Mac username)
   - Password: Choose strong password
   - Log in automatically: No (security)
7. **Install**: Click "Install Ubuntu" - takes 10-20 minutes

#### For Ubuntu Server:
1. **Language**: English
2. **Network**: Should auto-detect
3. **Proxy**: Leave blank
4. **Ubuntu archive**: Leave default
5. **Storage**: "Use entire disk" (erases Windows)
6. **Profile Setup**:
   - Name: Your name
   - Server name: i7-server
   - Username: `sivarajumalladi`
   - Password: Strong password
7. **SSH Setup**: ✅ Install OpenSSH server
8. **Featured Server Snaps**: Skip for now
9. **Install**: Takes 5-10 minutes

## 🔄 Step 5: Post-Installation Setup

### First Boot:
1. **Remove USB drive** when prompted
2. **Restart** into Ubuntu
3. **Complete setup** if any prompts appear

### Update System:
```bash
# Update package lists and upgrade
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git htop iotop vim net-tools openssh-server
```

### Network Configuration:
```bash
# Check current IP
ip addr show

# Test internet
ping -c 3 8.8.8.8

# Note down IP address for later SSH setup
hostname -I
```

## 🔐 Step 6: SSH Server Setup

Ubuntu Desktop comes with SSH server. For Server edition, you already selected it.

```bash
# Enable and start SSH service
sudo systemctl enable ssh
sudo systemctl start ssh

# Check SSH status
sudo systemctl status ssh

# Allow SSH through firewall (if enabled)
sudo ufw allow ssh
```

## 📋 Verification Checklist

After installation, verify these work:

- [ ] **Boot**: Ubuntu starts without USB
- [ ] **Network**: Internet connection works
- [ ] **SSH**: Can connect from another machine
- [ ] **Updates**: System updated successfully
- [ ] **User**: Your username works with sudo

## 🚨 Troubleshooting

### Can't Enter BIOS:
- Try different keys: F1, F2, F8, F10, F12, Del
- Search online: "[PC model] enter BIOS"
- Some PCs require tapping key repeatedly

### USB Not Detected:
- Try different USB port
- Recreate bootable USB
- Check USB drive isn't corrupted

### Installation Fails:
- Check ISO integrity (Ubuntu website has verification)
- Try different USB drive
- Disable Secure Boot completely

### No Internet After Install:
```bash
# Check network
nmcli device status
nmcli connection show

# Restart network manager
sudo systemctl restart NetworkManager
```

## ⏱️ Time Estimate
- **Download**: 10-30 minutes (depends on internet)
- **USB Creation**: 5-10 minutes
- **BIOS Setup**: 5 minutes
- **Installation**: 15-30 minutes
- **Post-Setup**: 10 minutes

**Total: ~45-85 minutes**

## 🎯 Next Steps After Ubuntu Install

Once Ubuntu is installed and SSH works:

1. **SSH Setup**: Copy keys from Mac to i7
2. **Prerequisites**: Install Python, Poetry, Redis
3. **Project**: Clone ai-trading-machine repository
4. **Cluster**: Deploy cluster components
5. **Testing**: Run validation script

## 📞 Need Help?

If you get stuck at any step:
1. **Take photos** of error messages
2. **Note exact step** where it fails
3. **Share error messages** - I can help troubleshoot!

Ready to start? Download Ubuntu and create the bootable USB! 🚀
