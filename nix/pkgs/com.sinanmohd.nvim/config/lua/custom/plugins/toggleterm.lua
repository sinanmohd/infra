-- Floating terminal, backed by a per instance tmux session
-- https://github.com/akinsho/toggleterm.nvim

math.randomseed(os.time())
local session_name = '_nvim_toggleterm_' .. vim.fn.getcwd() .. math.random()
session_name = session_name:gsub('%W', '')

-- NOTE: tmux refuses to attach ("sessions should be nested with
-- care") when $TMUX is set and the client tty has the name of one of its
-- panes. The sandbox has its own devpts, so its /dev/pts/N collide with the
-- host panes by chance. Keep the socket, drop $TMUX
local tmux = 'tmux'
local socket = (vim.env.TMUX or ''):match '^[^,]+'
if socket then tmux = 'TMUX= tmux -S ' .. vim.fn.shellescape(socket) end

local cmd = tmux
  .. [[ new-session -ds ]]
  .. session_name
  .. [[ \; set -t ]]
  .. session_name
  .. ' destroy-unattached '
  .. [[ \; set -t ]]
  .. session_name
  .. " window-status-current-format '#{window_index}:#{pane_current_command}' "
  .. [[ \; set -t ]]
  .. session_name
  .. " window-status-format '#{window_index}:#{pane_current_command}' "
  .. [[ \; attach -t ]]
  .. session_name

vim.pack.add { 'https://github.com/akinsho/toggleterm.nvim' }
require('toggleterm').setup {
  direction = 'float',
  open_mapping = [[<c-\>]],
  shell = cmd,
}
