{
  description = "NixOS module for Zagitta/gpu-unlock (unlocking NVIDIA Ampere Tensor Core BF16/FP16 performance)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = import ./gpu-unlock.nix;
    nixosModules.gpu-unlock = import ./gpu-unlock.nix;
  };
}
