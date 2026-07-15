{ pkgs, ... }:
{
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
}
