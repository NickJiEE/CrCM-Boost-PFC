# Issue 9: Reduced-Load Overvoltage and Minimum-Pulse Demand Control

## Issue

The converter regulated correctly at the original `100 W` operating point, but the first reduced-load test exposed two related controller limitations:

1. The voltage-loop integral term did not have enough negative authority to reduce the requested on-time.
2. After the integral-authority problem was fixed, the controller could request an on-time below the minimum pulse that the discrete gate-timing system could physically generate.

The first failure appeared during the:

```text
Input:              120 VAC, 60 Hz
Load resistance:    3200 ohm
Target power:       50 W
```

test.

Instead of settling at `400 V`, the output rose toward the OVP threshold and repeatedly cycled between the OVP turn-on and release levels.

---

## Original voltage-loop structure

The original request was:

```matlab
Ton_request = Ton_ff + Ton_P + Ton_I;
```

The feedforward command was:

```matlab
Ton_ff = 0.05751 / Vin_rms^2;
```

The integral correction had a fixed range:

```text
Ton_I minimum:      -1 us
Ton_I maximum:      +1 us
```

At `120 VAC`:

```text
Ton_ff ≈ 3.99 us
```

At `50%` load, the required steady-state on-time was approximately:

```text
Ton_required ≈ 1.9 us
```

The fixed `-1 us` lower limit could not reduce the request sufficiently.

---

## Initial symptoms

Before the correction, the reduced-load run showed approximately:

```text
Ton_ff:             3.99 us
Ton_I:             -1.00 us, saturated
Ton command:        about 2.0 us
Vout:               rising toward 420 V
OVP:                repeated 420 V / 410 V cycling
```

An earlier version of the OVP restart logic could also leave the converter unable to restart after OVP.

After that restart problem was corrected, the converter recovered after OVP release, but OVP was still acting as an unintended burst regulator because the voltage loop could not command a sufficiently small on-time.

---

## Root cause

The feedforward term was calibrated near rated power.

At reduced load:

```text
Required transferred energy per cycle decreases
→ required Ton decreases
→ voltage loop needs a larger negative correction
→ fixed Ton_I lower clamp is reached
→ Ton remains too large
→ input power exceeds load demand
→ Vout rises toward OVP
```

The issue was not caused by:

```text
The load resistance
The ZCD threshold
The maximum-frequency counter
The OVP hysteresis
The bridge or boost power stage
```

The primary cause was insufficient negative voltage-loop authority.

---

# Part 1: Dynamic Ton_I authority

## Selected integral limits

The existing feedforward-plus-PI form was retained:

```matlab
Ton_request = Ton_ff + Ton_P + Ton_I;
```

Define:

```matlab
Ton_base = Ton_ff + Ton_P;
```

The integral limits are then calculated dynamically:

```matlab
Ton_I_min = -Ton_base;

Ton_I_max = Ton_dynamic_max - Ton_base;
```

These bounds guarantee:

```text
0 <= Ton_request <= Ton_dynamic_max
```

because:

```matlab
Ton_base + Ton_I_min = 0;

Ton_base + Ton_I_max = Ton_dynamic_max;
```

The integral term can therefore cancel the entire feedforward and proportional contribution when zero power is requested.

---

## Dynamic integral implementation

The fixed-clamp integrator was replaced with a discrete dynamically saturated accumulator:

```matlab
Ton_I_candidate[k] = ...
    Ton_I_previous[k] + Ton_I_increment[k];

Ton_I_limited[k] = saturate( ...
    Ton_I_candidate[k], ...
    Ton_I_min[k], ...
    Ton_I_max[k]);

Ton_I_previous[k+1] = Ton_I_limited[k];
```

The signal path is:

```text
Ton_I_limited
    -> Unit Delay
    -> Ton_I_previous
    -> candidate Sum
    -> Saturation Dynamic
    -> Ton_I_limited
```

Unit Delay settings:

```text
Initial condition:   0
Sample time:         100 us
```

The stored state is the already-limited value, which provides direct anti-windup.

---

## Removal of the previous conditional integrator

The earlier voltage-loop implementation attempted to block the integrator increment depending on the current saturation state.

That structure formed a same-sample feedback path through:

```text
Integrator increment
→ Ton request
→ dynamic saturation
→ saturation-state logic
→ integrator enable
→ integrator increment
```

Simulink identified this as an algebraic loop.

