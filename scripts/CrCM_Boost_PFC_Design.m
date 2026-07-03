%% CrCM_Boost_PFC_Design_Nonideal.m
% Initial nonideal preliminary design calculator for a CrCM / BCM boost PFC.
%
% Includes the piecewise-linear diode drops/resistances,
% MOSFET RDS(on)/off conductance, inductor DCR, capacitor ESR/leakage,
% optional switching-energy losses, and the variable CrCM frequency.
%
% IMPORTANT LIMITATIONS
% ---------------------
% 1) PF is an ASSUMED input to the component-stress calculation. The script
%    cannot prove PF > 0.95; measure PF from the simulated line voltage and
%    line current after the controller is closed-loop and settled.
% 2) The MOSFET (Ideal, Switching) and piecewise-linear Diode blocks do not
%    automatically reproduce all real switching behavior.
% 3) Core loss, winding AC loss, EMI filter loss, snubber loss, gate-drive
%    loss, temperature dependence, tolerances, and control-loop dynamics
%    are not fully modeled unless enter estimates.
% 4) CrCM switching frequency is variable. The target below is the
%    switching frequency at the 90-VAC line crest, not a fixed frequency.

clear;
clc;
close all;

%% System requirements
spec.Vin_rms_min = 90;          % [V RMS]
spec.Vin_rms_max = 264;         % [V RMS]
spec.fline_min   = 50;          % [Hz]
spec.fline_max   = 60;          % [Hz]

spec.Vout        = 400;         % [V DC]
spec.Pout        = 100;         % [W]
spec.eta_min     = 0.92;        % required minimum efficiency
spec.PF_min      = 0.95;        % required minimum PF

% Expected PF used to estimate normal operating current.
spec.PF_expected = 0.99;

% Desired natural CrCM frequency at the crest of 90 VAC.
spec.fsw_low_line_crest_target = 100e3;   % [Hz]

% Practical maximum-frequency clamp. Near a line zero crossing, a real
% controller normally clamps frequency, skips cycles, or enters DCM.
spec.fsw_max_clamp = 250e3;               % [Hz]

% Output-bus ripple design assumption.
spec.Vout_ripple_pp_percent = 1.0;        % [% peak-to-peak]

% Optional hold-up requirement.
spec.hold_up_time = 0e-3;                  % [s], set to zero if unused
spec.Vout_hold_min = 350;                  % [V]

% Current-sense assumptions.
spec.Vcs_threshold = 1.0;                  % [V]
spec.current_limit_margin = 1.25;          % multiplier

% Candidate values used only to suggest convenient component values.
spec.L_candidates_uH = [180 200 220 240 250 270 300 330 390 470];
spec.C_candidates_uF = [68 82 100 120 150 180 220 270 330 390 470];

%% CASE 1: current Simulink component parameters
sim.name = "Current Simulink parameters";

% All bridge and boost diodes currently use the same piecewise-linear model.
sim.Vf_bridge   = 0.6;       % one bridge diode forward voltage [V]
sim.Ron_bridge  = 0.3;       % one bridge diode on resistance [ohm]
sim.Goff_bridge = 1e-8;      % one bridge diode off conductance [S]

sim.Vf_boost    = 0.6;       % boost diode forward voltage [V]
sim.Ron_boost   = 0.3;       % boost diode on resistance [ohm]
sim.Goff_boost  = 1e-8;      % boost diode off conductance [S]

sim.Rds_on      = 0.01;      % MOSFET on resistance [ohm]
sim.Goff_mosfet = 1e-6;      % MOSFET off conductance [S]
sim.Vth         = 2.0;       % MOSFET gate-source threshold [V]

sim.R_L         = 0.0;       % boost-inductor series resistance [ohm]
sim.G_L         = 1e-9;      % boost-inductor parallel conductance [S]

sim.ESR_C       = 0.0;       % bulk-capacitor ESR [ohm]
sim.G_C         = 0.0;       % bulk-capacitor parallel conductance [S]

% Optional representative switching energies per event.
% Leave at zero to match an ideal-switching model with no entered losses.
sim.Eon_mosfet  = 0;         % [J/event]
sim.Eoff_mosfet = 0;         % [J/event]
sim.Erec_diode  = 0;         % [J/event]

% Optional lumped losses.
sim.Pcore_est   = 0;         % inductor core + AC winding loss estimate [W]
sim.Pgate_est   = 0;         % gate-drive/controller estimate [W]
sim.Pother_est  = 0;         % EMI, snubber, auxiliary supply, etc. [W]

