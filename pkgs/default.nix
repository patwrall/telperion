{ pkgs
, stable
, small
}:
{
  app2unit = pkgs.callPackage ./app2unit { };
}
