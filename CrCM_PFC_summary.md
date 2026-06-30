# CrCM Boost PFC

## Project objective

A critical-conduction-mode boost PFC converter was developed and verified in Simulink/Simscape for:

```text
Input voltage:       90–264 VAC
Line frequency:      50/60 Hz
Output voltage:      400 VDC
Output power:        100 W
Load resistance:     1600 ohm
Target PF:           > 0.95
Target efficiency:   > 92%
```

The final model includes a bridge rectifier, differential-mode EMI filter, boost power stage, CrCM zero-current detection, Vin feedforward, outer voltage loop, dynamic on-time limiting, cycle-by-cycle OCP, OVP, a maximum-frequency clamp, precharge and bypass sequencing, hysteretic load connection, and a temporary low-line startup on-time limit.

---

## Final power-stage parameters

```text
Boost inductance:            270 uH
Inductor series resistance:  0.1 ohm

Output capacitance:          220 uF
Output-capacitor ESR:        0.3 ohm

Load resistance:             1600 ohm

EMI-filter inductors:        2 x 1 mH
EMI winding resistance:      0.05 ohm each
X capacitor:                 100 nF
X-capacitor ESR:             0.2 ohm

Precharge resistor:          82 ohm
```

The reported efficiency is a modeled efficiency. The simulation does not fully include MOSFET switching energy, gate-drive loss, Coss loss, diode reverse recovery, inductor core loss, detailed thermal effects, or layout-dependent parasitics.

---

## Final controller settings

### Sampling

```text
Fast control sample time:    100 ns
Voltage-loop sample time:    100 us
```

### Protection

```text
OCP threshold:               4.0 A
OVP threshold:               420 V
ZCD threshold:               0.02 A
```

### On-time limits

```text
Minimum on-time:             0.2 us
Normal absolute maximum:     8.0 us
Temporary startup maximum:   7.5 us
```

The startup limit remains active until `Vout_filtered` reaches `390 V`. Relay hysteresis returns to the startup limit if Vout falls below `370 V`.

### Vin feedforward and dynamic maximum

```matlab
Ton_ff = 0.05751 / Vin_rms^2;

Ton_dynamic_max = min( ...
    Ton_abs_max_selected, ...
    1.25 * Ton_ff);
```

### Maximum switching frequency

```text
Requested maximum:           500 kHz
Nominal minimum period:      2.0 us
Counter threshold:           20 fast samples
Measured maximum:            476.19 kHz
```

The next cycle begins only when the inductor has returned to the valid zero-current restart state and the minimum switching period has elapsed.

---

## Final startup sequence

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
Startup pulse initiates the first switching cycle

0.212 s:
Load-control logic is armed
```

Load hysteresis:

```text
Load ON threshold:           370 V
Load OFF threshold:          340 V
```

A `100 us` Unit Delay after the raw load command breaks the electrical/control algebraic loop.

---

# Four-corner steady-state validation

All final measurements use the `4.8–5.0 s` interval.

The `0.2 s` window contains 12 complete line cycles at `60 Hz` and 10 complete line cycles at `50 Hz`.

## Performance results

| Input condition | True PF | Modeled efficiency | Average Vout | Vout ripple | Maximum Fsw |
|---|---:|---:|---:|---:|---:|
| `264 VAC, 60 Hz` | `0.9901` | `98.23%` | `399.7 V` | `4.13 Vpp` | `476.19 kHz` |
| `264 VAC, 50 Hz` | `0.9905` | `98.13%` | `399.6 V` | `4.88 Vpp` | `476.19 kHz` |
| `90 VAC, 60 Hz` | `0.9996` | `96.17%` | `399.8 V` | `3.85 Vpp` | `147.06 kHz` |
| `90 VAC, 50 Hz` | `0.9997` | `96.17%` | `399.7 V` | `4.47 Vpp` | `147.06 kHz` |

## Requirement check

```text
Worst measured PF:           0.9901
Required PF:                  > 0.95
Result:                       PASS

