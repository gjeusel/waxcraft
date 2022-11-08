#!/usr/bin/env bash

# Sources:
# - https://github.com/jaredhowland/.dotfiles/blob/master/macos/bootstrap.sh
# - https://osxdaily.com/2012/02/14/speed-up-misson-control-animations-mac-os-x/

# To set back the default of any config:
# defaults delete com.apple.dock expose-animation-duration
# defaults delete -g NSWindowResizeTime

# Don't forget to restart doc to see the options applied:
# killall Dock

#
# ----------- Animation Speed -----------
#

# mission control animation:
defaults write com.apple.dock expose-animation-duration -float 0.10

# resize window time
defaults write -g NSWindowResizeTime -float 0.10

# disable any finder animation
defaults write com.apple.finder DisableAllAnimations -bool true

# launchpad show/hide animation
defaults write com.apple.dock springboard-show-duration -float 0.10
defaults write com.apple.dock springboard-hide-duration -float 0.10

# launchpad page-flip animation
defaults write com.apple.dock springboard-page-duration -float 0.10

#
# ----------- Finder -----------
#

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files for the current user from now on
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# # Use column view in all Finder windows by default
# # Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`, `Nlsv`
# defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

#
# ----------- ScreenShots -----------
#

# save screenshots to Downloads
defaults write com.apple.screencapture location -string "${HOME}/Downloads"
