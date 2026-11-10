{ config, lib, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  src = pkgs.fetchFromGitHub {
    owner = "Zagitta";
    repo = "gpu-unlock";
    rev = "7eb51bccae0a0b7e599e084d971170e9a1e82d0c";
    hash = "sha256-1KD/J1S1uyI5GGoTwQ1cU/sXeEKlG54exSvi6U+j73M=";
  };

  firmwareSrcKernel = pkgs.fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-610.43.03.tar.xz";
    sha256 = "7e118923c7a23edc36114d63273a46e3e04e9af98695a42203e7ac2dfe9fc1dc";
  };

  firmwareSrcInstaller = pkgs.fetchurl {
    url = "https://download.nvidia.com/XFree86/Linux-x86_64/610.43.03/NVIDIA-Linux-x86_64-610.43.03-no-compat32.run";
    sha256 = "e084451db730a6df29d3d74f655749c4d236e3c945f7d94b5205e84318fe2f90";
  };

  gpuUnlockFirmware = pkgs.stdenv.mkDerivation {
    pname = "gpu-unlock-firmware";
    version = "2.0.0-610.43.03";

    inherit src;

    nativeBuildInputs = [ pkgs.python3 pkgs.zstd ];

    dontStrip = true;
    dontPatchELF = true;

    buildPhase = ''
      mkdir -p inputs assets assets.src
      cp ${firmwareSrcKernel} inputs/NVIDIA-kernel-module-source-610.43.03.tar.xz
      cp ${firmwareSrcInstaller} inputs/NVIDIA-Linux-x86_64-610.43.03-no-compat32.run

      tar -xf inputs/NVIDIA-kernel-module-source-610.43.03.tar.xz -C assets.src
      python3 firmware/extract_gsp.py "$(realpath inputs/NVIDIA-Linux-x86_64-610.43.03-no-compat32.run)" assets
      python3 firmware/extract_boot_assets.py assets.src/NVIDIA-kernel-module-source-610.43.03 assets
    '';

    installPhase = ''
      mkdir -p $out/lib/firmware/gpu-unlock/610.43.03
      cp assets/*.bin $out/lib/firmware/gpu-unlock/610.43.03/
    '';
  };

  gpuUnlockModule = pkgs.stdenv.mkDerivation {
    pname = "gpu-unlock-module";
    version = "2.0.0";

    inherit src;

    nativeBuildInputs = kernel.moduleBuildDependencies;

    buildPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$(pwd)/kernel/gpu_unlock \
        modules
    '';

    # Kbuild generates the module certificate required by aggregateModules.
    installPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M="$PWD/kernel/gpu_unlock" \
        ${lib.escapeShellArgs config.boot.kernelPackages.kernelModuleMakeFlags} \
        INSTALL_MOD_PATH="$out" INSTALL_MOD_DIR=extra DEPMOD=true modules_install
    '';
  };
in
{
  # 1. Provide firmware to both host and early initrd
  hardware.firmware = [ gpuUnlockFirmware ];
  boot.initrd.extraFirmwarePaths = [ "gpu-unlock" ];

  # 2. Add out-of-tree kernel module package and expose to initrd
  boot.extraModulePackages = [ gpuUnlockModule ];
  boot.initrd.availableKernelModules = [ "gpu_unlock" ];

  # 3. Kernel parameters: unlock all supported Ampere targets (e.g. GA100, GA102 / RTX 3090, GA106 / RTX 3060, AD102)
  boot.kernelParams = [
    "gpu_unlock.targets=all"
    "gpu_unlock.resume=0"
  ];

  # 4. Early initrd systemd service: execute gpu_unlock BEFORE systemd-udevd binds the nvidia proprietary driver
  boot.initrd.systemd.services.gpu-unlock = {
    description = "Unlock Ampere Tensor Cores before NVIDIA proprietary driver loads";
    wantedBy = [ "initrd.target" ];
    before = [ "systemd-udevd.service" "systemd-modules-load.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kmod}/bin/modprobe gpu_unlock";
      RemainAfterExit = true;
    };
  };
}
