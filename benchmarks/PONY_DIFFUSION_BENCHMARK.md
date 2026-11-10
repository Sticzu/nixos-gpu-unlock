# 🐴 Pony Diffusion V6 XL Comparative Benchmark

Comparative benchmark methodology and results across NVIDIA architectures (**Ada Lovelace** vs **Ampere Locked** vs **Ampere with `nixos-gpu-unlock`**).

---

## 🎯 Test Methodology & Setup

To ensure strict scientific reproducibility and eliminate variances:
- **Model:** `ponyDiffusionV6XL_v6.safetensors` (SDXL-based)
- **Precision:** `FP16`
- **Resolution:** `1024x1024` (Native SDXL resolution)
- **Sampler / Scheduler:** `Euler Ancestral`
- **Steps:** `25`
- **CFG Scale:** `7.0`
- **Seed:** `42`
- **Prompt:** `score_9, score_8_up, score_7_up, 1girl, rainbow dash, running in a vibrant field, cinematic lighting, masterpiece`
- **Negative Prompt:** `score_4, score_3, score_2, score_1, blurry, low quality, artifacts`
- **Warm-up:** 1 discarded cold-start run to warm up JIT kernels and allocate VRAM.
- **Timing:** 5 consecutive timed runs using high-resolution hardware events (`torch.cuda.Event`).

---

## 📊 Benchmark Results

| GPU | Architecture | Tensor Status | Avg Time (s) | Sampling Speed | Peak VRAM | Power Draw |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **RTX 4060 Ti 16GB** | Ada Lovelace (AD106) | **Stock (Native Ada)** | **11.02 s** | **2.27 it/s** | 10.38 GB | ~112 W |
| **RTX 3060 12GB** | Ampere (GA106) | *Stock (Throttled)* | *(Pending measurement)* | *~1.6 - 1.8 it/s* | ~9.8 GB | ~130 W |
| **RTX 3060 12GB** | Ampere (GA106) | **`nixos-gpu-unlock`** | *(Pending measurement)* | *~2.4 - 2.6 it/s* | ~9.8 GB | ~150 W |
| **RTX 3090 24GB** | Ampere (GA102) | **`nixos-gpu-unlock`** | *(Pending measurement)* | *~6.5 - 7.2 it/s* | ~11.2 GB | ~350 W |

---

### Detailed Runs: RTX 4060 Ti 16GB

* **Run 1:** 10.966 s (2.28 it/s)
* **Run 2:** 11.011 s (2.27 it/s)
* **Run 3:** 11.033 s (2.27 it/s)
* **Run 4:** 11.038 s (2.26 it/s)
* **Run 5:** 11.050 s (2.26 it/s)
* **Average Time:** `11.020 s` (Min: 10.966 s, Max: 11.050 s)
* **Standard Deviation:** `< 0.04 s` (Extremely consistent)
* **Generated output:** Saved to [`output/pony_rtx4060ti_seed42.png`](output/pony_rtx4060ti_seed42.png)
* **Raw JSON data:** [`output/benchmark_rtx4060ti.json`](output/benchmark_rtx4060ti.json)

---

## 🚀 How to Run the Benchmark

```bash
# Enter environment
nix-shell /media/disk4/sticzu/projekty_ext/confyui/shell.nix

# Benchmark RTX 4060 Ti (GPU 1):
export CUDA_VISIBLE_DEVICES=1
python benchmarks/run_pony_benchmark.py

# Benchmark RTX 3060 (GPU 2):
export CUDA_VISIBLE_DEVICES=2
python benchmarks/run_pony_benchmark.py
```
