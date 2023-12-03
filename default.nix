{ system ? builtins.currentSystem
, pkgs ? import ./nix/pinned-nixpkgs.nix { inherit system; }
, isRelease ? false }:

let
  inherit (import ./nix/dependencies.nix { inherit pkgs isRelease; }) bundler bundix ruby postgresql opensearch psql ociTools;

  inherit (pkgs) lib callPackage writeShellScript makeWrapper runCommand buildEnv writeShellScriptBin;

  services = callPackage ./nix/services.nix { inherit postgresql opensearch; };
  main     = callPackage ./nix/demoapp.nix { inherit ruby bundler postgresql; };
in

rec {
  inherit (main) bundleEnv bundleProdEnv demoapp uuidTools runtimeDependencies;

  # To run services
  #  ./nix/start-services
  # To build a procfile:
  #  nix-build -A services.procfile -o services.procfile
  # Or to run services directly:
  #  PORT=10000 nix shell -f . services.environment -c start-redis
  inherit services;

  developmentDependencies = with pkgs; runtimeDependencies ++ [
    postgresql jq coreutils
  ];

  # To update Gemfile.lock/gemset.nix
  # nix shell -f . bundleLock -c bundleLock
  bundleLock = writeShellScriptBin "bundleLock" ''
    set -e
    ${bundler}/bin/bundle lock "$@"
    ${bundix}/bin/bundix
  '';

  # To update nix/pinned-nixpkgs.json
  # nix shell -f . updatePin -c updatePin
  updatePin = writeShellScriptBin "updatePin" ''
    ${ruby}/bin/ruby ${./nix/generate-pin.rb} > nix/pinned-nixpkgs.json
  '';

  inherit ruby postgresql psql bundix ociTools;
}