The conditional integration subsystem was removed. The limited accumulator state itself now supplies the anti-windup behavior without that same-sample feedback path.

---

## Existing upper protections retained

The upper on-time limit remains:

```matlab
Ton_dynamic_max = min( ...
    Ton_abs_max_selected, ...
    1.25 * Ton_ff);
```

with:

```text
Startup absolute maximum:   7.5 us
Normal absolute maximum:    8.0 us
```

The revised integral authority therefore improves reduced-load control without removing the existing startup, current-stress, or feedforward-based limits.

---

## Final numerical request saturation

The final voltage-loop request is:

```matlab
Ton_request = ...
    Ton_ff + ...
    Ton_P + ...
    Ton_I_limited;
```

It is numerically bounded using:

```matlab
Ton_request_limited = saturate( ...
    Ton_request, ...
    0, ...
    Ton_dynamic_max);
```

The lower limit was changed from `0.2 us` to zero.

This is important because the voltage loop must be able to represent:

```text
Zero requested power
```

The practical minimum gate-pulse width is handled separately.

---

# Part 2: Minimum-pulse demand control

## Why a second control layer was required

After the dynamic integral fix, the controller could correctly request:

```text
Ton_request_limited -> 0
```

However, the fast digital timing system uses a `100 ns` sample time.

An arbitrarily small on-time request would either:

```text
Produce an invalid pulse
Round to an inconsistent discrete pulse width
Or force switching when the required power is effectively zero
```

Therefore, two different quantities were separated:

```text
Ton_request_limited:
The energy command requested by the voltage loop

Ton_cmd:
A valid physical timer value whenever a pulse is allowed
```

A separate enable signal determines whether a new switching cycle is permitted.

---

## Demand-enable hysteresis

A Relay block generates the slow demand-enable signal:

```text
Input:               Ton_request_limited
Turn ON threshold:   0.25 us
Turn OFF threshold:  0.15 us
Output when ON:      1
Output when OFF:     0
Initial output:      0
```

Conceptually:

```matlab
TonDemandEnable_slow = hysteresis( ...
    Ton_request_limited, ...
    0.25e-6, ...
    0.15e-6);
```

The hysteresis prevents rapid enable/disable chatter near the minimum-pulse boundary.

---

## Valid timer command

A Max block generates:

```matlab
Ton_cmd_slow = max( ...
    Ton_request_limited, ...
    0.2e-6);
```

Therefore:

```text
The timer always receives at least 0.2 us.
The voltage loop can still request zero.
No physical pulse is generated while demand-enable is false.
```

---

## Rate transitions

The voltage loop runs at:

```text
100 us
```

while the gate and ZCD logic run at:

```text
100 ns
```

Two separate Rate Transition blocks are used:

```text
Ton_cmd_slow
    -> Ton_cmd_fast

TonDemandEnable_slow
    -> TonDemandEnable_fast
```

Recommended initial conditions:

```text
Ton_cmd_fast initial value:             0.2 us
TonDemandEnable_fast initial value:     false
```

---

## Integration into the restart logic

Demand-enable is applied before the restart edge detector:

```matlab
restart_ready_protected = ...
    zero_ready && ...
    period_done && ...
    ~OVP_active && ...
    TonDemandEnable_fast;
```

The rising edge of this protected restart state produces the limited ZCD restart pulse.

The SR-latch SET condition is:

```matlab
SET = ...
    (startup_pulse || zcd_pulse_limited) && ...
    ControllerEnable && ...
    ~OVP_active && ...
    TonDemandEnable_fast;
```

The RESET condition remains:

```matlab
RESET = ...
    Ton_done || ...
    OCP || ...
    OVP_active || ...
    ~ControllerEnable;
```

`TonDemandEnable_fast` is intentionally **not** included in RESET.

The demand signal blocks the next switching cycle. It does not asynchronously truncate a pulse already in progress.

---

## Final behavior

The final minimum-pulse behavior is:

```text
Ton request below 0.15 us:
TonDemandEnable = 0
No new switching cycle starts

Ton request between 0.15 us and 0.25 us:
Relay retains its previous state

Ton request above 0.25 us:
TonDemandEnable = 1
Switching can restart from the normal ZCD/frequency-qualified edge

Whenever switching is enabled:
Ton_cmd >= 0.2 us
```

---

# Verification

## 120 V, 60 Hz, 50% load

The dynamic integral correction eliminated OVP cycling and produced:

