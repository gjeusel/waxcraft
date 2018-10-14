#!/bin/bash

# Inspired from https://raw.githubusercontent.com/g0tmi1k/os-scripts/master/kali2.sh


##### (Cosmetic) Colour output
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal


##### Check if we are running as root - else this script will fail (hard!)
if [[ ${EUID} -ne 0 ]]; then
  echo -e ' '${RED}'[!]'${RESET}" This script must be ${RED}run as root${RESET}. Quitting..." 1>&2
  exit 1
else
  echo -e " ${BLUE}[*]${RESET} ${BOLD}Kali Linux 2.x post-install script${RESET}"
fi


##### Fix display output for GUI programs when connecting via SSH
export DISPLAY=:0.0   #[[ -z $SSH_CONNECTION ]] || export DISPLAY=:0.0
export TERM=xterm


#####  Give VM users a little heads up to get ready
(dmidecode | grep -iq virtual) && echo -e " ${YELLOW}[i]${RESET} VM Detected. Please be sure to have the correct tools ISO mounted." && sleep 5s


##### Check Internet access
echo -e "\n ${GREEN}[+]${RESET} Checking ${GREEN}Internet access${RESET}"
for i in {1..10}; do ping -c 1 -W ${i} www.google.com &>/dev/null && break; done
if [[ "$?" -ne 0 ]]; then
  echo -e ' '${RED}'[!]'${RESET}" ${RED}Possible DNS issues${RESET}(?). Trying DHCP 'fix'" 1>&2
  chattr -i /etc/resolv.conf 2>/dev/null
  dhclient -r
  route delete default gw 192.168.155.1 2>/dev/null
  dhclient
  sleep 15s
  _TMP=true
  _CMD="$(ping -c 1 8.8.8.8 &>/dev/null)"
  if [[ "$?" -ne 0 && "$_TMP" == true ]]; then
    _TMP=false
    echo -e ' '${RED}'[!]'${RESET}" ${RED}No Internet access${RESET}. Manually fix the issue & re-run the script" 1>&2
  fi
  _CMD="$(ping -c 1 www.google.com &>/dev/null)"
  if [[ "$?" -ne 0 && "$_TMP" == true ]]; then
    _TMP=false
    echo -e ' '${RED}'[!]'${RESET}" ${RED}Possible DNS issues${RESET}(?). Manually fix the issue & re-run the script" 1>&2
  fi
  if [[ "$_TMP" == false ]]; then
    (dmidecode | grep -iq virtual) && echo -e " ${YELLOW}[i]${RESET} VM Detected. ${YELLOW}Try switching network adapter mode${RESET} (NAT/Bridged)"
    echo -e ' '${RED}'[!]'${RESET}" Quitting..." 1>&2
    exit 1
  fi
fi
#--- GitHub under DDoS?
timeout 300 curl --progress -k -L -f "https://status.github.com/api/status.json" | grep -q "good" || (echo -e ' '${RED}'[!]'${RESET}" ${RED}GitHub is currently having issues${RESET}. ${BOLD}Lots may fail${RESET}. See: https://status.github.com/" 1>&2 && sleep 10s)


##### Install kernel headers
echo -e "\n ${GREEN}[+]${RESET} Installing ${GREEN}kernel headers${RESET}"
apt-get -y -qq install make gcc "linux-headers-$(uname -r)" || echo -e ' '${RED}'[!] Issue with apt-get'${RESET} 1>&2
if [[ $? -ne 0 ]]; then
  echo -e ' '${RED}'[!]'${RESET}" There was an ${RED}issue installing kernel headers${RESET}" 1>&2
  echo -e " ${YELLOW}[i]${RESET} Are you ${YELLOW}USING${RESET} the ${YELLOW}latest kernel${RESET}?"
  echo -e " ${YELLOW}[i]${RESET} ${YELLOW}Reboot your machine${RESET}"
  exit 1
fi


##### Fix audio issues
echo -e "\n ${GREEN}[+]${RESET} Fixing ${GREEN}audio${RESET} issues"
#--- Unmute on startup
apt-get -y -qq install alsa-utils || echo -e ' '${RED}'[!] Issue with apt-get'${RESET} 1>&2
#--- Set volume now
amixer set Master unmute >/dev/null
amixer set Master 50% >/dev/null


##### Configure XFCE4
echo -e "\n ${GREEN}[+]${RESET} Configuring ${GREEN}XFCE4${RESET}${RESET} ~ desktop environment"
cat <<EOF > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml || echo -e ' '${RED}'[!] Issue with writing file'${RESET} 1>&2
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-keyboard-shortcuts" version="1.0">

  <property name="commands" type="empty">
    <property name="custom" type="empty">

      <property name="override" type="bool" value="true"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;f" type="string" value="firefox"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="xfce4-terminal --hide-toolbar"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;d" type="string" value="Thunar"/>
      <property name="&lt;Alt&gt;space" type="string" value="xfce4-appfinder"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;l" type="string" value="xflock4"/>

    </property>
  </property>

  <property name="xfwm4" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Super&gt;F1" type="string" value="move_window_workspace_1_key"/>
      <property name="&lt;Super&gt;F2" type="string" value="move_window_workspace_2_key"/>
      <property name="&lt;Super&gt;F3" type="string" value="move_window_workspace_3_key"/>
      <property name="&lt;Super&gt;F4" type="string" value="move_window_workspace_4_key"/>

      <property name="&lt;Alt&gt;F4" type="string" value="close_window_key"/>
      <property name="&lt;Alt&gt;Tab" type="string" value="cycle_windows_key"/>

      <property name="&lt;Control&gt;&lt;Alt&gt;Down" type="string" value="down_workspace_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;Left" type="string" value="left_workspace_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;Right" type="string" value="right_workspace_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;Up" type="string" value="up_workspace_key"/>

      <property name="F1" type="string" value="workspace_1_key"/>
      <property name="F2" type="string" value="workspace_2_key"/>
      <property name="F3" type="string" value="workspace_3_key"/>
      <property name="F4" type="string" value="workspace_4_key"/>

      <property name="&lt;Super&gt;d" type="string" value="show_desktop_key"/>
      <property name="&lt;Super&gt;Left" type="string" value="tile_left_key"/>
      <property name="&lt;Super&gt;Right" type="string" value="tile_right_key"/>
      <property name="&lt;Super&gt;Up" type="string" value="maximize_window_key"/>


    </property>
  </property>
  <property name="providers" type="array">
    <value type="string" value="xfwm4"/>
    <value type="string" value="commands"/>
  </property>
</channel>
EOF
