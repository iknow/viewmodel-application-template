{ system ? builtins.currentSystem
, pkgs ? import ./nix/pinned-nixpkgs.nix { inherit system; } }:

with pkgs;

let
  moergo_web = import ./default.nix { inherit pkgs; };
in

stdenvNoCC.mkDerivation {
  name = "shell";

  buildInputs = [
    bashInteractive gnutar
    moergo_web.bundleLock
    moergo_web.bundleEnv
    moergo_web.bundleEnv.wrappedRuby
  ] ++ moergo_web.developmentDependencies;

  MOERGO_WEB_BUNDLE_ENV_PATH = moergo_web.bundleEnv;

  src = lib.sourceByRegex ./. ["^Gemfile$" "^Gemfile\.lock$" "^gemset\.nix$"];
}