%% CASE 2: illustrative nonideal placeholders
% These are NOT universal component values. Replace them with the actual
% MOSFET, inductor, and capacitor datasheets when parts are selected.
real = sim;
real.name = "Illustrative realistic placeholders";
real.Rds_on      = 0.30;     % example warm 600/650-V silicon MOSFET [ohm]
real.Goff_mosfet = 1e-8;     % lower artificial off-state leakage [S]
real.R_L         = 0.10;     % example boost-inductor DCR [ohm]
real.ESR_C       = 0.30;     % example 450-V electrolytic ESR [ohm]

% Optional example switching/core losses remain zero by default so that
% the program does not invent datasheet values. Enter real values later.

%% Run both cases
result_sim  = analyzeCase(sim, spec);
result_real = analyzeCase(real, spec);

%% Output-capacitor sizing
Vout = spec.Vout;
Pout = spec.Pout;
Iout = Pout / Vout;
Rload = Vout^2 / Pout;

DeltaVout_pp_allowed = ...
    spec.Vout_ripple_pp_percent / 100 * Vout;

% Unity-PF input power contains a 2*fline power pulsation.
Cout_ripple = Pout / ...
    (2*pi*spec.fline_min*Vout*DeltaVout_pp_allowed);

if spec.hold_up_time > 0
    assert(spec.Vout_hold_min < Vout, ...
        'Vout_hold_min must be smaller than Vout.');
    Cout_hold = 2*Pout*spec.hold_up_time / ...
        (Vout^2 - spec.Vout_hold_min^2);
else
    Cout_hold = 0;
end

Cout_calculated = max(Cout_ripple, Cout_hold);
Cout_selected = selectAtOrAbove( ...
    Cout_calculated, spec.C_candidates_uF*1e-6);

DeltaVout_pp_selected = Pout / ...
    (2*pi*spec.fline_min*Vout*Cout_selected);

%% Current-sense resistor based on the more conservative low-line peak
ILpk_design = max( ...
    result_sim.low.IL_pk_max, result_real.low.IL_pk_max);

IL_current_limit = spec.current_limit_margin * ILpk_design;
Rsense = spec.Vcs_threshold / IL_current_limit;

%% Summary
fprintf('\n============================================================\n');
fprintf('CrCM / BCM BOOST-PFC NONIDEAL PRELIMINARY DESIGN\n');
fprintf('============================================================\n');
fprintf('Input                         : %.0f to %.0f VAC, %.0f/%.0f Hz\n', ...
    spec.Vin_rms_min, spec.Vin_rms_max, ...
    spec.fline_min, spec.fline_max);
fprintf('Output                        : %.0f V, %.0f W\n', ...
    spec.Vout, spec.Pout);
fprintf('Full-load output current      : %.3f A\n', Iout);
fprintf('Full-load resistance          : %.1f ohm\n', Rload);
fprintf('Required PF / efficiency      : > %.2f / > %.1f %%\n', ...
    spec.PF_min, 100*spec.eta_min);
fprintf('PF assumed for calculations   : %.3f\n', spec.PF_expected);
fprintf('Target fsw at 90-VAC crest    : %.1f kHz\n', ...
    spec.fsw_low_line_crest_target/1e3);
fprintf('Maximum-frequency clamp       : %.1f kHz\n', ...
    spec.fsw_max_clamp/1e3);

fprintf('\n--- Case comparison at 90 VAC ---\n');
CaseName = [result_sim.name; result_real.name];
PredictedEfficiency_pct = [ ...
    100*result_sim.low.efficiency; ...
    100*result_real.low.efficiency];
InputRMS_A = [ ...
    result_sim.low.Iin_rms; ...
    result_real.low.Iin_rms];
PeakInductor_A = [ ...
    result_sim.low.IL_pk_max; ...
    result_real.low.IL_pk_max];
CalculatedL_uH = [ ...
    result_sim.L_calculated*1e6; ...
    result_real.L_calculated*1e6];
SuggestedL_uH = [ ...
    result_sim.L_selected*1e6; ...
    result_real.L_selected*1e6];
ActualCrestFsw_kHz = [ ...
    result_sim.low.fsw_crest/1e3; ...
    result_real.low.fsw_crest/1e3];

Comparison = table( ...
    CaseName, PredictedEfficiency_pct, InputRMS_A, ...
    PeakInductor_A, CalculatedL_uH, SuggestedL_uH, ...
    ActualCrestFsw_kHz);
