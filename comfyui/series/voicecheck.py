import sys, numpy as np, soundfile as sf
def f0s(w, sr, lo_hz):
    hop, win, out = int(sr*0.01), int(sr*0.04), []
    for i in range(0, len(w)-win, hop):
        x = w[i:i+win]-w[i:i+win].mean()
        if np.sqrt(np.mean(x*x)) < 0.02: continue
        ac = np.correlate(x, x, "full")[win-1:]
        lo, hi = int(sr/400), int(sr/lo_hz)
        lag = lo+int(np.argmax(ac[lo:hi]))
        if ac[lag] > 0.3*ac[0]: out.append(sr/lag)
    return np.array(out)
for p in sys.argv[1:]:
    w, sr = sf.read(p, dtype="float32", always_2d=True); w = w.mean(axis=1)
    a, b = f0s(w, sr, 60), f0s(w, sr, 140)
    spec = np.abs(np.fft.rfft(w)); fr = np.fft.rfftfreq(len(w), 1/sr)
    cen = float((spec*fr).sum()/spec.sum())
    print(f"{p.split('/')[-1]:32} F0 60-400: med {np.median(a):5.0f} (share<140 Hz {np.mean(a<140):.2f}) | F0 140-400: med {np.median(b):5.0f} | centroid {cen:5.0f} Hz")
