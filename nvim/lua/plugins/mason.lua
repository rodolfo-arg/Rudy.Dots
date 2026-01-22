return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- Hybrid: keep Mason available but avoid auto-installs during sync.
      opts.ensure_installed = {}
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      -- Hybrid: don't auto-install or auto-enable Mason servers.
      opts.ensure_installed = {}
      opts.automatic_enable = false
    end,
  },
}
