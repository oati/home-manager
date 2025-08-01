{
  pkgs,
  config,
  lib,
  ...
}:
let

  cfg = config.programs.vscode.haskell;

  defaultHieNixExe = hie-nix.hies + "/bin/hie-wrapper";
  defaultHieNixExeText = lib.literalExpression ''"''${pkgs.hie-nix.hies}/bin/hie-wrapper"'';

  hie-nix =
    pkgs.hie-nix or (abort ''
      vscode.haskell: pkgs.hie-nix missing. Please add an overlay such as:
      ${exampleOverlay}
    '');

  exampleOverlay = ''
    nixpkgs.overlays = [
      (self: super: { hie-nix = import ~/src/hie-nix {}; })
    ]
  '';

in
{
  options.programs.vscode.haskell = {
    enable = lib.mkEnableOption "Haskell integration for Visual Studio Code";

    hie.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Haskell IDE engine integration.";
    };

    hie.executablePath = lib.mkOption {
      type = lib.types.path;
      default = defaultHieNixExe;
      defaultText = defaultHieNixExeText;
      description = ''
        The path to the Haskell IDE Engine executable.

        Because hie-nix is not packaged in Nixpkgs, you need to add it as an
        overlay or set this option. Example overlay configuration:

        ```nix
        ${exampleOverlay}
        ```
      '';
      example = lib.literalExpression ''
        (import ~/src/haskell-ide-engine {}).hies + "/bin/hie-wrapper";
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscode.profiles.default.userSettings = lib.mkIf cfg.hie.enable {
      "languageServerHaskell.enableHIE" = true;
      "languageServerHaskell.hieExecutablePath" = cfg.hie.executablePath;
    };

    programs.vscode.profiles.default.extensions = [
      pkgs.vscode-extensions.justusadam.language-haskell
    ]
    ++ lib.optional cfg.hie.enable pkgs.vscode-extensions.alanz.vscode-hie-server;
  };
}
