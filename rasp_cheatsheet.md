Raspberry Pi
===============


# SSH
-----------
- Connect to device via SSH : `ssh pi@192.168.64.1.5`


# Keyboard
-----------
Fr layout : `setxkbmap fr`


Users
-----------
Add new user with home dir: `sudo useradd -m sven -G sudo` (see `/etc/passwd`)

Set password for user: `sudo passwd sven` (see `/etc/shadow`)


System
-----------

Get system info (e.g. IP): `ifconfig`

Get network info: `iwconfig`

Get hostname: `hostname`

Get hostname IP: `hostname -I`

Check for all connected USB devices: `lsusb`

Switch to config: `sudo raspi-config`

Switch to GUI: `startx`

Start SSH while booting: `sudo update-rc.d ssh defaults`


Web Server
-----------

- [Related tutorial](http://www.raspberry-projects.com/pi/software_utilities/web-servers/phpapache)

Update system: `sudo apt-get update` & `sudo apt-get upgrade`

Install Web Server: `sudo apt-get install apache2 php5`

Laravel will also need `mcrypt` and `GD` extension.

Install MySQL: `sudo apt-get install mysql-server mysql-client php5-mysql`

Restart: `sudo service apache2 restart`

Install Avahi for `.local` domain: `sudo apt-get install avahi-daemon` (see [tutorial](http://www.ryukent.com/2013/09/a-local-url-instead-of-an-ip-address-for-your-raspberry-pi/))

Note: Also update vhosts to `AllowOverride All`!


Audio
-----------

Play: `omxplayer audio.mp3`

Volume: `+` & `-`


GUI Keyboard Shortcuts
-----------

System menu: `ctrl + esc`

Open programm menu: `alt + space`

Access dropdown: `alt + [letter-with-underline]` e.g. `alt + f`

Back to CLI: `ctrl + alt + backspace`


Remote Control
-----------

Install XRDP: `apt-get install xrdp`

Connect via Remote Desktop app

---
<img src="pictures/schema_vnc.png" width="150" alt="logo"/>

- [Related tutorial](http://gettingstartedwithraspberrypi.tumblr.com/post/24142374137/setting-up-a-vnc-server)

- Install VNC: `sudo apt-get install tightvncserver`
- Start VNC: `tightvncserver` or `vncserver :1 -geometry 1024x728 -depth 24`
or `vncserver :1 -geometry 1920x1080 -depth 24`
- Kill VNC: `vncserver -kill :1`

- [Real VNC for OS X](http://www.realvnc.com/)
- [Mocha VNC Lite for iOS](https://itunes.apple.com/gb/app/mocha-vnc-lite/id284984448)


File Sharing
-----------

- [Related tutorial](http://gettingstartedwithraspberrypi.tumblr.com/post/24398167109/file-sharing-with-afp-and-auto-discovery-with)

Install file sharing: `sudo apt-get install netatalk`

Connect to Server (via ⌘K): `afp://192.168.64.xxx`


Wifi
-----------

### Setup

- [Via interface](http://youtu.be/sXDqMapgU_M)
- [Via terminal](http://www.maketecheasier.com/setup-wifi-on-raspberry-pi/)

### Disable Power Management

- [Tutorial](http://www.raspberrypi-spy.co.uk/2015/06/how-to-disable-wifi-power-saving-on-the-raspberry-pi/)

- Check the power management flag using: `cat /sys/module/8192cu/parameters/rtw_power_mgnt` (this will report a value of 1)
- To set it to zero you can use: `sudo touch /etc/modprobe.d/8192cu.conf`
- Add this line to the created file: `options 8192cu rtw_power_mgnt=0 rtw_enusbss=0`
- Reboot: `sudo reboot`


Midnight Commander
-----------

Install: `sudo apt-get install mc`

Start: `sudo mc`