disp(Comparison);

fprintf('\n--- Suggested power-stage starting values ---\n');
fprintf('Boost inductance              : %.0f uH using current model\n', ...
    result_sim.L_selected*1e6);
fprintf('                              : %.0f uH using placeholders\n', ...
    result_real.L_selected*1e6);
fprintf('Bulk capacitance calculated   : %.1f uF\n', ...
    Cout_calculated*1e6);
fprintf('Bulk capacitance suggested    : %.0f uF, at least 450 V\n', ...
    Cout_selected*1e6);
fprintf('Ripple with suggested C       : %.2f V peak-to-peak at %.0f Hz line\n', ...
    DeltaVout_pp_selected, spec.fline_min);
fprintf('Current-sense resistance      : %.3f ohm for %.2f-V threshold\n', ...
    Rsense, spec.Vcs_threshold);
fprintf('Current-limit design point    : %.3f A\n', IL_current_limit);

fprintf('\n--- Current Simulink case: operating points ---\n');
displayOperatingTable(result_sim);

fprintf('\n--- Illustrative realistic case: operating points ---\n');
displayOperatingTable(result_real);

fprintf('\n--- Estimated low-line losses ---\n');
displayLossTable(result_sim.low, result_real.low);

fprintf('\nINTERPRETATION\n');
fprintf(['1) The calculated efficiency is only a conduction/leakage estimate plus\n' ...
         '   any switching/core/other losses that you manually enter.\n']);
fprintf(['2) With all switching energies and core loss set to zero, the result is\n' ...
         '   intentionally optimistic and does not verify the 92%% goal.\n']);
fprintf(['3) PF is not determined by L and C alone. Measure it from settled\n' ...
         '   line-voltage and line-current waveforms in the closed-loop model.\n']);
fprintf(['4) The MOSFET gate-source voltage must exceed Vth = %.1f V. A 0/1-V\n' ...
         '   gate command will not turn on this physical-gate block.\n'], sim.Vth);
fprintf(['5) CrCM frequency is variable. The inductor current should reach zero\n' ...
         '   once per switching cycle, while its envelope varies at 2*fline.\n']);
fprintf('============================================================\n\n');

%% Plot natural CrCM switching frequency for the selected realistic L
plotFrequencyCurve(result_real, real, spec);

%% Local functions
function result = analyzeCase(dev, spec)
    % Iterate because the current, losses, and inductance are coupled.
    L = 250e-6;

    for n = 1:40
        low = solveOperatingPoint(spec.Vin_rms_min, L, dev, spec);
        L_new = solveInductanceAtCrest( ...
            spec.Vin_rms_min, low.IL_pk_max, dev, spec);

        if abs(L_new - L) / L_new < 1e-7
            L = L_new;
            break;
        end

        L = 0.5*L + 0.5*L_new;
    end

    L_calculated = L;
    L_selected = selectAtOrAbove( ...
        L_calculated, spec.L_candidates_uH*1e-6);

    low  = solveOperatingPoint(spec.Vin_rms_min, L_selected, dev, spec);
    high = solveOperatingPoint(spec.Vin_rms_max, L_selected, dev, spec);

    result.name = dev.name;
    result.L_calculated = L_calculated;
    result.L_selected = L_selected;
    result.low = low;
    result.high = high;
end

