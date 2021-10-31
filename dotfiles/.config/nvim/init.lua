--      _   _   __  __   __    __  _  ___  __   _   _  _  __ __
--     | | | | /  \ \ \_/ /   |  \| || __|/__\ | \ / || ||  V  |
--     | 'V' || /\ | > , <    | | ' || _|| \/ |`\ V /'| || \_/ |
--     !_/ \_!|_||_|/_/ \_\   |_|\__||___|\__/   \_/  |_||_| |_|
--
-- Inspired by:
-- - tjevries: https://github.com/tjdevries/config_manager/tree/master/xdg_config/nvim              ( the god )
-- - Connie2461: https://github.com/Conni2461/dotfiles/tree/master/.config/nvim                     ( the semi-god )
-- - ThePrimeagen: https://github.com/awesome-streamers/awesome-streamerrc/tree/master/ThePrimeagen ( the funny )
-- - ChristianChiarulli: https://github.com/ChristianChiarulli/LunarVim                             ( the ambitious )
-- - mvllow: https://github.com/mvllow/nvim/                                                        ( frontend lsp master -> keep an eye for volar vue3 setup )

require("wax.utils")

if is_module_available("impatient") then
  require("impatient") -- optim lua
  -- require'impatient'.enable_profile()
end

require("wax.plugins")

require("wax.settings")
require("wax.keymaps")

require("wax.themes")

require("wax.filetypes")
require("wax.folds")
