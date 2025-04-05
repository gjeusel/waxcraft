{
  # NOTE: Some options are not supported by nix-darwin directly, manually set them:
  #   1. To avoid conflicts with neovim, disable ctrl + up/down/left/right to switch spaces in:
  #     [System Preferences] -> [Keyboard] -> [Keyboard Shortcuts] -> [Mission Control]
  #   2. Disable use Caps Lock as 中/英 switch in:
  #     [System Preferences] -> [Keyboard] -> [Input Sources] -> [Edit] -> [Use 中/英 key to switch ] -> [Disable]
  system.keyboard = {
    enableKeyMapping = true; # Required for custom key remapping
    # List of keyboard mappings to apply, for more information see:
    # https://developer.apple.com/library/content/technotes/tn2450/_index.html
    #
    # use https://hidutil-generator.netlify.app/ and convert hex to decimal
    userKeyMapping = [];
  };
}
