{ pkgs
, ...
}:
{
  programs = {
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [ ];
}
