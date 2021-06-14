local vim = vim

-- map

function keymap(modes, input, output, options)
  options = options or {}
  -- input = vim.api.nvim_replace_termcodes(input, true, true, true)
  -- output = vim.api.nvim_replace_termcodes(output, true, true, true)

  if not modes then
    vim.api.nvim_set_keymap("", input, output, options)
  else
    modes:gsub(
      ".",
      function(mode)
        vim.api.nvim_set_keymap(mode, input, output, options)
      end
  )
  end
end

function nmap(input, output, options)
  keymap('n', input, output, options)
end

function imap(input, output, options)
  keymap('i', input, output, options)
end

function vmap(input, output, options)
  keymap('v', input, output, options)
end

function xmap(input, output, options)
  keymap('x', input, output, options)
end

function omap(input, output, options)
  keymap('o', input, output, options)
end

function tmap(input, output, options)
  keymap('t', input, output, options)
end

function cmap(input, output, options)
  keymap('c', input, output, options)
end

-- noremap

function noremap(modes, input, output, options)
  options = options or {}
  options['noremap'] = true
  keymap(modes, input, output, options)
end

function nnoremap(input, output, options)
  noremap('n', input, output, options)
end

function inoremap(input, output, options)
  noremap('i', input, output, options)
end

function vnoremap(input, output, options)
  noremap('v', input, output, options)
end

function xnoremap(input, output, options)
  noremap('x', input, output, options)
end

function onoremap(input, output, options)
  noremap('o', input, output, options)
end

function tnoremap(input, output, options)
    noremap('t', input, output, options)
end

function cnoremap(input, output, options)
    noremap('c', input, output, options)
end
