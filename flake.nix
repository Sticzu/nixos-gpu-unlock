{
  description = "NixOS module for Zagitta/gpu-unlock 2.0 (unlocking NVIDIA Ampere and Ada Lovelace Tensor Core performance)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = import ./gpu-unlock.nix;
    nixosModules.gpu-unlock = import ./gpu-unlock.nix;
  };
}
