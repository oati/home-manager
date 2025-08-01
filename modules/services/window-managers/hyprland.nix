{
  config,
  lib,
  pkgs,
  ...
}:
let

  cfg = config.wayland.windowManager.hyprland;

  variables = builtins.concatStringsSep " " cfg.systemd.variables;
  extraCommands = builtins.concatStringsSep " " (map (f: "&& ${f}") cfg.systemd.extraCommands);
  systemdActivation = ''
    exec-once = ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd ${variables} ${extraCommands}
  '';
in
{
  meta.maintainers = [ lib.maintainers.fufexan ];

  # A few option removals and renames to aid those migrating from the upstream
  # module.
  imports = [
    (lib.mkRemovedOptionModule # \
      [ "wayland" "windowManager" "hyprland" "disableAutoreload" ]
      "Autoreloading now always happens"
    )

    (lib.mkRemovedOptionModule # \
      [ "wayland" "windowManager" "hyprland" "recommendedEnvironment" ]
      "Recommended environment variables are now always set"
    )

    (lib.mkRemovedOptionModule # \
      [ "wayland" "windowManager" "hyprland" "xwayland" "hidpi" ]
      "HiDPI patches are deprecated. Refer to https://wiki.hypr.land/Configuring/XWayland"
    )

    (lib.mkRemovedOptionModule # \
      [ "wayland" "windowManager" "hyprland" "nvidiaPatches" ] # \
      "Nvidia patches are no longer needed"
    )
    (lib.mkRemovedOptionModule # \
      [ "wayland" "windowManager" "hyprland" "enableNvidiaPatches" ] # \
      "Nvidia patches are no longer needed"
    )

    (lib.mkRenamedOptionModule # \
      [ "wayland" "windowManager" "hyprland" "systemdIntegration" ] # \
      [ "wayland" "windowManager" "hyprland" "systemd" "enable" ]
    )
  ];

  options.wayland.windowManager.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable configuration for Hyprland, a tiling Wayland
        compositor that doesn't sacrifice on its looks.

        ::: {.note}
        This module configures Hyprland and adds it to your user's {env}`PATH`,
        but does not make certain system-level changes. NixOS users should
        enable the NixOS module with {option}`programs.hyprland.enable`, which
        makes system-level changes such as adding a desktop session entry.
        :::
      '';
    };

    package = lib.mkPackageOption pkgs "hyprland" {
      nullable = true;
      extraDescription = "Set this to null if you use the NixOS module to install Hyprland.";
    };

    portalPackage = lib.mkPackageOption pkgs "xdg-desktop-portal-hyprland" {
      nullable = true;
    };

    finalPackage = lib.mkOption {
      type = with lib.types; nullOr package;
      readOnly = true;
      default =
        if cfg.package != null then
          cfg.package.override { enableXWayland = cfg.xwayland.enable; }
        else
          null;
      defaultText = lib.literalMD "`wayland.windowManager.hyprland.package` with applied configuration";
      description = ''
        The Hyprland package after applying configuration.
      '';
    };

    finalPortalPackage = lib.mkOption {
      type = with lib.types; nullOr package;
      readOnly = true;
      default =
        if (cfg.portalPackage != null) then
          if cfg.finalPackage != null then
            cfg.portalPackage.override { hyprland = cfg.finalPackage; }
          else
            cfg.portalPackage
        else
          null;
      defaultText = lib.literalMD ''
        `wayland.windowManager.hyprland.portalPackage` with
                `wayland.windowManager.hyprland.finalPackage` override'';
      description = ''
        The xdg-desktop-portal-hyprland package after overriding its hyprland input.
      '';
    };

    plugins = lib.mkOption {
      type = with lib.types; listOf (either package path);
      default = [ ];
      description = ''
        List of Hyprland plugins to use. Can either be packages or
        absolute plugin paths.
      '';
    };

    systemd = {
      enable = lib.mkEnableOption null // {
        default = true;
        description = ''
          Whether to enable {file}`hyprland-session.target` on
          hyprland startup. This links to `graphical-session.target`.
          Some important environment variables will be imported to systemd
          and D-Bus user environment before reaching the target, including
          - `DISPLAY`
          - `HYPRLAND_INSTANCE_SIGNATURE`
          - `WAYLAND_DISPLAY`
          - `XDG_CURRENT_DESKTOP`
        '';
      };

      variables = lib.mkOption {
        type = with lib.types; listOf str;
        default = [
          "DISPLAY"
          "HYPRLAND_INSTANCE_SIGNATURE"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
        ];
        example = [ "--all" ];
        description = ''
          Environment variables to be imported in the systemd & D-Bus user
          environment.
        '';
      };

      extraCommands = lib.mkOption {
        type = with lib.types; listOf str;
        default = [
          "systemctl --user stop hyprland-session.target"
          "systemctl --user start hyprland-session.target"
        ];
        description = "Extra commands to be run after D-Bus activation.";
      };

      enableXdgAutostart = lib.mkEnableOption ''
        autostart of applications using
        {manpage}`systemd-xdg-autostart-generator(8)`'';
    };

    xwayland.enable = lib.mkEnableOption "XWayland" // {
      default = true;
    };

    settings = lib.mkOption {
      type =
        with lib.types;
        let
          valueType =
            nullOr (oneOf [
              bool
              int
              float
              str
              path
              (attrsOf valueType)
              (listOf valueType)
            ])
            // {
              description = "Hyprland configuration value";
            };
        in
        valueType;
      default = { };
      description = ''
        Hyprland configuration written in Nix. Entries with the same key
        should be written as lists. Variables' and colors' names should be
        quoted. See <https://wiki.hypr.land> for more examples.

        ::: {.note}
        Use the [](#opt-wayland.windowManager.hyprland.plugins) option to
        declare plugins.
        :::

      '';
      example = lib.literalExpression ''
        {
          decoration = {
            shadow_offset = "0 5";
            "col.shadow" = "rgba(00000099)";
          };

          "$mod" = "SUPER";

          bindm = [
            # mouse movements
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
            "$mod ALT, mouse:272, resizewindow"
          ];
        }
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        # window resize
        bind = $mod, S, submap, resize

        submap = resize
        binde = , right, resizeactive, 10 0
        binde = , left, resizeactive, -10 0
        binde = , up, resizeactive, 0 -10
        binde = , down, resizeactive, 0 10
        bind = , escape, submap, reset
        submap = reset
      '';
      description = ''
        Extra configuration lines to add to `~/.config/hypr/hyprland.conf`.
      '';
    };

    sourceFirst =
      lib.mkEnableOption ''
        putting source entries at the top of the configuration
      ''
      // {
        default = true;
      };

    importantPrefixes = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "$"
        "bezier"
        "name"
        "output"
      ];
      example = [
        "$"
        "bezier"
      ];
      description = ''
        List of prefix of attributes to source at the top of the config.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "wayland.windowManager.hyprland" pkgs lib.platforms.linux)
    ];

    warnings =
      let
        inconsistent =
          (cfg.systemd.enable || cfg.plugins != [ ]) && cfg.extraConfig == "" && cfg.settings == { };
        warning = "You have enabled hyprland.systemd.enable or listed plugins in hyprland.plugins but do not have any configuration in hyprland.settings or hyprland.extraConfig. This is almost certainly a mistake.";
      in
      lib.optional inconsistent warning;

    home.packages = lib.mkIf (cfg.package != null) (
      [ cfg.finalPackage ] ++ lib.optional cfg.xwayland.enable pkgs.xwayland
    );

    xdg.configFile."hypr/hyprland.conf" =
      let
        shouldGenerate =
          cfg.systemd.enable || cfg.extraConfig != "" || cfg.settings != { } || cfg.plugins != [ ];

        importantPrefixes = cfg.importantPrefixes ++ lib.optional cfg.sourceFirst "source";

        pluginsToHyprconf =
          plugins:
          lib.hm.generators.toHyprconf {
            attrs = {
              "exec-once" =
                let
                  mkEntry =
                    entry: if lib.types.package.check entry then "${entry}/lib/lib${entry.pname}.so" else entry;
                in
                map (p: "hyprctl plugin load ${mkEntry p}") cfg.plugins;
            };
            inherit importantPrefixes;
          };
      in
      lib.mkIf shouldGenerate {
        text =
          lib.optionalString cfg.systemd.enable systemdActivation
          + lib.optionalString (cfg.plugins != [ ]) (pluginsToHyprconf cfg.plugins)
          + lib.optionalString (cfg.settings != { }) (
            lib.hm.generators.toHyprconf {
              attrs = cfg.settings;
              inherit importantPrefixes;
            }
          )
          + lib.optionalString (cfg.extraConfig != "") cfg.extraConfig;

        onChange = lib.mkIf (cfg.package != null) ''
          (
            XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
            if [[ -d "/tmp/hypr" || -d "$XDG_RUNTIME_DIR/hypr" ]]; then
              for i in $(${cfg.finalPackage}/bin/hyprctl instances -j | jq ".[].instance" -r); do
                ${cfg.finalPackage}/bin/hyprctl -i "$i" reload config-only
              done
            fi
          )
        '';
      };

    xdg.portal = {
      enable = cfg.finalPortalPackage != null;
      extraPortals = lib.mkIf (cfg.finalPortalPackage != null) [ cfg.finalPortalPackage ];
      configPackages = lib.mkIf (cfg.finalPackage != null) (lib.mkDefault [ cfg.finalPackage ]);
    };

    systemd.user.targets.hyprland-session = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Hyprland compositor session";
        Documentation = [ "man:systemd.special(7)" ];
        BindsTo = [ "graphical-session.target" ];
        Wants = [
          "graphical-session-pre.target"
        ]
        ++ lib.optional cfg.systemd.enableXdgAutostart "xdg-desktop-autostart.target";
        After = [ "graphical-session-pre.target" ];
        Before = lib.mkIf cfg.systemd.enableXdgAutostart [ "xdg-desktop-autostart.target" ];
      };
    };
  };
}
