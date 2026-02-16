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
