# Tangled spindle CI runner using the microVM engine, behind nginx for TLS.
#
# Workflows run in PVM guests; import modules/pvm-host.nix alongside this
# module. The image is the flake's `spindle-image` package, passed in as
# `spindleImage`.
{
  config,
  lib,
  spindleImage,
  ...
}:
let
  cfg = config.services.tangled.spindle;
in
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "stjacobs@fastmail.fm";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts.${cfg.server.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://${cfg.server.listenAddr}";
        # Workflow logs and events stream over WebSockets.
        proxyWebsockets = true;
      };
    };
  };

  services.tangled.spindle = {
    enable = true;
    # This host has no S3 credentials; keep workflow logs on the local disk.
    mill.artifactStore = "disk";
    artifactStores.disk.dir = "/var/lib/spindle/artifacts";
    # Stores are all written, so disable the upstream default S3 bucket.
    artifactStores.s3.bucket = "";
    server = {
      hostname = config.networking.fqdn;
      owner = "did:plc:eyfrtl2gxdohgbjf573dsj6m";
      listenAddr = "127.0.0.1:6555";
    };

    pipelines = {
      # PVM guests are slower than hardware KVM, and the timeout also covers
      # waiting for a slot and booting the VM.
      workflowTimeout = "30m";

      microvm = {
        defaultImage = "nixos";
        # Keep 2 GiB and the remaining vCPUs for the host. The image asks for
        # 4 GiB and 2 vCPUs per workflow.
        limits.total = {
          memoryMiB = 6144;
          vcpus = 4;
        };
        # Contain each VM in a cgroup so an OOM kills the workflow, not
        # spindle.
        cgroup.enable = true;
      };

      # Guests substitute through spindle's read proxy; without an upstream
      # they build every dependency from source.
      nixCache = {
        readUrls = [ "https://cache.nixos.org" ];
        trustedPublicKeys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
      };
    };
  };

  # spindle retries Jetstream in a tight loop without backoff; starting before
  # DNS works floods the journal with thousands of lookup errors at boot.
  systemd.services.spindle = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # The upstream module enables Docker for the nixery engine. This spindle only
  # runs microVM workflows, and the PVM host kernel lacks the nftables support
  # Docker's iptables uses.
  virtualisation.docker.enable = lib.mkForce false;

  pvm.host.extraKernelConfig = ''
    # QEMU's per-workflow networking (slirp4netns).
    CONFIG_TUN=m
    # spindle applies per-workflow CPU limits through cgroup v2 cpu.max.
    CONFIG_CFS_BANDWIDTH=y
    # QEMU uses unshare user namespaces to isolate each VM's network.
    CONFIG_USER_NS=y
  '';

  # spindle resolves `image: <name>` to <imageDir>/<name>/spec.json.
  systemd.tmpfiles.rules = [
    "d ${cfg.pipelines.microvm.imageDir} 0755 root root -"
    "L+ ${cfg.pipelines.microvm.imageDir}/nixos - - - - ${spindleImage}"
  ];
}