Worst modeled efficiency:    96.17%
Required efficiency:         > 92%
Result:                       PASS

Average output-voltage range:
399.6–399.8 V

Largest output ripple:
4.88 Vpp at 264 VAC, 50 Hz
```

OVP and OCP remained inactive during all final steady-state windows.

---

# Steady-state component stress

The values below combine the worst measured peak and RMS values across the four corners.

| Quantity | Worst steady-state result | Main corner |
|---|---:|---|
| Source-current peak | `1.69 A` | Low line |
| Source-current RMS | `1.15 A` | Low line |
| Boost-inductor peak | `3.37 A` | Low line |
| Boost-inductor RMS | `1.35 A` | Low line |
| MOSFET peak current | `3.32 A` | Low line |
| MOSFET RMS current | `1.15 A` | Low line |
| Bridge-diode peak | `3.37 A` | Low line |
| Bridge-diode RMS | `0.95 A` | Low line |
| Boost-diode peak | `3.36 A` | Low line |
| Boost-diode corrected RMS | `0.70 A` | Low line |
| Output-capacitor peak current | `3.11 A` | Low line |
| Output-capacitor ripple RMS | `0.66 A` | Low line |
| X-capacitor RMS current | `0.70 A` | Low line |

Worst steady-state voltage stresses:

```text
MOSFET Vds:                         403.6 V
Boost-diode reverse voltage:        401.8 V
Representative bridge reverse:      432.6 V
```

Startup produced the larger bridge reverse-voltage stress.

---

# Charge-balance correction

Discrete event logging created a small DC-area bias in switched-current averages.

The correction used:

```text
Expected capacitor average current = C * dV/dt
```

and:

```text
Average boost-diode current
=
average load current
+
average capacitor current
```

Final conservative low-line values are approximately:

```text
Output-capacitor ripple RMS:       0.66 A
Boost-diode corrected RMS:         0.70 A
Boost-diode raw RMS:               0.71 A
```

The raw boost-diode RMS may be retained as the conservative rating value.

---

# Startup validation

Two representative startup cases were used:

```text
264 VAC, 60 Hz:
High-line precharge, bypass, voltage, and passive-inrush stress

90 VAC, 50 Hz:
Low-line active startup, load delay, and OCP behavior
```

The startup analysis interval was `0–0.5 s`.

The bypass-transition window was:

```text
0.195–0.210 s
```

---

## High-line startup: 264 VAC, 60 Hz

### Sequencing

```text
Bypass command:             0.2000 s
Controller enable:          0.2100 s
Load connection:            0.2155 s
```

### Precharge and bypass

```text
Precharge current peak:     3.90 A
Precharge peak power:       1249 W
Precharge energy:           11.74 J
Precharge I^2*t:            0.143 A^2*s

Bypass-transition peak:     4.31 A
Bypass-transition I^2*t:    0.0156 A^2*s
```

### Current and voltage stress

```text
Source/bypass peak:         4.31 A
Boost-inductor peak:        4.31 A
Bridge-path peak:           4.31 A
Boost-diode peak:           4.31 A
Output-capacitor peak:      4.31 A
MOSFET startup peak:        1.64 A

Maximum Vout:               410.4 V
OVP margin:                 9.6 V
Maximum MOSFET Vds:         411.3 V
Boost-diode reverse:        410.1 V
Bridge-diode reverse:       445.6 V
```

Protection result:

```text
OVP:                        no trip
OCP:                        no trip
```

---

## Low-line startup: 90 VAC, 50 Hz

### Sequencing

```text
Bypass command:             0.2000 s
Controller enable:          0.2100 s
Load connection:            0.3314 s
```

### Precharge and bypass

```text
Precharge current peak:     1.29 A
Precharge energy:           1.34 J

Bypass-transition peak:     1.47 A
Bypass-transition I^2*t:    0.00202 A^2*s