function op = solveOperatingPoint(Vin_rms, L, dev, spec)
    theta = linspace(0, pi, 20001);
    Vout = spec.Vout;
    Pout = spec.Pout;
    Iout = Pout / Vout;

    Pin = Pout / 0.96;

    for iteration = 1:100
        Iin_rms = Pin / (spec.PF_expected * Vin_rms);
        Iline_avg_pk = sqrt(2) * Iin_rms;

        % In ideal CrCM, the switching-cycle current is triangular from
        % zero to Ipk and back to zero, so its cycle average is Ipk/2.
        IL_pk_max = 2 * Iline_avg_pk;

        wave = calculateWaveMetrics( ...
            Vin_rms, IL_pk_max, L, dev, spec, theta);

        P_bridge = ...
            2*dev.Vf_bridge*wave.Irect_avg + ...
            2*dev.Ron_bridge*wave.IL_rms^2;

        P_boost_diode = ...
            dev.Vf_boost*Iout + ...
            dev.Ron_boost*wave.ID_rms^2;

        P_mosfet_conduction = dev.Rds_on*wave.IQ_rms^2;
        P_inductor_copper   = dev.R_L*wave.IL_rms^2;
        P_capacitor_esr     = dev.ESR_C*wave.IC_rms^2;

        % Approximate leakage losses.
        P_mosfet_off = ...
            dev.Goff_mosfet*Vout^2*wave.mosfet_off_fraction;

        P_boost_diode_off = wave.P_boost_diode_off_leak;
        P_capacitor_leak  = dev.G_C*Vout^2;

        % Representative energy-per-event model.
        P_switching = ...
            (dev.Eon_mosfet + dev.Eoff_mosfet + dev.Erec_diode) * ...
            wave.fsw_average_for_loss;

        P_loss = ...
            P_bridge + P_boost_diode + P_mosfet_conduction + ...
            P_inductor_copper + P_capacitor_esr + ...
            P_mosfet_off + P_boost_diode_off + ...
            P_capacitor_leak + P_switching + ...
            dev.Pcore_est + dev.Pgate_est + dev.Pother_est;

        Pin_new = Pout + P_loss;

        if abs(Pin_new - Pin) < 1e-9
            Pin = Pin_new;
            break;
        end

        Pin = 0.5*Pin + 0.5*Pin_new;
    end

    % Recalculate the final waveform with the converged input power.
    Iin_rms = Pin / (spec.PF_expected * Vin_rms);
    Iline_avg_pk = sqrt(2) * Iin_rms;
    IL_pk_max = 2 * Iline_avg_pk;

    wave = calculateWaveMetrics( ...
        Vin_rms, IL_pk_max, L, dev, spec, theta);

    % Rebuild the final loss values for reporting.
    P_bridge = ...
        2*dev.Vf_bridge*wave.Irect_avg + ...
        2*dev.Ron_bridge*wave.IL_rms^2;
    P_boost_diode = ...
        dev.Vf_boost*Iout + ...
        dev.Ron_boost*wave.ID_rms^2;
    P_mosfet_conduction = dev.Rds_on*wave.IQ_rms^2;
    P_inductor_copper = dev.R_L*wave.IL_rms^2;
    P_capacitor_esr = dev.ESR_C*wave.IC_rms^2;
    P_mosfet_off = ...
        dev.Goff_mosfet*Vout^2*wave.mosfet_off_fraction;
    P_boost_diode_off = wave.P_boost_diode_off_leak;
    P_capacitor_leak = dev.G_C*Vout^2;
    P_switching = ...
        (dev.Eon_mosfet + dev.Eoff_mosfet + dev.Erec_diode) * ...
        wave.fsw_average_for_loss;

    losses.bridge = P_bridge;
    losses.boost_diode = P_boost_diode;
    losses.mosfet_conduction = P_mosfet_conduction;
    losses.inductor_copper = P_inductor_copper;
    losses.capacitor_esr = P_capacitor_esr;
    losses.mosfet_off_leakage = P_mosfet_off;
    losses.boost_diode_off_leakage = P_boost_diode_off;
    losses.capacitor_leakage = P_capacitor_leak;
    losses.switching = P_switching;
    losses.core = dev.Pcore_est;
    losses.gate = dev.Pgate_est;
    losses.other = dev.Pother_est;

    lossVector = cell2mat(struct2cell(losses));
    P_loss = sum(lossVector);

    op.Vin_rms = Vin_rms;
    op.Pin = Pout + P_loss;
    op.efficiency = Pout / op.Pin;
    op.Iin_rms = op.Pin / (spec.PF_expected * Vin_rms);
    op.Iline_avg_pk = sqrt(2)*op.Iin_rms;
    op.IL_pk_max = 2*op.Iline_avg_pk;
    op.IL_rms = wave.IL_rms;
    op.IQ_rms = wave.IQ_rms;
    op.ID_rms = wave.ID_rms;
    op.IC_rms = wave.IC_rms;
    op.fsw_crest = wave.fsw_crest;
    op.fsw_average_for_loss = wave.fsw_average_for_loss;
    op.fsw_natural_max = wave.fsw_natural_max;
    op.losses = losses;
end

