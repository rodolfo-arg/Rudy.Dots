{ lib, ... }:
{
  # Declaratively manage Neovim config via Home Manager
  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
    force = true;
  };

  # Keep Neovim plugins tidy and up to date on every switch
  home.activation.nvimLazyClean = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if command -v nvim >/dev/null 2>&1; then
      if command -v git >/dev/null 2>&1; then
        echo "[nvim] Cleaning removed plugins (Lazy)"
        nvim --headless "+Lazy! clean" +qa || true
      else
        echo "[nvim] Skipping Lazy clean (git not found)"
      fi
    fi
  '';
  home.activation.nvimLazySync = lib.hm.dag.entryAfter [ "nvimLazyClean" ] ''
    if command -v nvim >/dev/null 2>&1; then
      if command -v git >/dev/null 2>&1; then
        echo "[nvim] Syncing plugins (Lazy)"
        nvim --headless "+Lazy! sync" +qa || true
      else
        echo "[nvim] Skipping Lazy sync (git not found)"
      fi
    fi
  '';
}

