local function ensure_list(list, value)
  if not vim.tbl_contains(list, value) then
    table.insert(list, value)
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      ensure_list(opts.ensure_installed, "kotlin")
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      local util = require("lspconfig.util")

      local kotlin_lsp = vim.fn.exepath("kotlin-lsp")
      if kotlin_lsp == "" then
        kotlin_lsp = "kotlin-lsp"
      end

      local system_path = vim.fn.stdpath("cache") .. "/kotlin_lsp"
      opts.servers.kotlin_lsp = {
        cmd = { kotlin_lsp, "--stdio", "--system-path", system_path },
        root_dir = util.root_pattern(
          "workspace.json",
          "settings.gradle",
          "settings.gradle.kts",
          "build.gradle",
          "build.gradle.kts",
          "pom.xml",
          ".git"
        ),
      }
    end,
  },
}
