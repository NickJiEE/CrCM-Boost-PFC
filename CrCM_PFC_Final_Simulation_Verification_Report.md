# CrCM Boost PFC — Final Simulation Verification Report

## 1. Design target

| Parameter | Target / final setting |
|---|---:|
| AC input | 90–264 VAC, 50/60 Hz |
| DC output | 400 VDC |
| Rated power | 100 W |
| Power factor requirement | PF > 0.95 |
| Efficiency requirement | > 92% |
| Boost inductance | 270 µH |
| Output capacitor | 220 µF |
| OCP threshold | 4 A |
| OVP hysteresis | 420 V ON / 410 V OFF |
| Maximum switching frequency | 500 kHz requested; 476.190 kHz realized by discrete timing |
| Minimum commanded on-time | 0.2 µs |
| Startup on-time limit | 7.5 µs |
| Normal absolute on-time limit | 8.0 µs |

## 2. Data sources and cross-check

- The uploaded archive contains **14 primary stress CSV files** and **12 charge-balanced companion CSV files**.
- Every requested startup and steady-state case is present. The uploaded `230 V, 50 Hz, full-load` case is also included because 230 V / 50 Hz is a common nominal mains condition outside North America.
- Stress values in the CSVs were checked against the latest command-window outputs retained in this conversation. The compared values match to the displayed rounding.
- The PF/efficiency script did not export CSV files. Those results are taken from the console outputs previously pasted in this conversation.
- The standalone 120 V, 230 V, and 240 V full-load PF/efficiency values were available only in rounded retained summaries; they are marked with `≈`. The 230 V output-power estimate is calculated from the uploaded Vout RMS value and the 1600 Ω load. Final-controller full-load behavior is independently confirmed by the refreshed 90 V and 264 V corner runs and by the 120 V post-step 100% window.
- Post-step CSV files contain the final steady-state window only. Transient extrema were taken from the plotted waveforms or separately measured cursor values.

## 3. Startup verification

| Case | Iac peak (A) | Precharge peak (A) | iL peak (A) | MOSFET branch peak (A) | Vout max (V) | Vds max (V) | Boost diode reverse (V) | Bridge diode reverse (V) | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 90V 50Hz full | 2.1657 | 1.2873 | 4.1109 | 4.0540 | 409.2088 | 410.6333 | 408.4546 | 220.1089 | Pass with brief sampled OCP event |
| 264V 60Hz full | 4.3139 | 3.9031 | 4.3120 | 1.6443 | 410.4064 | 411.2812 | 410.1421 | 445.6135 | Pass; passive high-line inrush, no MOSFET OCP |

Startup notes:

- **90 V, 50 Hz:** the MOSFET branch reached 4.054 A and the inductor reached 4.111 A. A brief OCP indication was previously observed near 0.223 s; the overshoot is small relative to the 4 A sampled threshold, and steady-state current remains below OCP.
- **264 V, 60 Hz:** the 4.314 A input/inductor peak is the passive bypass/inrush path. The MOSFET branch peak was only 1.644 A, so this event is not a MOSFET OCP violation.
- Retained high-line precharge estimates: approximately 1.249 kW peak resistor power, 11.739 J energy, and 0.143 A²s.

## 4. Steady-state electrical performance

