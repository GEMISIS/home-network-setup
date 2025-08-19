{
  description = "Home network setup using Nix flakes";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-nix-path = [ "nixpkgs=flake:nixpkgs" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      system = "x86_64-linux";
      pkgsUnfree = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.McAlister-Home = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.gemisis = import ./home/gemisis.nix;
          }
        ];
      };

      devShells.${system}.default = pkgsUnfree.mkShell {
        NIXPKGS_ALLOW_UNFREE = "1";
        NIX_CONFIG = ''
          experimental-features = nix-command flakes
          extra-nix-path = nixpkgs=flake:nixpkgs
        '';
      };
    };
}
