{ host
, lib
, ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix) sshEnable;
in
{
  services.openssh = lib.mkIf sshEnable {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
    };
    ports = [ 22 ];
  };
}
