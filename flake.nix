{
  description = "fak-ch58";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    naersk.url = "github:nix-community/naersk";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      naersk = pkgs.callPackage inputs.naersk {};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = 
          let
            wchisp = naersk.buildPackage rec {
              pname = "wchisp";
              version = "0.3-git";
              src = pkgs.fetchFromGitHub {
                owner = "ch32-rs";
                repo = pname;
                rev = "4b4787243ef9bc87cbbb0d95c7482b4f7c9838f1";
                hash = "sha256-Ju2DBv3R4O48o8Fk/AFXOBIsvGMK9hJ8Ogxk47f7gcU=";
              };
            };
          in
          with pkgs; [
          	zig
          	zls
            wchisp
          ];
      };
    };
}
