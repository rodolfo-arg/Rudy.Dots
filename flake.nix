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
            home.packages = with pkgs; [
              zsh
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
            ] ++ [ unstablePkgs.nixd ];

            home.sessionVariables = {
              # Set environment variables
              ANDROID_HOME = androidHome;
              ANDROID_NDK_HOME = "${androidHome}/ndk/${ndkVersion}";
              ANDROID_SDK_ROOT = androidHome;
              CC = "/usr/bin/clang";
              CXX = "/usr/bin/clang++";
            };

            home.sessionPath = [
              "$HOME/.asdf/shims"
              "$HOME/.asdf/bin"
              "$HOME/.pub-cache/bin"
              "/opt/homebrew/bin"
              "/opt/homebrew/sbin"
              "${androidHome}/cmdline-tools/latest/bin"
              "${androidHome}/platform-tools"
            ];

            programs.zsh.enable = true;
            programs.neovim.enable = true;
            programs.git.enable = true;
            programs.starship.enable = true;
            programs.gh.enable = true;
            programs.home-manager.enable = true;
            programs.nixpkgs.config.allowUnfree = true;
          }];
        };
    in
    {
      homeConfigurations = {
        "rudy" = mkHomeConfiguration "aarch64-darwin" { };
      };
    };
}

