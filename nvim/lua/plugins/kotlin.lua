local function ensure_list(list, value)
  if not vim.tbl_contains(list, value) then
    table.insert(list, value)
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      ensure_list(opts.ensure_installed, "kotlin")
      -- Always try to install missing parsers instead of hard-failing on open.
      opts.auto_install = true
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      local function resolve_kotlin_lsp()
        local bin = vim.fn.exepath("kotlin-lsp")
        if bin ~= "" then
          return { bin }
        end
        local home = vim.env.HOME or vim.fn.expand("~")
        local nix_bin = home .. "/.nix-profile/bin/kotlin-lsp"
        if vim.fn.executable(nix_bin) == 1 then
          return { nix_bin }
        end
        local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/kotlin-lsp"
        if vim.fn.executable(mason_bin) == 1 then
          return { mason_bin }
        end
        if vim.loop.fs_stat(mason_bin) then
          return { "bash", mason_bin }
        end
        return nil
      end

      local kotlin_lsp_cmd = resolve_kotlin_lsp() or { "kotlin-lsp" }
      local system_path = vim.fn.stdpath("cache") .. "/kotlin_lsp"
      local kotlin_lsp_cmd_with_args = vim.list_extend(vim.deepcopy(kotlin_lsp_cmd), {
        "--stdio",
        "--system-path",
        system_path,
      })
      -- Ensure the deprecated kotlin-language-server isn't started.
      opts.servers.kotlin_language_server = { enabled = false }
      opts.servers.kotlin_lsp = {
        cmd = kotlin_lsp_cmd_with_args,
        mason = false,
        filetypes = { "kotlin" },
        root_markers = {
          "workspace.json",
          "settings.gradle",
          "settings.gradle.kts",
          "build.gradle",
          "build.gradle.kts",
          "pom.xml",
          ".git",
        },
      }

      -- Attach Kotlin LSP to zipfile:// buffers (jar sources) where root detection fails.
      -- Handles both Kotlin and Java files for cross-language navigation.
      if not vim.g.__kotlin_zipfile_autocmd then
        vim.g.__kotlin_zipfile_autocmd = true

        local function attach_kotlin_lsp_to_zipfile(bufnr)
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          if not bufname:match("^zipfile://") then
            return
          end

          -- Find active kotlin_lsp clients
          local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
          if #clients == 0 then
            return
          end

          for _, client in ipairs(clients) do
            if not vim.lsp.buf_is_attached(bufnr, client.id) then
              -- Attach client to buffer
              vim.lsp.buf_attach_client(bufnr, client.id)

              -- Explicitly notify LSP about the document with correct jar: URI
              -- This ensures the LSP knows this buffer corresponds to an indexed source
              vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(bufnr) then
                  return
                end
                local uri = vim.uri_from_bufnr(bufnr)
                local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                local text = table.concat(lines, "\n")
                local ft = vim.bo[bufnr].filetype
                local lang_id = ft == "kotlin" and "kotlin" or "java"

                -- Send didOpen notification with jar: URI
                client:notify("textDocument/didOpen", {
                  textDocument = {
                    uri = uri,
                    languageId = lang_id,
                    version = 0,
                    text = text,
                  },
                })
              end)
            end
          end
        end

        -- Handle both Kotlin and Java files in jar sources
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "kotlin", "java" },
          callback = function(args)
            attach_kotlin_lsp_to_zipfile(args.buf)
          end,
        })

        -- Also try on BufReadPost for files that may have filetype set later
        vim.api.nvim_create_autocmd("BufReadPost", {
          pattern = "zipfile://*",
          callback = function(args)
            -- Defer to let filetype detection happen first
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(args.buf) then
                local ft = vim.bo[args.buf].filetype
                if ft == "kotlin" or ft == "java" then
                  attach_kotlin_lsp_to_zipfile(args.buf)
                end
              end
            end, 100)
          end,
        })
      end
    end,
  },
}
