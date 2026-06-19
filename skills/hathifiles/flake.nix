{
  # Local development shell for hathifiles.
  #
  # DEV convenience only — distribution is prebuilt static binaries via GitHub
  # releases (CI builds with opam on Alpine). It exists because OCaml libraries
  # can't be resolved from a bare NixOS profile; a devShell's setup hooks
  # expose the full closure on OCAMLPATH, so here `dune build` just works.
  #
  #   nix develop -c dune build --root src      # one-off
  #   direnv allow                              # auto-load via .envrc, then: dune build
  description = "hathifiles dev shell (OCaml toolchain + libraries)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.dune_3
            pkgs.curl # the tool execs `curl` at runtime to fetch the listing and files
          ]
            ++ (with pkgs.ocamlPackages; [
              ocaml
              findlib
              yojson
            ]);
        };
      });
    };
}
