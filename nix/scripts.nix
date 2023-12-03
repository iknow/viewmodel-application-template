{ system ? builtins.currentSystem
, pkgs ? import ./pinned-nixpkgs.nix { inherit system; } }:

let
  dependencies = import ./dependencies.nix { inherit pkgs; };
  services = pkgs.callPackage ./services.nix { inherit (dependencies) postgresql opensearch; };
in
{
  start-services = pkgs.writeScript "start-services" ''
    #!${pkgs.stdenv.shell} -e
    ${pkgs.coreutils}/bin/ln -sfT ${services.procfile} Procfile

    # Overmind does not work if SHELL is not POSIX-enough, for
    # example: fish. Force the use of bash here.
    export SHELL=$BASH

    # The default overmind port is 5000, which is also occupied by
    # AirPlay Receiver in macOS 12
    export OVERMIND_PORT="''${OVERMIND_PORT:-6000}"

    exec ${pkgs.overmind}/bin/overmind start
  '';
}
