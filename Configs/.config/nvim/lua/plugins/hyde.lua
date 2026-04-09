return {
  {
    "iamharshdabas/hyde.nvim",
    opts = {
      font = {
        enabled = true, -- Let Hyde build `guifont`.
        fallback = {
          family = "CaskaydiaCove Nerd Font Mono", -- Used when Kitty does not provide a font family.
          size = 12, -- Used when Kitty does not provide a font size.
        },
        hyde = {
          enabled = true, -- Read font values from Kitty.
          file_path = {
            "~/.config/kitty/theme.conf", -- Theme-level font overrides.
            "~/.config/kitty/vyle.conf", -- Hyde defaults.
          },
          family_key = "font_family", -- Kitty key for the font family.
          size_key = "font_size", -- Kitty key for the font size.
        },
      },
      palette = {
        file_path = "~/.config/kitty/theme.conf", -- Kitty theme file for Tokyonight colors.
        watcher = {
          enabled = true, -- Watch the theme file for changes.
          debounce = 100, -- Wait this long before reloading after a file event.
          notify = true, -- Show theme change notifications when debug is on.
        },
      },
      neovide = {
        enabled = true, -- Apply Neovide settings when running in Neovide.
        opacity = 0.9, -- Window opacity.
        hide_mouse_when_typing = true, -- Hide the mouse while typing.
        cursor_trail_size = 0.8, -- Cursor trail size.
        cursor_vfx_mode = "pixiedust", -- Cursor effect.
        opacity_keymaps = {
          enabled = true, -- Enable opacity keymaps.
          increase = "<C-A-i>", -- Increase opacity.
          decrease = "<C-A-o>", -- Decrease opacity.
          step = 0.05, -- Change per key press.
          min = 0.0, -- Lowest opacity.
          max = 1.0, -- Highest opacity.
          target = "neovide_opacity", -- `vim.g` key to update.
        },
      },
      tokyonight = {
        style = "storm", -- Tokyonight variant.
        transparent = true, -- Keep the main background transparent outside Neovide.
        styles = {
          sidebars = "transparent", -- Sidebar background style.
          floats = "transparent", -- Float background style.
        },
      },
      debug = {
        enabled = false, -- Show Hyde notifications.
      },
    },
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    dependencies = { "hyde.nvim" },
    opts = function()
      return require("hyde").get_tokyonight_config()
    end,
    config = function(_, opts)
      local hyde = require("hyde")

      hyde.apply_guifont()

      if vim.g.neovide then
        hyde.apply_neovide()
      end

      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")

      hyde.start_theme_watcher(nil, function()
        hyde.apply_guifont()
        require("tokyonight").setup(hyde.get_tokyonight_config())
        vim.cmd.colorscheme("tokyonight")
      end)
    end,
  },
}
