Hi @Zagitta,

First of all, huge thanks for your incredible work on `gpu-unlock`! The tensor core unlock gives an extraordinary boost in machine learning and diffusion workloads (+80% BF16 throughput tested on an RTX 3090 and RTX 3060).

Following up on the discussion in #78 regarding NixOS compatibility, we have built and verified a complete, declarative NixOS integration that handles firmware packaging, kernel module patching, and early initrd execution out of the box.

### Why a dedicated NixOS module is needed
1. **Deterministic packaging:** NixOS builds must not rely on dynamic DKMS or arbitrary internet downloads during boot. The module extracts the required 5 firmware binaries from NVIDIA `610.43.03` sources via a pure Nix derivation and provides it to `hardware.firmware` and `boot.initrd.extraFirmwarePaths`.
2. **Early initrd execution:** On NixOS, if `systemd-udevd` loads the proprietary NVIDIA driver (`nvidia.ko` / open-gpu-kernel-modules) before `gpu_unlock.ko` binds, the hardware registers lock down. The module creates an early oneshot service:
   ```nix
   boot.initrd.systemd.services.gpu-unlock = {
     wantedBy = [ "initrd.target" ];
     before = [ "systemd-udevd.service" "systemd-modules-load.service" ];
     serviceConfig = {
       Type = "oneshot";
       ExecStart = "${pkgs.kmod}/bin/modprobe gpu_unlock";
       RemainAfterExit = true;
     };
   };
   ```
3. **Kernel 6.x / modern patch integration:** Upstream PRs #35, #70, and #72 are automatically fetched and applied to ensure compatibility with modern 6.x kernels.

### Ready-to-use Repository & Flake
I have packaged this into a repository with full documentation:
🔗 **https://github.com/Sticzu/nixos-gpu-unlock**

Would you be interested in:
- Linking this NixOS module in the main `gpu-unlock` README under an "Installation on NixOS" section, or
- Accepting a Pull Request adding `flake.nix` and `nixos/gpu-unlock.nix` directly to the upstream repository?

I would be happy to submit a PR if you would like native Nix / Flakes support integrated into the main repo!
