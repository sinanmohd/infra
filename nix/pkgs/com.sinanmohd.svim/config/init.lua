vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- TODO: replace with pkgs.wrapNeovim and pkgs.vimUtils.buildVimPlugin
-- hack to add neovim -u path to runtime path, so require 'options' works
vim.opt.rtp:prepend(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))

require 'options'
require 'keymaps'
require 'pacman'
