{ pkgs
, inputs
, username
, host
, profile
, ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix) gitUsername;
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit inputs username host profile; };
    users.${username} = {
      imports = [ ./../home ];
      home = {
        username = "${username}";
        homeDirectory = "/home/${username}";
        sessionVariables = {
          EDITOR = "nvim";
        };
        stateVersion = "25.05";
      };
    };
  };
  users.mutableUsers = true;
  users.users.${username} = {
    isNormalUser = true;
    description = "${gitUsername}";
    extraGroups = [
      "docker"
      "libvirtd"
      "networkmanager"
      "scanner"
      "wheel"
      "vboxusers"
    ];
    shell = pkgs.fish;
  };
  nix.settings.allowed-users = [ "${username}" ];
}
