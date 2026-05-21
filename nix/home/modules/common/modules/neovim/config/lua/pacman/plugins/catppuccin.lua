return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require("catppuccin").setup({
          flavour = "mocha", -- latte, frappe, macchiato, mocha
          transparent_background = true, -- disables setting the background color.
          float = {
            transparent = true, -- enable transparent floating windows
          },
          term_colors = false, -- sets terminal colors (e.g. `g:terminal_color_0`)
      })

      vim.cmd.colorscheme "catppuccin-nvim"
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
