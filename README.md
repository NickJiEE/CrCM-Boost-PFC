# Critical-Conduction-Mode Boost PFC

A universal-input, single-phase boost power-factor-correction converter developed and verified in Simulink/Simscape.

The converter operates in critical conduction mode, also called transition mode or boundary conduction mode. In this mode, the boost-inductor current returns to approximately zero before the next switching cycle begins. This reduces reverse-recovery stress and provides natural cycle-by-cycle current shaping, but results in a variable switching frequency.

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
| Fast control sample time | `100 ns` |
| Voltage-loop sample time | `100 µs` |

---

## What the project includes

The final model contains:

- Full-wave bridge rectifier
- Differential-mode EMI filter
- Boost power stage
- Critical-conduction-mode zero-current detection
- Input-voltage feedforward
- Outer output-voltage control loop
- Dynamically bounded integral control
- Dynamic and absolute on-time limiting
- Minimum-pulse demand inhibition
- Maximum-switching-frequency clamp
- Cycle-by-cycle overcurrent protection
- Hysteretic output overvoltage protection
- Precharge resistor and bypass sequencing
- Delayed controller startup
- Hysteretic load connection
- Startup-specific on-time limiting
- Reduced-load and no-load control
- Load-step verification
- Charge-balanced switched-current post-processing

---

## Operating principle

The bridge rectifier converts the AC input into a full-wave rectified voltage. The boost converter then regulates the DC bus to approximately `400 V`.

During each switching cycle:

1. The MOSFET turns on and the boost-inductor current rises.
2. The MOSFET turns off and the inductor transfers energy to the output.
3. The inductor current falls back to the zero-current-detection threshold.
4. A new switching cycle begins only after:
   - valid zero-current detection,
   - MOSFET turn-off confirmation,
   - completion of the minimum switching period,
   - inactive OVP,
   - active controller enable, and
   - active on-time demand.

Because the inductor current returns to zero every cycle, the switching frequency varies with line voltage, output voltage, and load.

---

## Final controller settings

### Feedforward and on-time limits

```matlab
Ton_ff = Ton_nom * Vin_nom^2 / Vin_rms^2 = 0.05751 / Vin_rms^2;

Ton_dynamic_max = min( ...
    Ton_abs_max_selected, ...
    1.25 * Ton_ff);
```

```text
Minimum physical Ton command:      0.2 µs
Normal maximum Ton:                8.0 µs
Startup maximum Ton:               7.5 µs
```

### Minimum-pulse demand logic

```text
Demand enable ON threshold:        0.25 µs
Demand enable OFF threshold:       0.15 µs
```

The timer always receives a valid command of at least `0.2 µs`, but new switching cycles are blocked when the controller requests effectively zero power.

### Frequency limit

```text
Requested maximum frequency:       500 kHz
Measured discrete-time maximum:    476.190 kHz
```

### Protection

```text
OCP threshold:                     4.0 A
OVP turn-on threshold:             420 V
OVP release threshold:             410 V
ZCD threshold:                     0.02 A
```

---

## Startup sequence

```text
0.000–0.200 s:
Precharge resistor active
Bypass open
Controller disabled
Load disconnected

0.200 s:
Bypass switch closes

0.210 s:
Controller enabled

0.211 s:
Startup pulse initiates switching

0.212 s:
Load-control logic is armed
```

Load-connection hysteresis:

```text
Load ON:                           370 V
Load OFF:                          340 V
```

---

## Verified operating points

### Full-load steady state

| Input condition | True PF | Modeled efficiency | Average Vout |
|---|---:|---:|---:|
| `90 V, 50 Hz` | `0.999664` | `96.171%` | `400.011 V` |
| `120 V, 60 Hz` | `≈0.999715` | `≈97.307%` | `399.782 V` |
| `230 V, 50 Hz` | `≈0.994517` | `≈98.198%` | `399.660 V` |
| `240 V, 60 Hz` | `≈0.993675` | `≈98.215%` | `399.763 V` |
| `264 V, 60 Hz` | `0.991258` | `98.108%` | `400.008 V` |

