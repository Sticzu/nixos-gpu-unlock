import os
import sys
import json
import time
import subprocess
import torch
from diffusers import StableDiffusionXLPipeline, EulerAncestralDiscreteScheduler

# Ensure clean cache
torch.cuda.empty_cache()
torch.cuda.reset_peak_memory_stats()

gpu_name = torch.cuda.get_device_name(0)
total_vram_gb = torch.cuda.get_device_properties(0).total_memory / (1024**3)

print("=" * 65)
print(f"BENCHMARK: Pony Diffusion V6 XL on {gpu_name}")
print(f"Total VRAM: {total_vram_gb:.2f} GB")
print("=" * 65)

MODEL_PATH = "/media/disk4/sticzu/projekty_ext/confyui-gpu1/ComfyUI/models/checkpoints/ponyDiffusionV6XL_v6.safetensors"
OUT_DIR = "/home/sticzu/nixos-gpu-unlock/benchmarks/output"
os.makedirs(OUT_DIR, exist_ok=True)

print("\n[1/4] Loading model into VRAM (fp16)...")
t0 = time.time()
pipe = StableDiffusionXLPipeline.from_single_file(
    MODEL_PATH,
    torch_dtype=torch.float16,
    use_safetensors=True
).to("cuda:0")

pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config)
print(f"Model loaded in {time.time() - t0:.2f}s")

prompt = "score_9, score_8_up, score_7_up, 1girl, rainbow dash, running in a vibrant field, cinematic lighting, masterpiece"
negative_prompt = "score_4, score_3, score_2, score_1, blurry, low quality, artifacts"

STEPS = 25
WIDTH = 1024
HEIGHT = 1024
BENCHMARK_RUNS = 5

print("\n[2/4] WARM-UP RUN (compiling kernels & JIT caches)...")
_ = pipe(
    prompt=prompt,
    negative_prompt=negative_prompt,
    num_inference_steps=STEPS,
    height=HEIGHT,
    width=WIDTH,
    generator=torch.Generator(device="cuda:0").manual_seed(999)
)
torch.cuda.synchronize()
print("Warm-up complete!")

print(f"\n[3/4] RUNNING BENCHMARK ({BENCHMARK_RUNS} iterations, seed=42)...")
run_times = []
saved_image = None

for i in range(1, BENCHMARK_RUNS + 1):
    torch.cuda.synchronize()
    start_event = torch.cuda.Event(enable_timing=True)
    end_event = torch.cuda.Event(enable_timing=True)
    
    start_event.record()
    out = pipe(
        prompt=prompt,
        negative_prompt=negative_prompt,
        num_inference_steps=STEPS,
        height=HEIGHT,
        width=WIDTH,
        guidance_scale=7.0,
        generator=torch.Generator(device="cuda:0").manual_seed(42)
    )
    end_event.record()
    torch.cuda.synchronize()
    
    elapsed = start_event.elapsed_time(end_event) / 1000.0  # seconds
    it_per_sec = STEPS / elapsed
    run_times.append(elapsed)
    
    print(f"  -> Run {i}/{BENCHMARK_RUNS}: {elapsed:.3f} s ({it_per_sec:.2f} it/s)")
    if i == 1:
        saved_image = out.images[0]

# Save output image
img_path = os.path.join(OUT_DIR, "pony_rtx4060ti_seed42.png")
saved_image.save(img_path)
print(f"\nImage saved to: {img_path}")

# Memory stats
peak_vram_gb = torch.cuda.max_memory_allocated(0) / (1024**3)

# Calculate statistics
avg_time = sum(run_times) / len(run_times)
avg_it_s = STEPS / avg_time
min_time = min(run_times)
max_time = max(run_times)

# Read nvidia-smi power/temp
try:
    smi_out = subprocess.check_output(
        ["nvidia-smi", "--query-gpu=temperature.gpu,power.draw", "--format=csv,noheader,nounits"],
        text=True
    ).strip().split("\n")[1]  # GPU 1
    temp, power = [x.strip() for x in smi_out.split(",")]
except Exception:
    temp, power = "N/A", "N/A"

results = {
    "gpu_name": gpu_name,
    "architecture": "Ada Lovelace (AD106)",
    "gpu_unlock": "unlocked (v2.0)",
    "total_vram_gb": round(total_vram_gb, 2),
    "peak_vram_gb": round(peak_vram_gb, 2),
    "model": "Pony Diffusion V6 XL",
    "resolution": f"{WIDTH}x{HEIGHT}",
    "steps": STEPS,
    "sampler": "Euler Ancestral",
    "cfg": 7.0,
    "seed": 42,
    "run_times_seconds": [round(t, 3) for t in run_times],
    "average_time_seconds": round(avg_time, 3),
    "average_it_s": round(avg_it_s, 2),
    "min_time_seconds": round(min_time, 3),
    "max_time_seconds": round(max_time, 3),
    "temperature_c": temp,
    "power_draw_w": power,
    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
}

json_path = os.path.join(OUT_DIR, "benchmark_rtx4060ti_unlocked.json")
with open(json_path, "w") as f:
    json.dump(results, f, indent=2)

# Also update latest
with open(os.path.join(OUT_DIR, "benchmark_rtx4060ti.json"), "w") as f:
    json.dump(results, f, indent=2)

print("\n" + "=" * 65)
print("FINAL BENCHMARK RESULTS:")
print(f"  GPU: {gpu_name}")
print(f"  Avg Generation Time: {avg_time:.3f} s (Min: {min_time:.3f} s, Max: {max_time:.3f} s)")
print(f"  Sampling Speed: {avg_it_s:.2f} it/s")
print(f"  Peak VRAM: {peak_vram_gb:.2f} GB / {total_vram_gb:.2f} GB")
print(f"  JSON output: {json_path}")
print("=" * 65)
