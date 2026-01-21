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
                  if builtins.hasAttr "jdk17" pkgs then
                    pkgs.jdk17
                  else if builtins.hasAttr "jdk" pkgs then
                    pkgs.jdk
                  else
                    null;
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
              ])
              ++ pkgs.lib.optional (jdkPkg != null) jdkPkg
              ++ [ unstablePkgs.nixd ]
              ++ (if builtins.hasAttr "kotlin-language-server" pkgs then
                [ pkgs."kotlin-language-server" ]
              else if builtins.hasAttr "kotlin-language-server" unstablePkgs then
                [ unstablePkgs."kotlin-language-server" ]
              else
                [ ]);

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
