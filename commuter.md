Do this on the i7 Windows machine (PowerShell as Admin):

wsl -l -v
Use your distro name from above (example: Ubuntu-22.04), then open WSL as root (no Linux password needed):

wsl -d Ubuntu-22.04 -u root
Inside that root shell, run:

apt update
apt install -y sudo

id sivarajumalladi || useradd -m -s /bin/bash sivarajumalladi

mkdir -p /home/sivarajumalladi
chown -R sivarajumalladi:sivarajumalladi /home/sivarajumalladi
chmod 700 /home/sivarajumalladi

usermod -d /home/sivarajumalladi -s /bin/bash -aG sudo sivarajumalladi
passwd sivarajumalladi
Set WSL default user:

printf "[user]\ndefault=sivarajumalladi\n" > /etc/wsl.conf
exit
Back in PowerShell:

wsl --shutdown
wsl -d Ubuntu-22.04 -e bash -lc "whoami && sudo -v"
Now use that Linux password in your Mac command:

I7_HOST=192.168.29.173 I7_USER=sivarajumalladi I7_PA

Step:2

i7 being ON is not enough. Right now this is a network forwarding issue (timeout), not password auth.

Do this exactly:

On i7 WSL (Ubuntu)
sudo apt update
sudo apt install -y openssh-server
sudo service ssh restart || sudo systemctl restart ssh
sudo ss -ltnp | grep ':22'
hostname -I
On i7 Windows PowerShell (Run as Administrator)
$Distro = "Ubuntu-22.04"   # change to your actual distro name from: wsl -l -v
$WslIp = (wsl -d $Distro -e sh -lc "hostname -I | awk '{print \$1}'").Trim()

Get-Service iphlpsvc | Set-Service -StartupType Automatic
Start-Service iphlpsvc

netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=22
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=22 connectaddress=$WslIp connectport=22
netsh interface portproxy show all

netsh advfirewall firewall add rule name="WSL SSH 22" dir=in action=allow protocol=TCP localport=22
Also verify i7 LAN IP didn’t change
ipconfig
If it’s not 192.168.29.173, use the new IP on Mac.

From your Mac, test
nc -vz -G 5 192.168.29.173 22
ssh sivarajumalladi@192.168.29.173
If you run these, I can immediately re-test from here and confirm if connection is back.
