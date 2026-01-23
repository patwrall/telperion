_:
_final: prev: {
  cudaPackages = prev.cudaPackages // {
    nsight_compute = prev.cudaPackages.nsight_compute.overrideAttrs (oldAttrs: {
      postInstall = (oldAttrs.postInstall or "") + ''
        mkdir -p $out/bin/target

        ln -s $out/bin/target/linux-desktop-glibc_2_11_3-x64 \
              $out/bin/target/linux-desktop-glibc_2_11_3-x86

        ln -s $out/sections $out/bin/sections
      '';
    });
  };
}