The refreshed low-line and high-line corner runs both passed regulation, PF, modeled efficiency, and steady-state protection checks.

### Reduced-load steady state

| Operating point | True PF | Modeled efficiency | Average Vout |
|---|---:|---:|---:|
| `120 V, 50% load` | `0.999708` | `97.405%` | `400.003 V` |
| `120 V, 20% load` | `0.988762` | `96.461%` | `400.000 V` |
| `240 V, 20% load` | `0.916414` | `95.406%` | `399.983 V` |

The `240 V, 20% load` case is the only loaded operating point that did not meet the `PF > 0.95` target. Regulation and modeled efficiency still passed. The limitation is caused by the combination of minimum on-time and the maximum switching-frequency clamp.

### No-load operation

| Input condition | Average Vout | Modeled idle input power |
|---|---:|---:|
| `120 V, 60 Hz` | `401.216 V` | `0.143 W` |
| `240 V, 60 Hz` | `402.023 V` | `0.575 W` |

At no load, the controller correctly inhibits new switching pulses once the output bus is charged. PF and efficiency are not meaningful compliance metrics at essentially zero output power.

---

## Load-step verification

### 120 V, 20% → 100%

- Controlled Vout undershoot
- Approximate minimum Vout: `365–367 V`
- Recovery to near `400 V`: approximately `1 s`
- OVP inactive
- Post-step PF: `0.999733`
- Post-step modeled efficiency: `97.298%`

### 240 V, 100% → 20%

- Controlled Vout overshoot
- Peak remained below the `420 V` OVP threshold
- OVP and OCP inactive
- Stable return to the light-load operating point

### 264 V, 100% → 20%, near line-voltage peak

```text
Measured peak Vout:                413.1815 V
OVP threshold:                     420.0000 V
Remaining OVP margin:              6.8185 V
```

This was the highest measured output voltage in the final verification set.

---

## Worst simulated stresses

### Current

```text
Highest passive input/bypass current:
4.314 A during 264 V startup

Highest boost-inductor current:
4.312 A during high-line passive inrush

Highest active MOSFET current:
4.054 A during 90 V startup

Highest steady-state MOSFET current:
3.324 A at 90 V, 50 Hz, full load

Highest output-capacitor ripple RMS:
0.658 A at 90 V, 50 Hz, full load
```

### Voltage

```text
Highest output voltage:
413.1815 V during 264 V load removal

Highest startup MOSFET Vds:
411.281 V

Highest startup boost-diode reverse voltage:
410.142 V

Highest bridge-diode reverse voltage:
445.614 V
```

Real hardware should use substantial voltage, current, thermal, and transient margin beyond these idealized simulation results.

---

## Final verification status
The final controller has been verified for:

- Universal-input full-load operation
- Reduced-load and no-load operation
- Startup and inrush behavior
- Large load-step transients
- OVP, OCP, minimum-pulse, and frequency-clamp behavior

### Final result

- `400 V` regulation passed across all tested loaded conditions.
- Rated-load PF exceeded `0.95` across the tested input range.
- Modeled efficiency exceeded `92%` for every loaded case.
- The highest measured Vout was `413.1815 V`, below the `420 V` OVP threshold.
- The known limitation is `PF = 0.916414` at `240 V, 20% load`.

---

## Documentation

- [Detailed project summary](CrCM_PFC_summary.md)
- [Final simulation verification report](CrCM_PFC_Final_Simulation_Verification_Report.md)

---

## Notes on modeled efficiency

The reported efficiency does not fully include:

- MOSFET switching energy
- Gate-drive loss
- MOSFET output-capacitance loss
- Diode reverse-recovery loss
- Inductor core loss
- Controller auxiliary power
- Detailed thermal effects
- Layout-dependent parasitic ringing

The results should therefore be treated as control and power-stage simulation results rather than guaranteed hardware efficiency.

---

## Project status

The controller is considered frozen for the current simulation scope. The next stage would be hardware-oriented validation, including device selection, thermal design, EMI compliance, switching-loss estimation, magnetic design, and tolerance analysis.
