{ config, pkgs, lib, ... }:
{
  programs.zsh = {
    # Enable completions
    enableCompletion = false;

    # zplug handled manually in initContent to avoid deprecation warnings
    zplug.enable = false;

    # Full .zshrc content (initExtra is deprecated; use initContent)
    initContent = ''
      # Init Dependencies
      eval "$(zoxide init zsh)"
      eval "$(atuin init zsh)"
      eval "$(starship init zsh)"

      # Extend homebrew
       if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
      else
        # Fallbacks for common locations
        for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
          if [ -x "$candidate" ]; then
            eval "$($candidate shellenv)"
            break
          fi
        done
      fi

      # Unset c/c++ related dependencies to avoid using nix's.
      unset CC
      unset CXX
      unset AR
      unset RANLIB
      unset STRIP
      unset LD
      unset AS
    '';
  };
}
