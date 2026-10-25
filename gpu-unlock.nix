{ config, lib, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  src = pkgs.fetchFromGitHub {
    owner = "Zagitta";
    repo = "gpu-unlock";
    rev = "af28cbbfd3d922a659227ecfb7369adfd924cf03";
    hash = "sha256-6FaDuPojB707ds7gkQY/g/+m4Tnz1xHZ95UjNfFxBJc=";
  };

  firmwareSrcKernel = pkgs.fetchurl {
    url = "https://download.nvidia.com/XFree86/NVIDIA-kernel-module-source/NVIDIA-kernel-module-source-610.43.03.tar.xz";
    sha256 = "7e118923c7a23edc36114d63273a46e3e04e9af98695a42203e7ac2dfe9fc1dc";
  };

  firmwareSrcUtils = pkgs.fetchurl {
    url = "https://archive.cachyos.org/archive/cachyos-v3/nvidia-utils-610.43.03-1-x86_64_v3.pkg.tar.zst";
    sha256 = "e17e7c92eeffa178b0fe1f40eb17a47095f8fc3ce4a77bf115cf5bd5a4df86e9";
  };

  gpuUnlockFirmware = pkgs.stdenv.mkDerivation {
    pname = "gpu-unlock-firmware";
    version = "1.0.0-610.43.03";

    inherit src;

    nativeBuildInputs = [ pkgs.python3 pkgs.zstd ];

    dontStrip = true;
    dontPatchELF = true;

    buildPhase = ''
      mkdir -p inputs assets assets.src
      cp ${firmwareSrcKernel} inputs/NVIDIA-kernel-module-source-610.43.03.tar.xz
      cp ${firmwareSrcUtils} inputs/nvidia-utils-610.43.03-1-x86_64_v3.pkg.tar.zst

      tar -xf inputs/NVIDIA-kernel-module-source-610.43.03.tar.xz -C assets.src
      python3 firmware/generate_v67.py "$(realpath inputs/nvidia-utils-610.43.03-1-x86_64_v3.pkg.tar.zst)" assets
      python3 firmware/extract_boot_assets.py assets.src/NVIDIA-kernel-module-source-610.43.03 assets
    '';

    installPhase = ''
      mkdir -p $out/lib/firmware/gpu-unlock/610.43.03
      cp assets/*.bin $out/lib/firmware/gpu-unlock/610.43.03/
    '';
  };

  gpuUnlockModule = pkgs.stdenv.mkDerivation {
    pname = "gpu-unlock-module";
    version = "1.0.0";

    inherit src;

    # Critical upstream stability patches (PR #35, #70, #72) for Linux 6.x kernels
    patches = [
      (pkgs.fetchurl {
        name = "pr-35.patch";
        url = "https://github.com/Zagitta/gpu-unlock/pull/35.patch";
        sha256 = "0ilsp95lhyb12v4h7ljyisfd0sr1f76m9mpri2fv4d8415czv472";
      })
      (pkgs.fetchurl {
        name = "pr-70.patch";
        url = "https://github.com/Zagitta/gpu-unlock/pull/70.patch";
        sha256 = "06ay77b8p7vz461dg4x3p0yi6ysdff0h56kncj4g3p8b3vylwvqq";
      })
      (pkgs.fetchurl {
        name = "pr-72.patch";
        url = "https://github.com/Zagitta/gpu-unlock/pull/72.patch";
        sha256 = "1kqz00vz37cp35vrqrlkbjgxbn62j6anhx9wmpxfd5plfd1rrcqc";
      })
    ];

    nativeBuildInputs = kernel.moduleBuildDependencies;

    buildPhase = ''
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$(pwd)/kernel/gpu_unlock \
        modules
    '';

    installPhase = ''
      install -D -m 644 kernel/gpu_unlock/gpu_unlock.ko \
        $out/lib/modules/${kernel.modDirVersion}/extra/gpu_unlock.ko
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

  # 3. Kernel parameters: unlock all supported Ampere targets (e.g. GA102 / RTX 3090, GA106 / RTX 3060)
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
