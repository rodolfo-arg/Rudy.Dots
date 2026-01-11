return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts = opts or {}
      opts.linters_by_ft = opts.linters_by_ft or {}

      if vim.fn.executable("statix") == 1 then
        opts.linters_by_ft.nix = { "statix" }
      else
        opts.linters_by_ft.nix = {}
      end

      return opts
    end,
  },
}