```text
Load resistance:           3200 ohm
Output power:              50.0007 W
Output current:            0.1250 A
Average Vout:              400.003 V
Vout ripple:               1.900 Vpp
Vout drift:               -0.001 V

True PF:                   0.999708
Modeled efficiency:        97.405%

Ton command:               1.886–1.901 us
Average Ton:               1.893 us
Average switching freq:    349.125 kHz
Maximum switching freq:    476.190 kHz

OVP:                       inactive
OCP:                       inactive
```

This confirmed that the dynamic `Ton_I` authority solved the original reduced-load overvoltage problem.

---

## 120 V, 60 Hz, 20% load

The final minimum-pulse structure also regulated the lower-power case:

```text
Load resistance:           8000 ohm
Output power:              19.99997 W
Average Vout:              399.9999 V
Vout ripple:               1.014 Vpp
Vout drift:                0.0033 V

True PF:                   0.988762
Modeled efficiency:        96.461%

Average Ton request:       0.897 us
Switching frequency:       476.190 kHz
OVP:                       inactive
OCP:                       inactive
```

The request remained above the minimum-pulse hysteresis band, so continuous switching was still possible.

---

## 240 V, 60 Hz, 20% load

At high line and light load:

```text
Average Vout:              399.983 V
Output power:              19.998 W
Vout ripple:               1.417 Vpp

Average Ton command:       0.200 us
Average switching freq:    474.218 kHz
Maximum switching freq:    476.190 kHz

Modeled efficiency:        95.406%
OVP:                       inactive
OCP:                       inactive
```

The controller was simultaneously near:

```text
The minimum practical on-time
The maximum switching-frequency clamp
```

Regulation and efficiency passed, but true PF decreased to:

```text
0.916414
```

This is a documented high-line, light-load limitation. It is not a failure of the revised integral or minimum-pulse logic.

---

## No-load verification

The no-load tests used an effective:

```text
1 Gohm
```

load.

### 120 V, 60 Hz

```text
Average Vout:              401.216 V
Vout ripple:               0.015 Vpp
Vout drift:               -0.0076 V
Gate pulses from 4–5 s:    none
OVP/OCP:                   inactive
```

### 240 V, 60 Hz

```text
Average Vout:              402.023 V
Vout ripple:               0.010 Vpp
Vout drift:               -0.0052 V
Gate pulses from 4–5 s:    none
OVP/OCP:                   inactive
```

The controller correctly reached:

```text
Ton request below the demand threshold
→ TonDemandEnable = 0
→ no new gate pulses
→ Vout remains bounded near 400 V
```

This verified that zero power demand is represented by disabling new switching cycles rather than by generating invalid subminimum pulses.

---

## Load-step confirmation

During the `120 V, 20% → 100%` load step, the on-time command transitioned from approximately:

```text
0.9 us at 20% load
```

to:

```text
3.7 us at full load
```

The converter recovered to the expected full-load operating point without OVP activation.

During high-line load removal, the revised controller reduced the requested on-time and entered the expected light-load switching pattern without becoming stuck on or stuck off.

---

# Why the final solution was retained

The combined solution:

```text
Provides enough negative integral authority
Preserves the existing feedforward equation
Preserves all upper Ton protections
Avoids integrator windup
Removes the algebraic loop
Allows zero requested power
Prevents invalid subminimum physical pulses
Supports controlled pulse skipping
Allows restart after inhibited intervals
Avoids using OVP as the normal reduced-load regulator
```

No additional mode controller was required.

---

# Issue-specific result

The original fixed `±1 us` voltage-loop integral clamp was insufficient for reduced-load operation.

It was replaced by:

```matlab
Ton_I_min = -(Ton_ff + Ton_P);

Ton_I_max = ...
    Ton_dynamic_max - Ton_ff - Ton_P;
```

The final request lower bound was changed to zero, and practical minimum-pulse handling was separated into:

```matlab
TonDemandEnable = hysteresis( ...
    Ton_request_limited, ...
    0.25e-6, ...
    0.15e-6);

Ton_cmd = max( ...
    Ton_request_limited, ...
    0.2e-6);
```

The completed fix successfully regulated:

```text
120 V at 50% load
120 V at 20% load
240 V at 20% load
120 V no load
240 V no load
```

without OVP cycling, uncontrolled overvoltage, or a permanent stuck-off state.

The only remaining limitation is reduced PF at high-line light load, where the minimum pulse width and maximum switching-frequency clamp are both active.
