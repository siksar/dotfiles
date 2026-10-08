# `nix repl ./` gibi flake'siz araçlar için kapı; rebuild yolu değil.
(builtins.getFlake (toString ./.)).outputs