function wave = calculateWaveMetrics( ...
        Vin_rms, IL_pk_max, L, dev, spec, theta)

    Vpk = sqrt(2)*Vin_rms;
    sinTheta = sin(theta);
    vin = Vpk*sinTheta;
    ipk = IL_pk_max*sinTheta;

    R_on_path = ...
        2*dev.Ron_bridge + dev.R_L + dev.Rds_on;
    R_off_path = ...
        2*dev.Ron_bridge + dev.R_L + dev.Ron_boost;

    V_on_constant = vin - 2*dev.Vf_bridge;
    V_off_constant = ...
        spec.Vout + 2*dev.Vf_bridge + dev.Vf_boost - vin;

    ton = zeros(size(theta));
    toff = zeros(size(theta));

    active = ...
        ipk > 1e-12 & ...
        V_on_constant > R_on_path.*ipk & ...
        V_off_constant > 0;

    if R_on_path > 1e-15
        ton(active) = ...
            -L/R_on_path .* log( ...
            1 - R_on_path.*ipk(active)./V_on_constant(active));
    else
        ton(active) = ...
            L.*ipk(active)./V_on_constant(active);
    end

    if R_off_path > 1e-15
        toff(active) = ...
            L/R_off_path .* log( ...
            1 + R_off_path.*ipk(active)./V_off_constant(active));
    else
        toff(active) = ...
            L.*ipk(active)./V_off_constant(active);
    end

    Tnatural = ton + toff;
    fswNatural = zeros(size(theta));
    fswNatural(active) = 1./Tnatural(active);

    % Duty fractions during active CrCM operation.
    Dsw = zeros(size(theta));
    Ddiode = zeros(size(theta));
    Dsw(active) = ton(active)./Tnatural(active);
    Ddiode(active) = toff(active)./Tnatural(active);

    % Near the line zero crossing the exact fixed-drop model cannot support
    % a perfectly sinusoidal current reference. The current there is tiny,
    % so use the ideal duty fractions only for RMS integration continuity.
    inactive = ~active;
    Dsw_ideal = max(0, min(1, 1 - vin/spec.Vout));
    Dsw(inactive) = Dsw_ideal(inactive);
    Ddiode(inactive) = 1 - Dsw(inactive);

    % For a triangular 0-to-Ipk-to-0 waveform:
    % mean(i^2) over the full switching period = Ipk^2/3.
    IL_rms = sqrt(trapz(theta, ipk.^2/3)/pi);
    IQ_rms = sqrt(trapz(theta, Dsw.*ipk.^2/3)/pi);
    ID_rms = sqrt(trapz(theta, Ddiode.*ipk.^2/3)/pi);

    % Rectified average line current.
    Irect_avg = trapz(theta, ipk/2)/pi;

    % Output-capacitor RMS current approximation:
    % on-time:  iC = -Iout
    % off-time: iC = iL - Iout
    Iout = spec.Pout/spec.Vout;
    iC_squared = ...
        Iout^2 + Ddiode.*(ipk.^2/3 - ipk*Iout);
    iC_squared = max(iC_squared, 0);
    IC_rms = sqrt(trapz(theta, iC_squared)/pi);

    % Frequency used for switching-loss estimate. This clamp approximation
    % does not attempt to reproduce the controller's exact skip/DCM logic.
    fswForLoss = min(fswNatural, spec.fsw_max_clamp);
    fsw_average_for_loss = trapz(theta, fswForLoss)/pi;

    % Natural frequency at the line crest.
    [~, crestIndex] = max(vin);
    fsw_crest = fswNatural(crestIndex);
    fsw_natural_max = max(fswNatural);

    % Approximate boost-diode reverse leakage while the MOSFET is on.
    Vreverse_boost = max(spec.Vout - vin, 0);
    P_boost_diode_off_leak = trapz( ...
        theta, dev.Goff_boost.*Vreverse_boost.^2.*Dsw)/pi;

    wave.IL_rms = IL_rms;
    wave.IQ_rms = IQ_rms;
    wave.ID_rms = ID_rms;
    wave.IC_rms = IC_rms;
    wave.Irect_avg = Irect_avg;
    wave.fsw_crest = fsw_crest;
    wave.fsw_average_for_loss = fsw_average_for_loss;
    wave.fsw_natural_max = fsw_natural_max;
    wave.mosfet_off_fraction = trapz(theta, 1-Dsw)/pi;
    wave.P_boost_diode_off_leak = P_boost_diode_off_leak;
    wave.theta = theta;
    wave.vin = vin;
    wave.fswNatural = fswNatural;
end

