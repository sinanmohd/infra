local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- vim: ts=2 sts=2 sw=2 et
require('lazy').setup({
  'Darazaki/indent-o-matic',
  require 'pacman.plugins.gitsigns',
  require 'pacman.plugins.which-key',
  require 'pacman.plugins.telescope',
  require 'pacman.plugins.lspconfig',
  require 'pacman.plugins.conform',
  require 'pacman.plugins.blink-cmp',
  require 'pacman.plugins.tokyonight',
  require 'pacman.plugins.todo-comments',
  require 'pacman.plugins.mini',
  require 'pacman.plugins.treesitter',
  require 'pacman.plugins.indent_line',
  require 'pacman.plugins.lint',
  require 'pacman.plugins.autopairs',
  require 'pacman.plugins.neo-tree',
  require 'pacman.plugins.vim-fugitive',
  require 'pacman.plugins.helm-ls',
  require 'pacman.plugins.toggleterm',
}, {
  lockfile = vim.fn.stdpath('data') .. "/lazy-lock.json",
})
