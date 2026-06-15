{
  # Local development shell for mint-gh-token.
  #
  # This is a DEV convenience only — it does not change how the tool is
  # distributed (prebuilt static binaries via GitHub releases; CI builds it
  # with opam on Alpine). It exists because OCaml libraries can't be resolved
  # from a bare NixOS profile: `environment.systemPackages` symlinks only the
  # listed libs, not their transitive propagated deps (x509 -> ohex, zarith,
  # mirage-crypto, asn1-combinators, ...). A devShell's setup hooks DO expose
  # the full closure on OCAMLPATH, so here `dune build` just works.
  #
  #   nix develop -c dune build --root src      # one-off
  #   direnv allow                              # auto-load via .envrc, then: dune build
  #
  # nixpkgs tracks nixos-26.05 to match the coeus system toolchain (ocaml
  # 5.4.1), so the compiler/lib closure is already in the local store.
  description = "mint-gh-token dev shell (OCaml toolchain + libraries)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      # The tool's two release targets.
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          # dune drives the build; the ocamlPackages set must come from one
          # pinned nixpkgs so the compiler and libs stay ABI-compatible.
          buildInputs = [
            pkgs.dune_3
            pkgs.curl # the tool execs `curl` at runtime to call the GitHub API
          ]
            ++ (with pkgs.ocamlPackages; [
              ocaml
              findlib
              # libraries the tool links against (see src/dune)
              x509
              base64
              yojson
              ptime
              mirage-crypto-rng # provides the .unix sublib that seeds the RNG
              logs # transitively required to link mirage-crypto-rng.unix
            ]);
        };
      });
    };
}
