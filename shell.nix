{ pkgs ? import <nixpkgs> { } }:
let
  python-pkgs = pkgs.python3.withPackages (p: [
      p.pyaml
  ]);
in
pkgs.stdenvNoCC.mkDerivation {
  name = "shell";
  nativeBuildInputs = with pkgs; [
    gnumake
    python-pkgs
    #autoconf automake pkgconfig libtool python3
  ];
}
