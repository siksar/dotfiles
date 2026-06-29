{ lib, ... }:

{
  options.desktop.theme = {
    colors = {
      bg = lib.mkOption {
        type = lib.types.str;
        default = "1a1b26";
        description = "Background color (Tokyo Night default)";
      };
      fg = lib.mkOption {
        type = lib.types.str;
        default = "a9b1d6";
        description = "Foreground color";
      };
      accent = lib.mkOption {
        type = lib.types.str;
        default = "7aa2f7";
        description = "Accent color";
      };
      activeBorder = lib.mkOption {
        type = lib.types.str;
        default = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        description = "Active window border gradient/color";
      };
      inactiveBorder = lib.mkOption {
        type = lib.types.str;
        default = "rgba(595959aa)";
        description = "Inactive window border color";
      };
    };
  };
}
