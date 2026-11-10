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

| GPU | Architecture | Tensor / Unlock Status | Avg Time (s) | Sampling Speed | Peak VRAM | Power Draw | Speedup |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **RTX 4060 Ti 16GB** | Ada Lovelace (AD106) | **Stock / Baseline** | **11.02 s** | **2.27 it/s** | 10.38 GB | ~112 W | Baseline |
| **RTX 4060 Ti 16GB** | Ada Lovelace (AD106) | **`nixos-gpu-unlock 2.0` (Experimental tier)** | **8.06 s** | **3.10 it/s** | 10.38 GB | ~125 W | **+36.6% it/s (1.37x)** |
| **RTX 3060 12GB** | Ampere (GA106) | *Stock (Throttled)* | *(Pending measurement)* | *~1.6 - 1.8 it/s* | ~9.8 GB | ~130 W | - |
| **RTX 3060 12GB** | Ampere (GA106) | **`nixos-gpu-unlock 2.0`** | *(Pending measurement)* | *~2.4 - 2.6 it/s* | ~9.8 GB | ~150 W | - |
| **RTX 3090 24GB** | Ampere (GA102) | **`nixos-gpu-unlock 2.0`** | *(Pending measurement)* | *~6.5 - 7.2 it/s* | ~11.2 GB | ~350 W | - |

---

### Detailed Comparison: RTX 4060 Ti 16GB (Stock vs `gpu-unlock 2.0`)

| Metric | Stock Baseline | With `gpu-unlock 2.0` | Difference |
|:---|:---:|:---:|:---:|
| **Average Time (s)** | `11.020 s` | `8.057 s` | **-2.96 s (-26.9%)** |
| **Sampling Throughput** | `2.27 it/s` | `3.10 it/s` | **+0.83 it/s (+36.6%)** |
| **Min Time** | `10.966 s` | `8.028 s` | **-2.94 s** |
| **Max Time** | `11.050 s` | `8.086 s` | **-2.96 s** |
| **Power Draw** | `112.4 W` | `124.7 W` | +12.3 W (higher sustained compute) |
| **Peak VRAM** | `10.38 GB` | `10.38 GB` | Identical footprint |

#### Individual Runs (With `gpu-unlock 2.0`):
* **Run 1:** 8.028 s (3.11 it/s)
* **Run 2:** 8.040 s (3.11 it/s)
* **Run 3:** 8.060 s (3.10 it/s)
* **Run 4:** 8.072 s (3.10 it/s)
* **Run 5:** 8.086 s (3.09 it/s)

* **Generated output:** [`output/pony_rtx4060ti_seed42.png`](output/pony_rtx4060ti_seed42.png)
* **Stock JSON data:** [`output/benchmark_rtx4060ti_stock.json`](output/benchmark_rtx4060ti_stock.json)
* **Unlocked JSON data:** [`output/benchmark_rtx4060ti_unlocked.json`](output/benchmark_rtx4060ti_unlocked.json)

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
