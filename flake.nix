{
  description = ''Rudy: Performance-first nvim 
  configuration tailored for the following Tech Stack: 
  - Flutter/Dart
  - C/C++
  - Kotlin/Java
  - Objective-C/Swift
  - Lua
  - Nix
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; # Unstable Nixpkgs for latest packages
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      supportedSystems = [ "aarch64-darwin" ];

      commonModules = [
        ./ghostty.nix
        ./starship.nix
        ./nvim.nix
        ./zsh.nix
      ];

      mkHomeConfiguration = system: { username ? "rodolfo", homeDirectory ? "/Users/rodolfo" }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          unstablePkgs = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };

          androidHome = "${homeDirectory}/Library/Android/sdk";
          ndkVersion = "28.1.13356709";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          extraSpecialArgs = {
            inherit unstablePkgs;
          };

          modules = commonModules ++ [{
            home.username = username;
            home.homeDirectory = homeDirectory;
            home.stateVersion = "24.11";
            home.packages =
              let
                jdkPkg =
                  if builtins.hasAttr "jdk21" pkgs then
                    pkgs.jdk21
                  else if builtins.hasAttr "jdk17" pkgs then
                    pkgs.jdk17
                  else if builtins.hasAttr "jdk" pkgs then
                    pkgs.jdk
                  else
                    null;
                javaBin =
                  if jdkPkg != null then
                    "${jdkPkg}/bin/java"
                  else
                    "java";
                kotlinLspPkg = pkgs.stdenvNoCC.mkDerivation {
                  pname = "kotlin-lsp";
                  version = "261.13587.0";
                  src = pkgs.fetchzip {
                    url =
                      "https://download-cdn.jetbrains.com/kotlin-lsp/261.13587.0/kotlin-lsp-261.13587.0-mac-aarch64.zip";
                    hash = "sha256-zwlzVt3KYN0OXKr6sI9XSijXSbTImomSTGRGa+3zCK8=";
                    stripRoot = false;
                  };
                  dontConfigure = true;
                  dontBuild = true;
                  installPhase = ''
                    runHook preInstall
                    mkdir -p $out/lib/kotlin-lsp $out/bin
                    cp -R . $out/lib/kotlin-lsp
                    cat > $out/bin/kotlin-lsp <<'EOF'
                    #!${pkgs.bash}/bin/bash
                    set -euo pipefail

                    DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")/../lib/kotlin-lsp" && pwd)"
                    JAVA_BIN="''${JAVA_BIN:-${javaBin}}"

                    exec "$JAVA_BIN" \
                      --add-opens java.base/java.io=ALL-UNNAMED \
                      --add-opens java.base/java.lang=ALL-UNNAMED \
                      --add-opens java.base/java.lang.ref=ALL-UNNAMED \
                      --add-opens java.base/java.lang.reflect=ALL-UNNAMED \
                      --add-opens java.base/java.net=ALL-UNNAMED \
                      --add-opens java.base/java.nio=ALL-UNNAMED \
                      --add-opens java.base/java.nio.charset=ALL-UNNAMED \
                      --add-opens java.base/java.text=ALL-UNNAMED \
                      --add-opens java.base/java.time=ALL-UNNAMED \
                      --add-opens java.base/java.util=ALL-UNNAMED \
                      --add-opens java.base/java.util.concurrent=ALL-UNNAMED \
                      --add-opens java.base/java.util.concurrent.atomic=ALL-UNNAMED \
                      --add-opens java.base/java.util.concurrent.locks=ALL-UNNAMED \
                      --add-opens java.base/jdk.internal.vm=ALL-UNNAMED \
                      --add-opens java.base/sun.net.dns=ALL-UNNAMED \
                      --add-opens java.base/sun.nio.ch=ALL-UNNAMED \
                      --add-opens java.base/sun.nio.fs=ALL-UNNAMED \
                      --add-opens java.base/sun.security.ssl=ALL-UNNAMED \
                      --add-opens java.base/sun.security.util=ALL-UNNAMED \
                      --add-opens java.desktop/com.apple.eawt=ALL-UNNAMED \
                      --add-opens java.desktop/com.apple.eawt.event=ALL-UNNAMED \
                      --add-opens java.desktop/com.apple.laf=ALL-UNNAMED \
                      --add-opens java.desktop/com.sun.java.swing=ALL-UNNAMED \
                      --add-opens java.desktop/com.sun.java.swing.plaf.gtk=ALL-UNNAMED \
                      --add-opens java.desktop/java.awt=ALL-UNNAMED \
                      --add-opens java.desktop/java.awt.dnd.peer=ALL-UNNAMED \
                      --add-opens java.desktop/java.awt.event=ALL-UNNAMED \
                      --add-opens java.desktop/java.awt.font=ALL-UNNAMED \
                      --add-opens java.desktop/java.awt.image=ALL-UNNAMED \
                      --add-opens java.desktop/java.awt.peer=ALL-UNNAMED \
                      --add-opens java.desktop/javax.swing=ALL-UNNAMED \
                      --add-opens java.desktop/javax.swing.plaf.basic=ALL-UNNAMED \
                      --add-opens java.desktop/javax.swing.text=ALL-UNNAMED \
                      --add-opens java.desktop/javax.swing.text.html=ALL-UNNAMED \
                      --add-opens java.desktop/sun.awt=ALL-UNNAMED \
                      --add-opens java.desktop/sun.awt.X11=ALL-UNNAMED \
                      --add-opens java.desktop/sun.awt.datatransfer=ALL-UNNAMED \
                      --add-opens java.desktop/sun.awt.image=ALL-UNNAMED \
                      --add-opens java.desktop/sun.awt.windows=ALL-UNNAMED \
                      --add-opens java.desktop/sun.font=ALL-UNNAMED \
                      --add-opens java.desktop/sun.java2d=ALL-UNNAMED \
                      --add-opens java.desktop/sun.lwawt=ALL-UNNAMED \
                      --add-opens java.desktop/sun.lwawt.macosx=ALL-UNNAMED \
                      --add-opens java.desktop/sun.swing=ALL-UNNAMED \
                      --add-opens java.management/sun.management=ALL-UNNAMED \
                      --add-opens jdk.attach/sun.tools.attach=ALL-UNNAMED \
                      --add-opens jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
                      --add-opens jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED \
                      --add-opens jdk.jdi/com.sun.tools.jdi=ALL-UNNAMED \
                      --enable-native-access=ALL-UNNAMED \
                      -Djdk.lang.Process.launchMechanism=FORK \
                      -Djava.awt.headless=true \
                      -cp "$DIR/lib/*" com.jetbrains.ls.kotlinLsp.KotlinLspServerKt "$@"
                    EOF
                    chmod +x $out/bin/kotlin-lsp
                    runHook postInstall
                  '';
                  meta = with pkgs.lib; {
                    description = "Kotlin Language Server (official Kotlin LSP)";
                    homepage = "https://github.com/Kotlin/kotlin-lsp";
                    platforms = [ "aarch64-darwin" ];
                  };
                };
              in
              (with pkgs; [
                zoxide
                atuin
                jq
                starship
                nixpkgs-fmt
                ripgrep
                coreutils
                unzip
                bat
                lazygit
                fd
                gradle
                kotlin
                jdt-language-server # Java LSP for multi-layer navigation
              ])
              ++ pkgs.lib.optional (jdkPkg != null) jdkPkg
              ++ [ unstablePkgs.nixd kotlinLspPkg ];

            home.sessionVariables = {
              # Set environment variables
              ANDROID_HOME = androidHome;
              ANDROID_NDK_HOME = "${androidHome}/ndk/${ndkVersion}";
              ANDROID_SDK_ROOT = androidHome;
              ASDF_DIR = "${homeDirectory}/.asdf";
              ASDF_DATA_DIR = "${homeDirectory}/.asdf";
              CC = "/usr/bin/clang";
              CXX = "/usr/bin/clang++";
            };

            home.sessionPath = [
              "$HOME/.asdf/shims"
              "$HOME/.asdf/bin"
              "$HOME/.pub-cache/bin"
              "/opt/homebrew/bin"
              "/opt/homebrew/sbin"
              "/opt/homebrew/opt/python@3.14/libexec/bin"
              "${androidHome}/cmdline-tools/latest/bin"
              "${androidHome}/platform-tools"
            ];

            programs.zsh.enable = true;
            programs.neovim.enable = true;
            programs.git.enable = true;
            programs.starship.enable = true;
            programs.gh.enable = true;
            programs.home-manager.enable = true;
          }];
        };
    in
    {
      homeConfigurations = {
        "rudy" = mkHomeConfiguration "aarch64-darwin" { };
      };
    };
}
