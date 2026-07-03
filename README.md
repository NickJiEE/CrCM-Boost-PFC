# Critical-Conduction-Mode Boost PFC

A universal-input, single-phase boost power-factor-correction converter developed and verified in Simulink/Simscape.

The converter operates in critical conduction mode, also called transition mode or boundary conduction mode. In this mode, the boost-inductor current returns to approximately zero before the next switching cycle begins. This provides natural input-current shaping and reduces reverse-recovery stress, but results in a variable switching frequency.

<p align="center">
  <img src="figures/pfc.png"
       alt="Final CrCM boost PFC Simulink model"
       width="100%">
</p>

---

## Main specifications

| Parameter | Value |
|---|---:|
| AC input voltage | `90–264 VAC` |
| Line frequency | `50/60 Hz` |
| DC output voltage | `400 V` |
| Rated output power | `100 W` |
| Rated load | `1600 Ω` |
| Power-factor target | `PF > 0.95` |
| Modeled-efficiency target | `> 92%` |
| Boost inductance | `270 µH` |
| Output capacitance | `220 µF` |

---

## Key features

- Universal-input CrCM boost PFC power stage
- Zero-current-detection-based variable-frequency switching
- Input-voltage feedforward and output-voltage regulation
- Dynamically bounded integral control with anti-windup
- Minimum-pulse demand inhibition
- Maximum-switching-frequency limiting
- Cycle-by-cycle overcurrent protection
- Hysteretic output overvoltage protection
- Precharge, bypass, controller-startup, and load-connect sequencing
- Verified startup, full-load, reduced-load, no-load, and load-step operation

---

## Operating principle

The bridge rectifier converts the AC input into a full-wave rectified voltage. The boost stage then regulates the output bus to approximately `400 V`.

During each switching cycle:

1. The MOSFET turns on and the boost-inductor current rises.
2. The MOSFET turns off and the inductor transfers energy to the output.
3. The inductor current falls to the zero-current-detection threshold.
4. A new cycle begins after the restart and minimum-period conditions are satisfied.

Because the inductor current returns to zero every cycle, the switching frequency varies with input voltage, output voltage, and load.

---

## Results at a glance

| Result | Final value |
|---|---:|
| Lowest refreshed rated-load PF | `0.991258` |
| Lowest loaded modeled efficiency | `95.406%` |
| Maximum measured switching frequency | `476.190 kHz` |
| Highest measured Vout | `413.1815 V` |
| OVP threshold | `420 V` |
| Highest active MOSFET current | `4.054 A` |

The converter maintained approximately `400 V` across all tested loaded operating points. Rated-load PF exceeded `0.95` throughout the tested input range, and modeled efficiency exceeded `92%` for every loaded case.

The known limitation is high-line light-load PF:

```text
240 V, 60 Hz, 20% load:
PF = 0.916414
```

Regulation and modeled efficiency still passed at this operating point.

Reported efficiencies are simulation-based and do not represent guaranteed hardware efficiency.

---

## Documentation

- [Detailed project summary](CrCM_PFC_summary.md)
- [Final simulation verification report](CrCM_PFC_Final_Simulation_Verification_Report.md)

---

## Project status

The controller is considered complete for the current simulation scope.

Future work includes hardware device selection, magnetic design, thermal analysis, switching-loss estimation, EMI validation, and component-tolerance analysis.
