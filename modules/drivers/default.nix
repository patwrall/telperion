{ inputs
, ...
}:
{
  imports = [
    "${inputs.self}/modules/drivers/vm-guest-services.nix"
  ];
}