| Operating point | True PF | Filtered PF | Input P (W) | Output P (W) | Modeled efficiency (%) | Avg Vout (V) | Ripple (Vpp) | Drift (V) | Requirement result |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 90 V, 50 Hz, 100% | 0.999664 | 0.999687 | 103.986917 | 100.005765 | 96.171488 | 400.010569 | 4.482349 | -0.011201 | PASS |
| 120 V, 60 Hz, 100% | ≈0.999715 | — | — | ≈99.9 | ≈97.3069 | 399.782 | 3.688 | — | PASS |
| 120 V, 60 Hz, 50% | 0.999708 | 0.999762 | — | 50.000694 | 97.405421 | 400.003019 | 1.899647 | -0.000987 | PASS |
| 120 V, 60 Hz, 20% | 0.988762 | 0.988796 | 20.733796 | 19.999973 | 96.460739 | 399.999904 | 1.014453 | 0.003260 | PASS |
| 120 V, 60 Hz, no load | 0.254480† | 0.254663† | 0.142856 | 0.000161 | 0.112683† | 401.216366 | 0.015204 | -0.007602 | N/A |
| 120 V, 20→100%, post-step | 0.999733 | 0.999745 | 102.775838 | 99.999214 | 97.298369 | 399.998947 | 3.668139 | 0.000740 | PASS |
| 230 V, 50 Hz, 100% | ≈0.994517 | — | — | ≈99.832 | ≈98.1975 | 399.660414 | 4.318092 | — | PASS |
| 240 V, 60 Hz, 100% | ≈0.993675 | — | — | ≈99.9 | ≈98.2154 | 399.763 | 3.625 | — | PASS |
| 240 V, 60 Hz, 20% | 0.916414 | 0.920139 | 20.961356 | 19.998291 | 95.405522 | 399.983023 | 1.417310 | 0.018598 | PF FAIL / Eff PASS |
| 240 V, 60 Hz, no load | 0.255923† | 0.256105† | 0.574888 | 0.000162 | 0.028114† | 402.023149 | 0.010334 | -0.005167 | N/A |
| 240 V, 100→20%, post-step | 0.914614 | 0.912415 | 20.995491 | 20.000343 | 95.260182 | 399.987543 | 1.442951 | -0.001478 | PF FAIL / Eff PASS |
| 264 V, 60 Hz, 100% | 0.991258 | 0.991458 | 101.932788 | 100.004335 | 98.108113 | 400.008095 | 4.169157 | -0.014993 | PASS |

† At no load, PF and efficiency are reported only as raw numerical outputs. They are not meaningful compliance metrics because output power is essentially zero.

The 230 V / 50 Hz row uses the uploaded stress CSV for voltage, ripple, and component stress. Its PF, efficiency, and timing values are from the rounded simulation summary retained in this conversation.

## 5. Steady-state component stress from uploaded CSVs

| Operating point | Iac RMS (A) | iL peak (A) | MOSFET current peak (A) | Vout max (V) | Vout min (V) | Vds max (V) | Boost diode reverse (V) | Bridge diode reverse (V) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 90 V, 50 Hz, 100% | 1.15580 | 3.36548 | 3.32418 | 402.52993 | 398.04409 | 403.93478 | 401.81110 | 145.60175 |
| 120 V, 60 Hz, 100% | 0.85571 | 2.50514 | 2.44449 | 401.81573 | 398.12748 | 403.01431 | 401.27576 | 178.99136 |
| 120 V, 60 Hz, 50% | 0.42790 | 1.32356 | 1.26170 | 401.04914 | 399.14944 | 401.94421 | 400.77296 | 174.82647 |
| 120 V, 60 Hz, 20% | 0.17475 | 0.69792 | 0.63501 | 400.56752 | 399.55306 | 401.32691 | 400.42269 | 175.60284 |
| 120 V, 60 Hz, no load | 0.00468 | 0.00168 | 0.00169 | 401.22397 | 401.20876 | 168.50877 | 400.82394 | 169.10944 |
| 120 V, 20→100%, post-step | 0.85669 | 2.50517 | 2.44452 | 402.02698 | 398.35708 | 403.21128 | 401.47803 | 178.99324 |
| 230 V, 50 Hz, 100% | 0.44445 | 1.34250 | 1.22140 | 401.87916 | 397.56106 | 402.79080 | 401.58433 | 330.44040 |
| 240 V, 60 Hz, 100% | 0.42643 | 1.27519 | 1.14857 | 401.63836 | 398.01342 | 402.52184 | 401.36540 | 344.97559 |
| 240 V, 60 Hz, 20% | 0.09531 | 0.50542 | 0.46255 | 400.75687 | 399.33955 | 401.45267 | 400.66218 | 346.34658 |
| 240 V, 60 Hz, no load | 0.00936 | 0.00338 | 0.00339 | 402.02832 | 402.01798 | 338.21760 | 401.62749 | 338.81895 |
| 240 V, 100→20%, post-step | 0.09565 | 0.51297 | 0.48031 | 400.78999 | 399.34703 | 401.48580 | 400.69530 | 347.51610 |
| 264 V, 60 Hz, 100% | 0.38951 | 1.29798 | 1.15576 | 402.10422 | 397.93493 | 402.95611 | 401.86057 | 400.69674 |

