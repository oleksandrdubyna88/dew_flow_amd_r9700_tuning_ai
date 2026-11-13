"""Print which comfy-kitchen backend serves each quantized op on this GPU (run inside the container)."""
import comfy_kitchen as ck
from comfy_kitchen import registry
info = ck.list_backends()
for name, b in info.items():
    caps = set(b.get("capabilities", []))
    print(name, "available" if b.get("available") else "unavailable", "disabled" if b.get("disabled") else "")
    for op in ("dequantize_nvfp4", "scaled_mm_nvfp4", "quantize_nvfp4", "int8_linear", "mm_int8", "dequantize_int8_convrot_weight",
               "int8_attention", "scaled_mm_mxfp8", "dequantize_mxfp8", "dequantize_per_tensor_fp8", "scaled_mm_v2",
               "fp16_linear", "convrot_w4a4_linear", "gemv_awq_w4a16", "sage_attention", "flash_attention"):
        if op in caps:
            print("   ", op)
