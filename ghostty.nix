{ pkgs, lib, config, ... }:
let
  sourceDir = ./ghostty;
in
{
  # Single source of truth: XDG path
  home.file.".config/ghostty" = {
    source = sourceDir;
    recursive = true;
    force = true;
  };

  # macOS: Ghostty uses bundle path under Application Support
  # Correct path: ~/Library/Application Support/com.mitchellh.ghostty
  home.file."Library/Application Support/com.mitchellh.ghostty" = lib.mkIf pkgs.stdenv.isDarwin {
    source = sourceDir;
    recursive = true;
    force = true;
  };

  # Cleanup: if an older path ".../ghostty" exists as a Nix symlink, remove it
  home.activation.cleanupOldGhosttyPath = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      OLD_PATH="$HOME/Library/Application Support/ghostty"
      if [ -L "$OLD_PATH" ]; then
        TARGET=$(readlink "$OLD_PATH" || true)
        case "$TARGET" in
          /nix/store/*)
            echo "Removing old Ghostty symlink: $OLD_PATH -> $TARGET"
            rm -f "$OLD_PATH"
            ;;
        esac
      fi
    ''
  );
}

