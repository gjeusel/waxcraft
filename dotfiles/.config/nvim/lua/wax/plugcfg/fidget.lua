safe_require("fidget").setup({
  text = {
    spinner = "pipe", -- animation shown when tasks are ongoing
    done = "", -- character shown when all tasks are complete
    commenced = "", -- message shown when task starts
    completed = "", -- message shown when task completes
  },
  timer = {
    spinner_rate = 125, -- frame rate of spinner animation, in ms
    fidget_decay = 500, -- how long to keep around empty fidget, in ms
    task_decay = 500, -- how long to keep around completed task, in ms
  },
  window = {
    relative = "win", -- where to anchor, either "win" or "editor"
    blend = 0, -- &winblend for the window
    zindex = nil, -- the zindex value for the window
    border = "none", -- style of border for the fidget window
  },
})
