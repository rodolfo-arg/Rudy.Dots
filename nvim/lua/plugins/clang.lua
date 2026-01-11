return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        cmd = { vim.fn.exepath("clangd") }, -- resolves to nix-provided clangd
      },
    },
  },
}
