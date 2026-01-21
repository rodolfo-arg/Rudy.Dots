return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      local function ensure(value)
        if not vim.tbl_contains(opts.ensure_installed, value) then
          table.insert(opts.ensure_installed, value)
        end
      end

      ensure("kotlin-lsp")
      ensure("kotlin-debug-adapter")
      ensure("ktlint")
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "kotlin_lsp") then
        table.insert(opts.ensure_installed, "kotlin_lsp")
      end
    end,
  },
}
