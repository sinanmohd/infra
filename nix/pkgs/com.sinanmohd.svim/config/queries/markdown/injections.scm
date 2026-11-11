; extends

; mdx expression comments, mdx.nvim only injects tsx for lines starting with `<`
((inline) @injection.content
  (#lua-match? @injection.content "^%s*{/%*")
  (#set! injection.language "typescriptreact"))
