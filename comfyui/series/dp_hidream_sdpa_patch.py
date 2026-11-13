"""diffusion-pipe HiDream on ROCm without flash-attn (2026-11-13 ~04:00): the HiDream submodule imports flash_attn with no
fallback, and flash-attn is not installed in venv_dp (a ROCm build is a long CPU compile, against the no-heavy-CPU rule).
This adds a third branch: torch's scaled_dot_product_attention with flash_attn_func's layout (B, S, H, D) in and out.
Idempotent; keeps attention_processor.py.orig. Run in a container with lora-env at /lora:
  python3 /opt/tests/dp_hidream_sdpa_patch.py
"""
import os
import shutil

P = "/lora/diffusion-pipe/submodules/HiDream/hi_diffusers/models/attention_processor.py"
OLD = """try:
    from flash_attn_interface import flash_attn_func
    USE_FLASH_ATTN3 = True
except:
    from flash_attn import flash_attn_func
    USE_FLASH_ATTN3 = False
"""
NEW = """try:
    from flash_attn_interface import flash_attn_func
    USE_FLASH_ATTN3 = True
except:
    try:
        from flash_attn import flash_attn_func
    except ImportError:  # ROCm without flash-attn: torch SDPA, same (B, S, H, D) layout as flash_attn_func
        import torch.nn.functional as _F

        def flash_attn_func(q, k, v, dropout_p=0., causal=False):
            return _F.scaled_dot_product_attention(q.transpose(1, 2), k.transpose(1, 2), v.transpose(1, 2),
                                                   dropout_p=dropout_p, is_causal=causal).transpose(1, 2)
    USE_FLASH_ATTN3 = False
"""
s = open(P).read()
if NEW in s:
    print("sdpa patch: already applied")
else:
    assert s.count(OLD) == 1, "sdpa patch: the import block changed upstream"
    if not os.path.exists(P + ".orig"):
        shutil.copyfile(P, P + ".orig")
    open(P, "w").write(s.replace(OLD, NEW))
    print("sdpa patch: applied")
