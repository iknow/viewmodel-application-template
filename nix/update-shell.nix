{ system ? builtins.currentSystem
, pkgs ? import ./pinned-nixpkgs.nix { inherit system; } }:

let
  inherit (import ./dependencies.nix { inherit pkgs; isRelease = false; }) bundix bundler;
in
pkgs.mkShell {
  packages = [ bundix bundler ];
}
