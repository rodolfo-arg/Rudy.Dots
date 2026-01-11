return {
  "akinsho/flutter-tools.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "stevearc/dressing.nvim",
  },
  config = function()
    local dart_exe = vim.fn.exepath("dart")
    local flutter_exe = vim.fn.exepath("flutter")

    require("flutter-tools").setup({
      flutter_path = flutter_exe,
      dart_path = dart_exe,

      widget_guides = { enabled = true },
      closing_tags = { highlight = "Comment" },

      -- Enable flutter-tools debugger and dev log; run via nvim-dap
      debugger = {
        enabled = true,
      },
      dev_log = {
        enabled = false, -- disable the flutter-tools dev log window only
      },

      lsp = {
        color = { enabled = true },
        cmd = { dart_exe, "language-server", "--protocol=lsp" },
        on_attach = function(client, bufnr)
          local buf = vim.lsp.buf
          local opts = { buffer = bufnr }
          vim.keymap.set("n", "gd", buf.definition, opts)
          vim.keymap.set("n", "K", buf.hover, opts)
          vim.keymap.set("n", "gr", buf.references, opts)
          vim.keymap.set("n", "<leader>rn", buf.rename, opts)
        end,
      },
    })
  end,
}
