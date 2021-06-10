local layout_strategies = require("telescope.pickers.layout_strategies")
local builtin_themes = require("telescope.themes")

local M = {}

-- Custome layout strategy ( like center but follow layout defaults )
---    +--------------+
---    |    Preview   |
---    |    Preview   |
---    |    Preview   |
---    |    Preview   |
---    |    Preview   |
---    +--------------+
---    |    Prompt    |
---    +--------------+
---    |    Result    |
---    |    Result    |
---    +--------------+
M.centerwax = function(self, max_columns, max_lines)
  local resolve = require("telescope.config.resolve")
  local p_window = require('telescope.pickers.window')

  local layout_config = self.layout_config or {}

  local initial_options = p_window.get_initial_window_options(self)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_padding = resolve.resolve_width(
    layout_config.width_padding or math.ceil((1 - self.window.width) * 0.5 * max_columns)
  )(self, max_columns, max_lines)

  local width = max_columns - width_padding * 2
  if not self.previewer then
    preview.width = 0
  else
    preview.width = width
  end
  results.width = width
  prompt.width = width

  -- Height
  local height_padding = math.max(
    1,
    resolve.resolve_height(layout_config.height_padding or 3)(self, max_columns, max_lines)
  )
  local picker_height = max_lines - 2 * height_padding

  local preview_total = 0
  preview.height = 0
  if self.previewer then
    preview.height = resolve.resolve_height(
      layout_config.preview_height or (max_lines - 15)
    )(self, max_columns, picker_height)

    preview_total = preview.height + 2
  end

  prompt.height = 1
  results.height = picker_height - preview_total - prompt.height - 2

  results.col, preview.col, prompt.col = width_padding, width_padding, width_padding

  if self.previewer then
    preview.line = height_padding
    prompt.line = preview.line + preview.height + 2
    results.line = prompt.line + prompt.height + 2

---    +-----------------+
---    |    Previewer    |
---    |    Previewer    |
---    |    Previewer    |
---    +-----------------+
---    |     Result      |
---    |     Result      |
---    |     Result      |
---    +-----------------+
---    |     Prompt      |
---    +-----------------+
    -- preview.line = height_padding
    -- results.line = preview.line + preview.height + 2
    -- prompt.line = results.line + results.height + 2
  else
    results.line = height_padding
    prompt.line = results.line + results.height + 2
  end

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end


M.verticalwax = function(self, max_columns, max_lines)
  local layout_config = self.layout_config or {}
  local resolve = require("telescope.config.resolve")
  local p_window = require('telescope.pickers.window')

  local initial_options = p_window.get_initial_window_options(self)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_padding = resolve.resolve_width(
    layout_config.width_padding or math.ceil((1 - self.window.width) * 0.5 * max_columns)
  )(self, max_columns, max_lines)

  local width = max_columns - width_padding * 2
  preview.width = width
  results.width = width
  prompt.width = width

  -- Height
  local height_padding = resolve.resolve_height(layout_config.height_padding or 3)(self, max_columns, max_lines)
  height_padding = math.max(0, height_padding)
  local picker_height = max_lines - 2 * height_padding

  local preview_total = 0
  preview.height = 0
  preview.height = resolve.resolve_height(
    layout_config.preview_height or (max_lines - 15)
  )(self, max_columns, picker_height)

  preview_total = preview.height + 2

  if height_padding == 0 or preview_total <= 10 then
    self.preview = false
    preview.height = 0
    preview.width = 0
    preview_total = 0
  end

  prompt.height = 1
  results.height = picker_height - preview_total - prompt.height - 2

  results.col, preview.col, prompt.col = width_padding, width_padding, width_padding

  local step = 1
  if self.previewer then
    if not layout_config.mirror then
      preview.line = height_padding
      results.line = preview.line + preview.height + step
      prompt.line = results.line + results.height + step
    else
      prompt.line = height_padding
      results.line = prompt.line + prompt.height + step
      preview.line = results.line + results.height + step
    end
  else
    results.line = height_padding
    prompt.line = results.line + results.height + step
  end

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end


M.flexwax = function(self, max_columns, max_lines)
  local layout_config = self.layout_config or {}

  local flip_columns = layout_config.flip_columns or 150

  if max_columns < flip_columns then
    self.layout_config = (require("telescope.config").values.layout_defaults or {})['vertical']
    return M.verticalwax(self, max_columns, max_lines)
  else
    self.layout_config = (require("telescope.config").values.layout_defaults or {})['horizontal']
    return layout_strategies.horizontal(self, max_columns, max_lines)
  end
end


return M
