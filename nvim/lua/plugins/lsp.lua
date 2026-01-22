-- General LSP configuration
-- Note: Kotlin/Java specific config is in kotlin-android-lsp.lua
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Guard LazyVim's Mason integration on first start
      local has_mason_lsp = pcall(require, "mason-lspconfig")
      if not has_mason_lsp then
        opts.mason = false
      end

      -- Force-disable inline diagnostics beyond signs
      opts.diagnostics = vim.tbl_deep_extend("force", opts.diagnostics or {}, {
        underline = false,
        virtual_text = false,
        virtual_lines = false,
      })
    end,
  },
}
