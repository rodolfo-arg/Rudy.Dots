-- Guard LazyVim's Mason integration on first start.
-- If mason-lspconfig isn't installed yet, disable Mason integration to avoid
-- 'module mason-lspconfig.mappings.server not found' errors during bootstrap.
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local has_mason_lsp = pcall(require, "mason-lspconfig")
      if not has_mason_lsp then
        opts.mason = false
      end

      -- Force-disable inline diagnostics beyond signs so LazyVim doesn't re-enable them later
      opts.diagnostics = vim.tbl_deep_extend("force", opts.diagnostics or {}, {
        underline = false,
        virtual_text = false,
        virtual_lines = false,
      })
    end,
  },
}
