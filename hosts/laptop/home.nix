{ pkgs, lib, unstable, ... }:
{
  home.packages = [
    pkgs.hurl
    pkgs.bat
    pkgs.shellcheck
    pkgs.ghostty
    pkgs.duckdb
    pkgs.obsidian
    pkgs.claude-code
    pkgs.discord
    pkgs.slack
    pkgs.firefox-devedition
    pkgs.gh
    pkgs.linode-cli
    unstable.awscli2
    pkgs.ledger-live-desktop
    pkgs.yt-dlp
    pkgs.exiftool
    pkgs.gimp
    pkgs.inkscape
    pkgs.krita
    pkgs.pinta
    pkgs.audacity
    pkgs.mpv
    pkgs.vlc
    pkgs.feh
    pkgs.playerctl
    pkgs.pavucontrol
    pkgs.gcc
    pkgs.python3

    pkgs.gopls

    pkgs.nixfmt-rfc-style

    # fonts
    pkgs.dejavu_fonts

    # sway
    pkgs.grim # screenshot functionality
    pkgs.slurp # screenshot functionality
    pkgs.wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
    pkgs.mako # notification system developed by swaywm maintainer
    pkgs.kanshi
    pkgs.sway-contrib.grimshot
    pkgs.wdisplays
    pkgs.swappy
  ];

  fonts.fontconfig.enable = true;

  programs = {
    ssh.enable = true;
    gpg.enable = true;
    fuzzel.enable = true;
    bat.enable = true;

    # Settings from https://github.com/mrzool/bash-sensible
    bash = {
      enable = true;

      historySize = 500000;
      historyFileSize = 100000;
      historyControl = [ "erasedups" "ignoreboth" ];
      historyIgnore = [ "&" "[ ]*" "exit" "ls" "bg" "fg" "history" "clear" ];

      shellOptions = [
        "checkwinsize"
        "globstar"
        "histappend"
        "cmdhist"
        "autocd"
        "dirspell"
        "cdspell"
        "cdable_vars"
      ];

      initExtra = ''
        set -o noclobber
        PROMPT_DIRTRIM=2
        HISTTIMEFORMAT='%F %T '

        # Append to PROMPT_COMMAND to avoid clobbering ghostty's integration
        PROMPT_COMMAND="''${PROMPT_COMMAND:+$PROMPT_COMMAND; }history -a"

        bind Space:magic-space
        bind "set completion-ignore-case on"
        bind "set completion-map-case on"
        bind "set show-all-if-ambiguous on"
        bind "set mark-symlinked-directories on"

        bind '"\e[A": history-search-backward'
        bind '"\e[B": history-search-forward'
        bind '"\e[C": forward-char'
        bind '"\e[D": backward-char'
      '';
    };

    ghostty = {
      enable = true;
      enableBashIntegration = true;
      installBatSyntax = true;
      installVimSyntax = true;
      settings = {
        font-size = 8;
        keybind = [
          "ctrl+h=goto_split:left"
          "ctrl+l=goto_split:right"
        ];
      };
    };

    git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user = {
          name = "Steven Jacobs";
          email = "stjacobs@fastmail.fm";
        };
        init.defaultBranch = "main";
        github.user = "stvnjacobs";
        gitlab.user = "stvnjacobs";
      };
    };

    emacs = {
      enable = true;
      package = pkgs.emacs-gtk;
      extraConfig = ''
        (setq standard-indent 2)
      '';
    };

    # TODO: mail accounts
    # inspiration: https://github.com/averyanalex/dotfiles/blob/main/profiles/mail.nix
    thunderbird = {
      enable = true;
      profiles = {
        default = {
          isDefault = true;
        };
      };
    };

    aerc = {
      enable = true;
      extraConfig = {};
    };

    tmux = {
      enable = true;
      clock24 = true;
      keyMode = "vi";
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    go = {
      enable = true;
      env = {
        GOPATH = "$HOME/code/go";
      };
    };
  };

  services = {
    gpg-agent.enable = true;
    emacs.enable = true;
    syncthing.enable = true;
    kanshi = {
      enable = true;
      systemdTarget = "sway-session.target";
      settings = [
        {
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "2256x1504@60";
              position = "0,0";
              status = "enable";
              scale = 1.8;
            }
          ];
        }

        {
          profile.outputs = [
            {
              criteria = "eDP-1";
              mode = "2256x1504@60";
              position = "3200,120";
              status = "enable";
              scale = 1.8;
            }
            {
              criteria = "Dell Inc. DELL U2723QE 7W4SXN3";
              mode = "3840x2160@60";
              position = "0,0";
              status = "enable";
              scale = 1.2;
            }
          ];
        }
      ];
    };
  };

  # reference - https://github.com/shaunsingh/nix-darwin-dotfiles/blob/631f4c9b5e6d2000a127a8f75ef461bfd9794b5a/sway/home.nix
  wayland.windowManager.sway = {
    enable = true;
    config = rec {
      modifier = "Mod4";
      menu = "${pkgs.fuzzel}/bin/fuzzel";
      terminal = "${pkgs.ghostty}/bin/ghostty";
      startup = [
        # Launch Firefox on start
        #{command = "firefox";}
      ];
      defaultWorkspace = "workspace number 1";
      input = {
        "keyboard" = {
          xkb_layout = "us";
        };
        "type:touchpad" = {
          tap = "disabled";
          natural_scroll = "enabled";
          accel_profile = "adaptive";
          click_method = "clickfinger";
          clickfinger_button_map = "lrm";
        };
      };
      output = {
        "*" = {
          background = "#4B5C43 solid_color";
        };
      };
      focus = {
        followMouse = "no";
      };
      #gaps = { };
      keybindings = lib.mkOptionDefault {
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        "XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
        "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +5%";
        "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -5%";
        "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
        "XF86AudioPlay" = "exec playerctl play-pause";
        "XF86AudioNext" = "exec playerctl next";
        "XF86AudioPrev" = "exec playerctl previous";
        # Screenshots:
        # Super+P: Current window
        # Super+Shift+p: Select area
        # Super+Alt+p Current output
        # Super+Ctrl+p Select a window
        "Mod4+p" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save active";
        "Mod4+Shift+p" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save area";
        "Mod4+Mod1+p" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save output";
        "Mod4+Ctrl+p" = "exec ${pkgs.sway-contrib.grimshot}/bin/grimshot save window";
      };
    };
    systemd = {
      enable = true;
    };
  };

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };

  # The state version is required and should stay at the version you
  # originally installed.
  home.stateVersion = "24.11";
}