## 6. Timing and switching behavior

| Operating point | Average Ton command (µs) | Average Fsw (kHz) | Maximum Fsw (kHz) |
|---|---:|---:|---:|
| 90 V, 50 Hz, 100% | 6.596 | 117.335 | 147.059 |
| 120 V, 60 Hz, 100% | ≈3.697 | ≈186.802 | 256.410 |
| 120 V, 60 Hz, 50% | 1.893 | 349.125 | 476.190 |
| 120 V, 60 Hz, 20% | 0.897 | 476.190 | 476.190 |
| 120 V, 60 Hz, no load | 0.200 command | No pulses | No pulses |
| 120 V, 20→100%, post-step | 3.699 | 186.667 | 256.410 |
| 230 V, 50 Hz, 100% | ≈0.899 | ≈356.516 | 476.190 |
| 240 V, 60 Hz, 100% | ≈0.806 | ≈351.146 | 476.190 |
| 240 V, 60 Hz, 20% | 0.200 | 474.218 | 476.190 |
| 240 V, 60 Hz, no load | 0.200 command | No pulses | No pulses |
| 240 V, 100→20%, post-step | 0.200 | 473.688 | 476.190 |
| 264 V, 60 Hz, 100% | 0.686 | 336.034 | 476.190 |

Important observations:

- At 120 V and 20% load, the converter operates continuously at the realized frequency ceiling while still achieving PF = 0.9888.
- At 240 V and 20% load, the on-time is pinned near 0.2 µs and the switching frequency is near the ceiling. The resulting current-envelope distortion reduces PF below 0.95.
- At no load, the on-time command remains clamped at 0.2 µs internally, but demand-enable blocks new pulses. No gate pulses were present in the 4–5 s measurement windows.

## 7. Load-step verification

| Test | Transient observation | Protection | Post-step result |
|---|---|---|---|
| 120 V, 60 Hz, 20% → 100% | Controlled Vout undershoot to approximately 365–367 V from the plotted waveform; recovery to near 400 V in about 1 s | OVP inactive; no observed instability | PF 0.999733, efficiency 97.298%, 100 W regulated |
| 240 V, 60 Hz, 100% → 20% | Vout overshoot remained below 420 V; plotted peak approximately 413–414 V | OVP/OCP inactive | 20 W regulated; efficiency 95.260%; known PF limitation remains |
| 264 V, 60 Hz, 100% → 20%, near line peak | **Measured Vout peak = 413.1815 V** | OVP/OCP inactive | Stable recovery; worst tested OVP margin = **6.8185 V** |

The post-step PF/efficiency measurements were taken only after the converter had returned to steady state. PF was not evaluated across the transient itself.

## 8. Charge-balanced current results

Charge-balanced companion CSVs were present for every steady-state run. They correct the inferred DC-area bias in `iCout` and `iBoostDiode` while preserving measured current peaks. Selected corrected ripple RMS values:

| Operating point | Corrected Cout ripple RMS (A) | Corrected boost-diode RMS (A) |
|---|---:|---:|
| 90 V, 50 Hz, 100% | 0.657836 | 0.703855 |
| 120 V, 60 Hz, 100% | 0.554555 | 0.608337 |
| 120 V, 60 Hz, 50% | 0.287511 | 0.313529 |
| 120 V, 60 Hz, 20% | 0.141574 | 0.150154 |
| 120 V, 60 Hz, no load | 0.000001 | 0.000003 |
| 120 V, 20→100%, post-step | 0.555001 | 0.608806 |
| 230 V, 50 Hz, 100% | 0.364922 | 0.442288 |
| 240 V, 60 Hz, 100% | 0.352420 | 0.432060 |
| 240 V, 60 Hz, 20% | 0.103390 | 0.114878 |
| 240 V, 60 Hz, no load | 0.000001 | 0.000002 |
| 240 V, 100→20%, post-step | 0.103712 | 0.115204 |
| 264 V, 60 Hz, 100% | 0.330708 | 0.414808 |

