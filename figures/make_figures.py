"""Portfolio figures for the README, drawn from analysis/results/*.csv.

The MATLAB/Octave pipeline (analysis/run_all.m) produces the numbers and its
own quick-look plots in figures/matlab/. This script only restyles the same
CSV data for the README. Run:  python figures/make_figures.py
"""
from pathlib import Path
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "analysis" / "results"
OUT = ROOT / "figures"

# Validated categorical palette (fixed order) and neutral inks
S1, S2, S3, S4, S5 = "#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"
INK, INK2, MUTED, GRID, AXIS, SURF = "#0b0b0b", "#52514e", "#898781", "#e1e0d9", "#c3c2b7", "#fcfcfb"
BAND = "#cde2fb"
T_MIN, T_MAX = 293.15, 303.15

plt.rcParams.update({
    "figure.facecolor": SURF, "axes.facecolor": SURF, "savefig.facecolor": SURF,
    "font.family": "DejaVu Sans", "font.size": 10, "text.color": INK,
    "axes.edgecolor": AXIS, "axes.labelcolor": INK2, "axes.titlecolor": INK,
    "axes.titlesize": 12, "axes.titleweight": "bold", "axes.titlelocation": "left",
    "xtick.color": MUTED, "ytick.color": MUTED, "axes.grid": True,
    "grid.color": GRID, "grid.linewidth": 0.6, "axes.spines.top": False,
    "axes.spines.right": False, "lines.linewidth": 2, "legend.frameon": False,
})


def read(name):
    with open(RES / name) as f:
        return list(csv.DictReader(f))


def col(rows, key):
    return [float(r[key]) for r in rows]


def label_end(ax, x, y, text, color):
    ax.annotate(text, (x, y), xytext=(6, 0), textcoords="offset points",
                va="center", fontsize=9, color=INK2)
    ax.plot([x], [y], "o", ms=5, color=color, mec=SURF, mew=1.5)


# ---- Figure 1: cold science sol (concept B) --------------------------------
d = read("ts_cold_sci_B.csv")
t = col(d, "t_h")
fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 6.6), sharex=True,
                             gridspec_kw={"height_ratios": [2.2, 1]})
a1.axhspan(T_MIN, T_MAX, color=BAND, lw=0, label="Payload operating band 293–303 K")
a1.plot(t, col(d, "T_int_K"), color=S1, label="Payload (WEB interior)")
a1.plot(t, col(d, "T_skin_K"), color=S2, label="WEB outer skin")
a1.plot(t, col(d, "T_air_K"), color=S3, label="Air (design cold case)")
a1.set_ylabel("Temperature [K]")
a1.set_title("Cold case, science sol: warm up, scan, PCM plateau, coast down", pad=40)
a1.legend(loc="lower left", bbox_to_anchor=(0, 1.03), fontsize=9, ncol=4, borderaxespad=0, handlelength=1.6)
for x, txt in [(7.0, "warm-up\nstarts"), (13.0, "38 W scan\n(2 h)")]:
    a1.axvline(x, color=MUTED, lw=0.8, ls=":")
    a1.text(x + 0.15, 252, txt, fontsize=8.5, color=INK2, va="center")
a1.text(15.6, 304.2, "PCM melting holds 301.1 K", fontsize=8.5, color=INK2)
a2.step(t, col(d, "Q_htr_W"), where="post", color=S4, lw=1.4, label="Heater (30 W)")
a2.step(t, col(d, "Q_int_W"), where="post", color=S5, lw=2, label="Internal dissipation")
a2.set_ylabel("Power [W]")
a2.set_xlabel("Time since local midnight [h] (1 sol = 24.66 h)")
a2.legend(loc="upper left", fontsize=9, ncol=2)
a2.set_ylim(0, 45)
a2.set_xlim(0, 24.66)
fig.tight_layout()
fig.savefig(OUT / "fig1_cold_science_sol.png", dpi=160)
plt.close(fig)

