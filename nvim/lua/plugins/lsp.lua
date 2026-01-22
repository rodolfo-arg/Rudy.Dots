-- Guard LazyVim's Mason integration on first start.
-- If mason-lspconfig isn't installed yet, disable Mason integration to avoid
-- 'module mason-lspconfig.mappings.server not found' errors during bootstrap.
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      if not vim.g.__jar_uri_to_fname_patched then
        vim.g.__jar_uri_to_fname_patched = true
        local orig_uri_to_fname = vim.uri_to_fname
        local orig_uri_from_fname = vim.uri_from_fname

        local function zipfile_to_jar(fname)
          local rest = fname:sub(11)
          local jar_part, inner = rest:match("^(.-)::(.+)$")
          jar_part = jar_part or rest
          if inner and inner ~= "" then
            inner = inner:gsub("^/+", "")
          end
          if jar_part == "" then
            return orig_uri_from_fname(fname)
          end
          local file_uri = orig_uri_from_fname(jar_part)
          if inner and inner ~= "" then
            return "jar:" .. file_uri .. "!/" .. inner
          end
          return "jar:" .. file_uri .. "!/"
        end

        vim.uri_from_fname = function(fname)
          if type(fname) == "string" and fname:sub(1, 10) == "zipfile://" then
            return zipfile_to_jar(fname)
          end
          return orig_uri_from_fname(fname)
        end

        vim.uri_to_fname = function(uri)
          if type(uri) == "string" and uri:sub(1, 4) == "jar:" then
            local rest = uri:sub(5)
            local jar_part, inner = rest:match("^(.-)!/(.+)$")
            if not jar_part then
              jar_part = rest:match("^(.-)!$")
            end
            jar_part = jar_part or rest
            local jar_path
            if jar_part:match("^file:") then
              jar_path = orig_uri_to_fname(jar_part)
            else
              jar_path = vim.uri_decode(jar_part):gsub("^/*", "/")
            end
            if inner and inner ~= "" then
              inner = inner:gsub("^/+", "")
            end
            if jar_path ~= "" then
              local zip_uri = "zipfile://" .. jar_path
              if inner and inner ~= "" then
                zip_uri = zip_uri .. "::" .. inner
              else
                zip_uri = zip_uri .. "::"
              end
              return zip_uri
            end
          end
          return orig_uri_to_fname(uri)
        end
      end

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