## 9. Requirement compliance

| Requirement | Final assessment |
|---|---|
| 400 V regulation | Pass across all tested loaded operating points; no-load bus remained bounded at approximately 401–402 V |
| PF > 0.95 at rated load | Pass at the refreshed full-load corners and the common 230 V / 50 Hz nominal point: 0.999664 at 90 V, approximately 0.994517 at 230 V, and 0.991258 at 264 V |
| Efficiency > 92% | Pass for every loaded steady-state case tested |
| Startup protection | Pass with documented brief low-line sampled OCP event; high-line passive inrush is outside the MOSFET OCP path |
| OVP behavior | Pass; no normal-regulation OVP cycling after the controller fixes |
| Load-step stability | Pass; controlled undershoot/overshoot and stable recovery |
| High-line 20% PF | Does not meet 0.95: approximately 0.915–0.916 due to minimum pulse width and maximum-frequency clamp |
| No-load PF/efficiency | Not applicable; use idle input power, bus voltage, and protection behavior instead |

## 10. Final conclusion

The final CrCM boost PFC simulation meets the 400 V, 100 W regulation target and passes the PF and modeled-efficiency requirements at the refreshed low-line and high-line full-load corners, as well as at the common 230 V / 50 Hz nominal mains point. Startup, no-load, reduced-load, protection, maximum-frequency, minimum-pulse, and load-step behaviors were verified.

The only documented performance exception is PF below 0.95 at 240 V and 20% load. Regulation and modeled efficiency still pass at that point. The limitation is associated with the 0.2 µs minimum on-time and the approximately 476 kHz realized switching-frequency ceiling.

The modeled efficiencies exclude switching loss, gate-drive loss, magnetic core loss, diode reverse-recovery loss, controller auxiliary power, and unmodeled parasitic spikes. Hardware component voltage ratings should therefore retain substantial margin beyond the simulated steady-state values.

## Appendix A — Uploaded files used

- `pfc_component_stress_startup_264V_60Hz_full.csv`
- `pfc_component_stress_startup_90V_50Hz_full.csv`
- `pfc_component_stress_steady_120V_60Hz_20pct.csv`
- `pfc_component_stress_steady_120V_60Hz_20pct_charge_balanced.csv`
- `pfc_component_stress_steady_120V_60Hz_50pct.csv`
- `pfc_component_stress_steady_120V_60Hz_50pct_charge_balanced.csv`
- `pfc_component_stress_steady_120V_60Hz_full.csv`
- `pfc_component_stress_steady_120V_60Hz_full_charge_balanced.csv`
- `pfc_component_stress_steady_120V_60Hz_noload.csv`
- `pfc_component_stress_steady_120V_60Hz_noload_charge_balanced.csv`
- `pfc_component_stress_steady_120V_60Hz_step20to100_post.csv`
- `pfc_component_stress_steady_120V_60Hz_step20to100_post_charge_balanced.csv`
- `pfc_component_stress_steady_230V_50Hz_full.csv`
- `pfc_component_stress_steady_230V_50Hz_full_charge_balanced.csv`
- `pfc_component_stress_steady_240V_60Hz_20pct.csv`
- `pfc_component_stress_steady_240V_60Hz_20pct_charge_balanced.csv`
- `pfc_component_stress_steady_240V_60Hz_full.csv`
- `pfc_component_stress_steady_240V_60Hz_full_charge_balanced.csv`
- `pfc_component_stress_steady_240V_60Hz_noload.csv`
- `pfc_component_stress_steady_240V_60Hz_noload_charge_balanced.csv`
- `pfc_component_stress_steady_240V_60Hz_step100to20_post.csv`
- `pfc_component_stress_steady_240V_60Hz_step100to20_post_charge_balanced.csv`
- `pfc_component_stress_steady_264V_60Hz_full.csv`
- `pfc_component_stress_steady_264V_60Hz_full_charge_balanced.csv`
- `pfc_component_stress_steady_90V_50Hz_full.csv`
- `pfc_component_stress_steady_90V_50Hz_full_charge_balanced.csv`
