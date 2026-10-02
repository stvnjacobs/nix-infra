# Tangled spindle CI runner (microVM and nixery engines), behind nginx for TLS.
#
# microVM workflows run in PVM guests; enable nixos-pvm's host module
# (`pvm.host.enable`) alongside this module. The image is the flake's
# `spindle-image` package, passed in as `spindleImage`. The upstream module also
# enables Docker for `engine: nixery` workflows.
{
  config,
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
        # 4 GiB and 2 vCPUs per workflow. Nixery (Docker) workflows are not
        # counted here, so they compete with microVMs for that headroom.
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

  # spindle resolves `image: <name>` to <imageDir>/<name>/spec.json.
  systemd.tmpfiles.rules = [
    "d ${cfg.pipelines.microvm.imageDir} 0755 root root -"
    "L+ ${cfg.pipelines.microvm.imageDir}/nixos - - - - ${spindleImage}"
  ];
}