function L = solveInductanceAtCrest(Vin_rms, IL_pk, dev, spec)
    vin = sqrt(2)*Vin_rms;

    R_on_path = ...
        2*dev.Ron_bridge + dev.R_L + dev.Rds_on;
    R_off_path = ...
        2*dev.Ron_bridge + dev.R_L + dev.Ron_boost;

    V_on_constant = vin - 2*dev.Vf_bridge;
    V_off_constant = ...
        spec.Vout + 2*dev.Vf_bridge + dev.Vf_boost - vin;

    assert(V_on_constant > R_on_path*IL_pk, ...
        'The selected device drops cannot support the requested crest current.');
    assert(V_off_constant > 0, ...
        'Output voltage is too low for boost operation at this line voltage.');

    if R_on_path > 1e-15
        k_on = ...
            -log(1 - R_on_path*IL_pk/V_on_constant)/R_on_path;
    else
        k_on = IL_pk/V_on_constant;
    end

    if R_off_path > 1e-15
        k_off = ...
            log(1 + R_off_path*IL_pk/V_off_constant)/R_off_path;
    else
        k_off = IL_pk/V_off_constant;
    end

    % ton + toff = L*(k_on + k_off)
    L = 1 / ...
        (spec.fsw_low_line_crest_target*(k_on + k_off));
end

function selected = selectAtOrAbove(calculated, candidates)
    index = find(candidates >= calculated, 1, 'first');

    if isempty(index)
        selected = candidates(end);
        warning(['Calculated value exceeds the largest candidate. ' ...
                 'The largest listed candidate was returned.']);
    else
        selected = candidates(index);
    end
end

function displayOperatingTable(result)
    Line = ["90 VAC"; "264 VAC"];
    Efficiency_pct = [ ...
        100*result.low.efficiency; ...
        100*result.high.efficiency];
    InputPower_W = [result.low.Pin; result.high.Pin];
    InputRMS_A = [result.low.Iin_rms; result.high.Iin_rms];
    PeakInductor_A = [ ...
        result.low.IL_pk_max; result.high.IL_pk_max];
    InductorRMS_A = [result.low.IL_rms; result.high.IL_rms];
    MOSFETRMS_A = [result.low.IQ_rms; result.high.IQ_rms];
    DiodeRMS_A = [result.low.ID_rms; result.high.ID_rms];
    CrestFrequency_kHz = [ ...
        result.low.fsw_crest/1e3; ...
        result.high.fsw_crest/1e3];
    AverageClampedFrequency_kHz = [ ...
        result.low.fsw_average_for_loss/1e3; ...
        result.high.fsw_average_for_loss/1e3];

    T = table( ...
        Line, Efficiency_pct, InputPower_W, InputRMS_A, ...
        PeakInductor_A, InductorRMS_A, MOSFETRMS_A, ...
        DiodeRMS_A, CrestFrequency_kHz, ...
        AverageClampedFrequency_kHz);
    disp(T);
end

function displayLossTable(simLow, realLow)
    LossName = [ ...
        "Bridge conduction"; ...
        "Boost-diode conduction"; ...
        "MOSFET conduction"; ...
        "Inductor copper"; ...
        "Capacitor ESR"; ...
        "MOSFET off leakage"; ...
        "Boost-diode off leakage"; ...
        "Capacitor leakage"; ...
        "Entered switching loss"; ...
        "Entered core loss"; ...
        "Entered gate loss"; ...
        "Entered other loss"];

    SimulinkCase_W = cell2mat(struct2cell(simLow.losses));
    RealisticCase_W = cell2mat(struct2cell(realLow.losses));

    LossTable = table(LossName, SimulinkCase_W, RealisticCase_W);
    disp(LossTable);
end

function plotFrequencyCurve(result, dev, spec)
    op = result.low;
    theta = linspace(0, pi, 20001);
    waveLow = calculateWaveMetrics( ...
        spec.Vin_rms_min, op.IL_pk_max, ...
        result.L_selected, dev, spec, theta);

    opHigh = result.high;
    waveHigh = calculateWaveMetrics( ...
        spec.Vin_rms_max, opHigh.IL_pk_max, ...
        result.L_selected, dev, spec, theta);

    figure;
    hold on;
    grid on;

    plot(theta*180/pi, waveLow.fswNatural/1e3, ...
        'LineWidth', 1.5);
    plot(theta*180/pi, waveHigh.fswNatural/1e3, ...
        'LineWidth', 1.5);
    yline(spec.fsw_max_clamp/1e3, '--', ...
        'Maximum-frequency clamp');

    xlabel('Rectified line angle (degrees)');
    ylabel('Natural CrCM switching frequency (kHz)');
    title('Variable Natural Switching Frequency of the CrCM Boost PFC');
    legend('90 VAC', '264 VAC', 'Clamp', 'Location', 'best');
    ylim([0, 1.1*spec.fsw_max_clamp/1e3]);
    hold off;
end
