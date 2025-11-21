-- vim: set ts=2 sw=2 et:
-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

config.color_scheme = 'Gruvbox dark, medium (base16)'
config.font = wezterm.font_with_fallback {
  {family = "Fira Code", weight="Medium", stretch="Normal", style="Normal"},
  {family = 'Noto Sans Mono CJK TC', weight='Medium', stretch='Normal', style='Normal'},
  'Noto Color Emoji',
}
config.font_size = 16
config.mouse_bindings = {
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action({ PasteFrom = "Clipboard" }),
  },
}
config.keys = {
  { key = 'LeftArrow', mods = 'SHIFT|CTRL', action = wezterm.action.DisableDefaultAssignment },
  { key = 'RightArrow', mods = 'SHIFT|CTRL', action = wezterm.action.DisableDefaultAssignment }
}
config.use_ime = true
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
  left = '0px',
  right = '0px',
  top = '0px',
  bottom = '0px',
}
-- and finally, return the configuration to wezterm
return config
