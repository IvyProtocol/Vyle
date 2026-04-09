return {
  -- Disable the default LazyVim autopair plugin (Updated name)
  { "nvim-mini/mini.pairs", enabled = false },

  -- Add nvim-autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
    -- use opts = {} for passing setup options
    -- this is equivalent to setup({}) function
    opts = {
      check_ts = true, -- enable treesitter integration
      disable_filetype = { "TelescopePrompt", "vim" },
    },
  },
}
