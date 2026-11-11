-- MDX
-- https://github.com/davidmh/mdx.nvim

-- NOTE: [AGENT]: mdx is parsed as jsx, html comments are a syntax error there
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('custom-mdx', { clear = true }),
  pattern = 'mdx',
  callback = function(args) vim.bo[args.buf].commentstring = '{/* %s */}' end,
})

-- Depends on nvim-treesitter, which is added in init.lua before custom plugins are loaded
vim.pack.add { 'https://github.com/davidmh/mdx.nvim' }

-- mdx_analyzer needs the typescript lib dir, find it next to the nix provided tsserver
local function get_nix_tsdk()
  local tsserver_path = vim.fn.exepath 'tsserver'
  if tsserver_path ~= '' then
    local real_bin = vim.uv.fs_realpath(tsserver_path) or tsserver_path
    local lib_dir = vim.fn.fnamemodify(real_bin, ':h:h') .. '/lib/node_modules/typescript/lib'
    if vim.uv.fs_stat(lib_dir) then return lib_dir end
  end
  return nil
end

vim.lsp.config('mdx_analyzer', {
  init_options = {
    typescript = {
      tsdk = get_nix_tsdk(),
    },
  },
})
vim.lsp.enable 'mdx_analyzer'
