{ system ? builtins.currentSystem
, pkgs ? import ./nix/pinned-nixpkgs.nix { inherit system; } }:

with pkgs;

let
  demoapp = import ./default.nix { inherit pkgs; };
in

stdenvNoCC.mkDerivation {
  name = "shell";

  buildInputs = [
    bashInteractive gnutar
    demoapp.bundleLock
    demoapp.bundleEnv
    demoapp.bundleEnv.wrappedRuby
  ] ++ demoapp.developmentDependencies;

  DEMOAPP_BUNDLE_ENV_PATH = demoapp.bundleEnv;

  src = lib.sourceByRegex ./. ["^Gemfile$" "^Gemfile\.lock$" "^gemset\.nix$"];
}