Maximum bypass current
during full startup:        2.17 A
```

### Current and voltage stress

```text
MOSFET peak:                4.05 A
Boost-inductor peak:        4.11 A

Maximum Vout:               409.2 V
OVP margin:                 10.8 V
Maximum MOSFET Vds:         410.6 V
Boost-diode reverse:        408.5 V
Bridge-diode reverse:       220.1 V
```

Protection result:

```text
OVP:                        no trip
OCP:                        brief cycle-by-cycle limiting
```

The approximately `0.05 A` OCP threshold overshoot is consistent with the `100 ns` sampled comparator and latch-reset delay.

---

# Final worst-case simulated stresses

## Current

```text
Highest source/bypass startup current:
4.31 A at high-line startup

Highest boost-inductor current:
4.31 A at high-line passive inrush

Highest active MOSFET startup current:
4.05 A at low-line startup

Highest steady-state MOSFET current:
3.32 A at low line

Highest output-capacitor ripple RMS:
0.66 A at low line
```

## Voltage

```text
Highest Vout:
410.4 V during high-line startup

Highest MOSFET Vds:
411.3 V during high-line startup

Highest boost-diode reverse voltage:
410.1 V during high-line startup

Highest bridge-diode reverse voltage:
445.6 V during high-line startup
```

Component ratings should include suitable margin above these simulated values.

---

# Resolved development issues

## Issue 1: PFC Controller — Burst Switching

The gate-control sequence was corrected so that a startup pulse initiates the first cycle and later cycles begin only from a valid ZCD restart-state transition.

## Issue 2: Voltage Loop — Integrator Windup

The voltage-loop integrator was limited and coordinated with the on-time saturation.

## Issue 3: Voltage Loop — Dynamic Maximum Ton

The maximum on-time was made dependent on Vin feedforward and an absolute ceiling.

## Issue 4: Vin Feedforward — Varying Frequency

The feedforward law was corrected for universal-input CrCM operation.

## Issue 5: Startup Inrush and Load Sequencing

An `82 ohm` precharge resistor, zero-cross bypass timing, controller hold-off, load disconnection, and hysteretic load connection reduced the original approximately `46 A` source-current spike to about `4.31 A`.

Testing showed that a `0.200 s` bypass time performed better than `0.150 s` with only `50 ms` additional startup delay.

## Issue 6: Switched-Current Logging Bias

Charge-balance correction was added for output-capacitor and boost-diode current statistics.

## Issue 7: Maximum Switching-Frequency Clamp and PF Tradeoff

A `250 kHz` or `300 kHz` clamp reduced high-line PF to about `0.965–0.966`.

A `500 kHz` requested ceiling restored high-line PF to about `0.99` while limiting measured maximum frequency to `476.19 kHz`.

Clamp-active Ton compensation was considered but not implemented because the added complexity was not justified.

## Issue 8: Low-Line Startup OCP and Temporary On-Time Limiting

Low-line startup briefly reached the `4 A` current threshold.

A temporary `7.5 us` startup on-time ceiling reduced source-side startup stress. The controlled OCP event was accepted because startup completed normally, Vout remained below OVP, and steady-state OCP remained inactive.

---

# Final verification status

```text
Four-corner PF verification:             complete
Four-corner modeled-efficiency test:     complete
Four-corner output regulation:           complete
Low-line steady-state current stress:    complete
High-line steady-state voltage stress:   complete
High-line startup/inrush stress:         complete
Low-line startup/OCP behavior:           complete
Frequency-clamp validation:              complete
Charge-balance correction:               complete
```

## Final project result

```text
PF target > 0.95:
PASS at all four corners

Modeled efficiency target > 92%:
PASS at all four corners

400 V output regulation:
PASS at all four corners

OVP:
No trip in final steady-state or startup validation

OCP:
Inactive in steady state
Brief controlled operation during low-line startup

Maximum measured switching frequency:
476.19 kHz with a 500 kHz requested ceiling
```

The final simulation meets the stated electrical performance targets across the complete input-voltage and line-frequency range.
