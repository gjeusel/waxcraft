vim.filetype.add({
  extension = {
    ["md"] = "markdown",
    ["txt"] = "sh",
    ["conf"] = "config",
    ["nix"] = "nix",

    ["plist"] = "xml",  -- macos PropertyList files

    -- frontend
    ["ts"] = "typescript",

    -- yamls
    ["kubeconfig"] = "yaml",
    ["yml"] = "yaml",

    -- terraform
    ["tf"] = "terraform",
    ["tfvars"] = "terraform",
    ["tfstate"] = "terraform",

    -- edgeql
    ["esdl"] = "edgeql",
  },
  filename = {
    -- git
    [".gitconfig"] = "config",
    [".gitignore"] = "config",
    -- ini
    [".flake8"] = "ini",
    -- sh
    ["cronfile"] = "sh",
    [".flaskenv"] = "sh",
    [".aliases"] = "zsh",
  },
  -- pattern = map_pattern_ft,
  pattern = {
    [".*%.env.*"] = "sh",
  },
})
