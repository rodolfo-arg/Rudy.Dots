{ config, pkgs, lib, ... }:
{
  programs.zsh = {
    # Enable completions
    enableCompletion = true;

    # zplug handled manually in initContent to avoid deprecation warnings
    zplug.enable = false;

    # Full .zshrc content (initExtra is deprecated; use initContent)
    initContent = ''
      # Init Dependencies
      eval "$(zoxide init zsh)"
      eval "$(atuin init zsh)"

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

      # Initialize asdf if installed (prefer ~/.asdf)
      if [ -f "''${ASDF_DIR:-$HOME/.asdf}/asdf.sh" ]; then
        . "''${ASDF_DIR:-$HOME/.asdf}/asdf.sh"
      fi

      [ -f "$HOME/sdk/google-cloud-sdk/path.zsh.inc" ] && source "$HOME/sdk/google-cloud-sdk/path.zsh.inc"
      [ -f "$HOME/sdk/google-cloud-sdk/completion.zsh.inc" ] && source "$HOME/sdk/google-cloud-sdk/completion.zsh.inc"

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
