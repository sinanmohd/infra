-- Floating terminal, backed by a per instance tmux session
-- https://github.com/akinsho/toggleterm.nvim

math.randomseed(os.time())
local session_name = '_nvim_toggleterm_' .. vim.fn.getcwd() .. math.random()
session_name = session_name:gsub('%W', '')

local cmd = 'tmux new-session -ds '
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