# ---- Figure 2: insulation trade --------------------------------------------
d = read("trade_T1_insulation.csv")
fig, ax = plt.subplots(figsize=(8, 4.6))
for mat, c in [("Silica aerogel", S1), ("MLI in Mars CO2", S2)]:
    rows = [r for r in d if r["material"] == mat]
    x, y = col(rows, "thickness_mm"), col(rows, "equivalent_kg")
    ax.plot(x, y, color=c, marker="o", ms=5, mec=SURF, mew=1.5)
    label_end(ax, x[-1], y[-1], mat, c)
sel = [r for r in d if r["material"] == "Silica aerogel" and float(r["thickness_mm"]) == 75][0]
ax.annotate("Selected: 75 mm aerogel\n(2.53 kg; optimum 2.49 kg at 50 mm)",
            (75, float(sel["equivalent_kg"])), xytext=(84, 1.0), fontsize=9, color=INK2,
            arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8))
ax.set_xlabel("Insulation thickness [mm]")
ax.set_ylabel("Insulation + equivalent array mass [kg]")
ax.set_title("Trade T1: aerogel beats MLI at every thickness on Mars")
ax.set_xlim(0, 150)
ax.set_ylim(0, 9.5)
fig.tight_layout()
fig.savefig(OUT / "fig2_trade_insulation.png", dpi=160)
plt.close(fig)

# ---- Figure 3: PCM trade ---------------------------------------------------
d = read("trade_T3_pcm.csv")
fig, ax = plt.subplots(figsize=(8, 4.6))
ax.axhline(T_MAX, color=INK2, lw=1, ls="--")
ax.text(1.55, T_MAX + 0.8, "Upper operating limit 303.15 K", fontsize=8.5, color=INK2)
for m, c in zip([0.0, 0.5, 1.0, 1.5, 2.0], [S1, S2, S3, S4, S5]):
    rows = [r for r in d if float(r["pcm_kg"]) == m]
    x, y = col(rows, "scan_h"), col(rows, "Tmax_K")
    ax.plot(x, y, color=c, marker="o", ms=5, mec=SURF, mew=1.5)
    label_end(ax, x[-1], y[-1], f"{m:.1f} kg PCM", c)
ax.set_xlabel("MSolo scan duration per science sol [h]")
ax.set_ylabel("Peak payload temperature [K]")
ax.set_title("Trade T3: 1.0 kg of n-octadecane covers a 2 h scan (hot case)")
ax.set_xlim(0.3, 4.8)
fig.tight_layout()
fig.savefig(OUT / "fig3_trade_pcm.png", dpi=160)
plt.close(fig)

# ---- Figure 4: mission heater energy, concept A vs B -----------------------
d = read("mission_energy.csv")
fig, ax = plt.subplots(figsize=(7, 4.0))
envs = ["hot", "cold"]
w = 0.36
for i, (con, c, lab) in enumerate([("A", S2, "A: hold 293–303 K all mission"),
                                    ("B", S1, "B: warm only for science (proposed)")]):
    vals = [float(next(r for r in d if r["environment"] == e and r["concept"] == con)["mission_kWh"])
            for e in envs]
    xs = [k + (i - 0.5) * (w + 0.02) for k in range(len(envs))]
    ax.bar(xs, vals, width=w, color=c, label=lab, zorder=3)
    for x, v in zip(xs, vals):
        ax.text(x, v + 0.4, f"{v:.1f}", ha="center", fontsize=9, color=INK)
ax.set_xticks(range(len(envs)))
ax.set_xticklabels(["Hot-case bound", "Cold-case bound"])
ax.set_ylabel("Heater energy over 90 sols [kWh]")
ax.set_title("Operating concept B cuts heater energy 36–75 %")
ax.grid(axis="x", visible=False)
ax.legend(loc="upper left", fontsize=9)
ax.set_ylim(0, 29)
fig.tight_layout()
fig.savefig(OUT / "fig4_mission_energy.png", dpi=160)
plt.close(fig)
print("figures written to", OUT)
