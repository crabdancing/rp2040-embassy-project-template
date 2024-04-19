# FIXME: `cargo run` should automatically flash pico

{
  description = "Build a cargo project without extra checks";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, crane, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };
        rust = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-analyzer" "rust-src" ];
          targets = [ "x86_64-unknown-linux-gnu" "thumbv6m-none-eabi" ];
        };

        commonBuildInputs = with pkgs; [
          openocd-rp2040
          probe-rs
          flip-link
          elf2uf2-rs
        ];
        craneLib = (crane.mkLib pkgs).overrideToolchain rust;
                
        my-crate = craneLib.buildPackage {
          src = ./.; #craneLib.cleanCargoSource (craneLib.path ./.);
          strictDeps = true;

          nativeBuildInputs = commonBuildInputs;
          # Breaks on cross compile for RP2040
          doCheck = false;
          buildInputs = [
            # Add additional build inputs here
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];

          extraDummyScript = ''
            cp -a ${./memory.x} $out/memory.x
            rm -rf $out/src/bin/crane-dummy-*
          '';
          # Additional environment variables can be set directly
          # MY_CUSTOM_VAR = "some value";
        };
      in
      {
        checks = {
          inherit my-crate;
        };

        packages.default = my-crate;

        apps.default = flake-utils.lib.mkApp {
          drv = my-crate;
        };

        devShells.default = craneLib.devShell {
          # Inherit inputs from checks.
          checks = self.checks.${system};
          nativeBuildInputs = commonBuildInputs;

          # Additional dev-shell environment variables can be set directly
          # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

          # Extra inputs can be added here; cargo and rustc are provided by default.
          packages = [
            # pkgs.ripgrep
          ];
        };
      });
}
