{ profile
, ...
}: {
  services = {
    smartd = {
      enable =
        if profile == "vm"
        then false
        else true;
      autodetect = true;
    };
  };
}
