{ system ? builtins.currentSystem }:

let
  pin = builtins.fromJSON (builtins.readFile ./pinned-nixpkgs.json);

  nixpkgsSrc = builtins.fetchTarball {
     inherit (pin) url sha256;
  };
in

import nixpkgsSrc {
  inherit system;
  config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      # Required by Kibana for OpenDistro 1.8.0
      "nodejs-10.24.1"
    ];
  };
  overlays = []; # prevent impure overlays
}
