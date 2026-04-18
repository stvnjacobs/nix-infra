# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  unstable = import <nixos-unstable> { };
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (import "${home-manager}/nixos")
    (modulesPath + "/hardware/video/displaylink.nix")
  ];

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    initrd.luks.devices."luks-5cd798f5-c333-4002-8c40-ca01c148bf9b".device =
      "/dev/disk/by-uuid/5cd798f5-c333-4002-8c40-ca01c148bf9b";

    plymouth.enable = true;
  };

  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true; # needed for NFS

  systemd.mounts = [
    {
      type = "nfs";
      mountConfig = {
        Options = "noatime";
      };
      what = "nas:/volume1/photo";
      where = "/mnt/nas/photo";
    }
  ];

  systemd.automounts = [
    {
      wantedBy = [ "multi-user.target" ];
      automountConfig = {
        TimeoutIdleSec = "600";
      };
      where = "/mnt/nas/photo";
    }
  ];

  security.polkit.enable = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Disable NetworkManager's internal DNS resolution
  networking.networkmanager.dns = "systemd-resolved";
  
  # Configure DNS servers manually (this example uses Cloudflare and Google DNS)
  # IPv6 DNS servers can be used here as well.
  networking.nameservers = [
    "45.90.28.0#2e28e3.dns.nextdns.io"
    "2a07:a8c0::#2e28e3.dns.nextdns.io"
    "45.90.30.0#2e28e3.dns.nextdns.io"
    "2a07:a8c1::#2e28e3.dns.nextdns.io"
  ];

  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [
      "45.90.28.0#2e28e3.dns.nextdns.io"
      "2a07:a8c0::#2e28e3.dns.nextdns.io"
      "45.90.30.0#2e28e3.dns.nextdns.io"
      "2a07:a8c1::#2e28e3.dns.nextdns.io"
    ];
    dnsovertls = "true";
  };

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  powerManagement.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.desktopManager.gnome = {
    enable = true;
    extraGSettingsOverridePackages = [ pkgs.mutter ];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
  };

  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [
      pkgs.gutenprint
      pkgs.brlaser
      pkgs.brgenml1lpr
      pkgs.brgenml1cupswrapper
    ];
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  hardware.keyboard.qmk.enable = true;
  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Enable the gnome-keyring secrets vault.
  # Will be exposed through DBus to programs willing to store secrets.
  services.gnome.gnome-keyring.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.steven = {
    isNormalUser = true;
    description = "Steven Jacobs";
    # libvirt - libvird
    # sway brightness control on laptop - video
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "video"
    ];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  home-manager.users.steven =
    { pkgs, ... }:
    {
      # Enable the unfree packages
      nixpkgs.config.allowUnfree = true;

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
        pkgs.linode-cli
        pkgs.ledger-live-desktop
        pkgs.exiftool
        pkgs.gimp
        pkgs.inkscape
        pkgs.krita
        pkgs.pinta
        pkgs.swappy
        pkgs.audacity
        pkgs.mpv
        pkgs.vlc
        pkgs.playerctl
        pkgs.pavucontrol
        pkgs.gcc

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
      ];

      fonts.fontconfig.enable = true;

      programs = {
        ssh.enable = true;
        gpg.enable = true;
        fuzzel.enable = true;
        bat.enable = true;

        bash = {
          enable = true;
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
        ssh-agent.enable = true;
        emacs.enable = true;
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
    };

  programs.firefox.enable = true;

  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    ripgrep
    htop
    jq
    fd
    fzf
    (aspellWithDicts (
      dicts: with dicts; [
        en
        en-computers
        en-science
      ]
    ))
    libreoffice-qt
    languagetool
    vim
    google-chrome
    gnomeExtensions.night-theme-switcher

    man-pages
    man-pages-posix

    # containers
    dive # look into docker image layers
    podman-tui # status of containers in the terminal
    #docker-compose # start group of containers for dev
    podman-compose # start group of containers for dev
    buildah
    skopeo

    # TODO: unstable in home manager
    unstable.jujutsu
    unstable.xan
    unstable.zed-editor

    # photo/video
    losslesscut-bin

    via
    dos2unix
    unstable.qmk
    unstable.qmk-udev-rules
  ];

  documentation.man = {
    #generateCaches = true;

    man-db.enable = false;
    mandoc.enable = true;
  };

  # sway
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  programs.light.enable = true;

  # libvirt
  programs.virt-manager.enable = true;
  # TODO: groups
  users.groups.libvirtd.members = [ "steven" ];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  virtualisation.containers.enable = true;
  virtualisation = {
    podman = {
      enable = true;

      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "steven" ];
  };

  programs.mtr.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  networking.firewall = {
    enable = true; 
    #allowedTCPPorts = [ 4321 ];
    trustedInterfaces = [ "tailscale0" ];
  };
  
  services.fwupd.enable = true;
  services.fprintd.enable = true;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  services.udev = {
    extraRules = ''
      # HW.1, Nano
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="1b7c|2b7c|3b7c|4b7c", TAG+="uaccess", TAG+="udev-acl"
      
      # Blue, NanoS, Aramis, HW.2, Nano X, NanoSP, Stax, Ledger Test,
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="2c97", TAG+="uaccess", TAG+="udev-acl"
      
      # Same, but with hidraw-based library (instead of libusb)
      KERNEL=="hidraw*", ATTRS{idVendor}=="2c97", MODE="0666"
    '';
    packages = with pkgs; [ via ];
  }; 

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
