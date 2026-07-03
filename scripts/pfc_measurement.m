%% CrCM PFC steady-state PF and efficiency measurement
%
% This script measures source-side true PF and modeled efficiency over the
% final steady-state interval. It also reports a low-frequency current-
% envelope PF as a controller-shape diagnostic.
%
% Required logged signals:
%   Vac, Iac, Vout
%
% Optional logged signal:
%   Iout
%
% Notes:
% - The true PF result uses the unfiltered source-side Vac and Iac.
% - The filtered-envelope PF is diagnostic only and is not the official PF.
% - Efficiency includes only losses represented in the simulation model.

clearvars -except out

%% User settings
measurement_duration = 0.2;   % [s], integer cycles at both 50 and 60 Hz
analysis_fs          = 1e6;   % [Hz], uniform analysis sampling rate
line_frequency       = 60;    % [Hz], informational/checking only

% Adjust RL for intended load % testing.
RL   = 1600;                  % [ohm]
Cout = 220e-6;                % [F], used only to estimate DC-bus energy drift

pf_requirement  = 0.95;
eff_requirement = 92.0;       % [%]

fc_pf     = 2e3;              % [Hz], envelope-PF low-pass cutoff
edge_time = 0.05;             % [s], discarded at each filter edge

%% Validate simulation output
if ~exist('out', 'var')
    error('Simulation output variable "out" was not found. Run the model first.');
end

try
    logs = out.logsout;
catch
    error('The simulation output does not contain logsout.');
end

if isempty(logs)
    error('logsout is empty.');
end

signal_names = string(getElementNames(logs));

required = ["Vac", "Iac", "Vout"];
missing = required(~ismember(required, signal_names));

if ~isempty(missing)
    error('Missing required logged signal(s): %s', strjoin(missing, ', '));
end

has_iout = any(signal_names == "Iout");

vac_ts  = logs.get('Vac').Values;
iac_ts  = logs.get('Iac').Values;
vout_ts = logs.get('Vout').Values;

if has_iout
    iout_ts = logs.get('Iout').Values;
end

%% Determine a common final interval
signal_end_times = [ ...
    double(vac_ts.Time(end)), ...
    double(iac_ts.Time(end)), ...
    double(vout_ts.Time(end))];

signal_start_times = [ ...
    double(vac_ts.Time(1)), ...
    double(iac_ts.Time(1)), ...
    double(vout_ts.Time(1))];

if has_iout
    signal_end_times(end+1) = double(iout_ts.Time(end));
    signal_start_times(end+1) = double(iout_ts.Time(1));
end

common_end = min(signal_end_times);
requested_start = common_end - measurement_duration;
common_available_start = max(signal_start_times);

if requested_start < common_available_start
    error(['The requested %.3f s measurement window is not fully available. ', ...
        'Common logged interval begins at %.9f s and ends at %.9f s.'], ...
        measurement_duration, common_available_start, common_end);
end

%% Crop each signal before interpolation to reduce memory use
% A small pad preserves interpolation support at the exact window endpoints.
pad_time = max(5/analysis_fs, 1e-6);
crop_start = requested_start - pad_time;
crop_end   = common_end + pad_time;

[t_vac,  vac_crop]  = crop_timeseries(vac_ts,  crop_start, crop_end);
[t_iac,  iac_crop]  = crop_timeseries(iac_ts,  crop_start, crop_end);
[t_vout, vout_crop] = crop_timeseries(vout_ts, crop_start, crop_end);

if has_iout
    [t_iout, iout_crop] = crop_timeseries(iout_ts, crop_start, crop_end);
end

%% Uniform analysis time vector
tm = (requested_start : 1/analysis_fs : common_end).';

if tm(end) < common_end
    tm(end+1,1) = common_end;
end

vac_m  = interp1(t_vac,  vac_crop,  tm, 'linear');
iac_m  = interp1(t_iac,  iac_crop,  tm, 'linear');
vout_m = interp1(t_vout, vout_crop, tm, 'linear');

if has_iout
    iout_m = interp1(t_iout, iout_crop, tm, 'linear');
end

if any(~isfinite(vac_m)) || any(~isfinite(iac_m)) || ...
        any(~isfinite(vout_m)) || ...
        (has_iout && any(~isfinite(iout_m)))
    error(['Interpolation produced NaN or Inf values. Check that all logged ', ...
        'signals cover the requested measurement interval.']);
end

if numel(tm) < 10
    error('Not enough samples in the selected measurement window.');
end

measurement_time = tm(end) - tm(1);
line_cycles = measurement_time * line_frequency;

%% Input measurements: official source-side true PF
pin_inst = vac_m .* iac_m;

Pin = trapz(tm, pin_inst) / measurement_time;
Vac_rms = sqrt(trapz(tm, vac_m.^2) / measurement_time);
Iac_rms = sqrt(trapz(tm, iac_m.^2) / measurement_time);

apparent_power = Vac_rms * Iac_rms;
PF = Pin / apparent_power;

%% Output measurements
% Use logged load current when available. Also calculate the resistive-load
% estimate so the two methods can be compared.
pout_resistive_inst = vout_m.^2 / RL;
Pout_resistive = trapz(tm, pout_resistive_inst) / measurement_time;

if has_iout
    pout_inst = vout_m .* iout_m;
    Pout = trapz(tm, pout_inst) / measurement_time;
    Iout_avg = trapz(tm, iout_m) / measurement_time;
    Iout_rms = sqrt(trapz(tm, iout_m.^2) / measurement_time);

    pout_method_difference = 100 * ...
        (Pout - Pout_resistive) / max(abs(Pout_resistive), eps);
else
    Pout = Pout_resistive;
    Iout_avg = NaN;
    Iout_rms = NaN;
    pout_method_difference = NaN;
end

efficiency = 100 * Pout / Pin;

%% Output-voltage quantities and steady-state drift
Vout_avg = trapz(tm, vout_m) / measurement_time;
Vout_rms = sqrt(trapz(tm, vout_m.^2) / measurement_time);
Vout_ripple_pp = max(vout_m) - min(vout_m);

n = numel(vout_m);
split_index = floor(n/2);

Vout_first_half = trapz( ...
    tm(1:split_index), vout_m(1:split_index)) / ...
    (tm(split_index) - tm(1));

Vout_second_half = trapz( ...
    tm(split_index+1:end), vout_m(split_index+1:end)) / ...
    (tm(end) - tm(split_index+1));

Vout_window_drift = Vout_second_half - Vout_first_half;

delta_Eout_cap = 0.5 * Cout * (vout_m(end)^2 - vout_m(1)^2);
Pcap_average = delta_Eout_cap / measurement_time;

%% Low-frequency current-envelope PF
% This is a controller-waveform diagnostic. It does not replace true PF.
if exist('lowpass', 'file') == 2
    iac_lf = lowpass(iac_m, fc_pf, analysis_fs);
else
    % Approximately reject switching ripple with a short moving average.
    ma_window_time = 200e-6;
    ma_window_samples = max(1, round(ma_window_time * analysis_fs));
    iac_lf = movmean(iac_m, ma_window_samples);
end

if measurement_time <= 2 * edge_time
    warning(['Measurement interval is too short to discard %.3f s from ', ...
        'each filter edge. Envelope PF was not calculated.'], edge_time);
    PF_lf = NaN;
else
    valid = tm >= tm(1) + edge_time & tm <= tm(end) - edge_time;

    tv = tm(valid);
    vv = vac_m(valid);
    iv = iac_lf(valid);

    measurement_time_lf = tv(end) - tv(1);

    Pin_lf = trapz(tv, vv .* iv) / measurement_time_lf;
    Vac_rms_lf = sqrt(trapz(tv, vv.^2) / measurement_time_lf);
    Iac_rms_lf = sqrt(trapz(tv, iv.^2) / measurement_time_lf);

    PF_lf = Pin_lf / (Vac_rms_lf * Iac_rms_lf);
end

%% Polarity and validity checks
if Pin <= 0
    warning(['Average input power is nonpositive. Reverse the Iac sensor ', ...
        'polarity. Do not use abs(Iac).']);
end

if Pout <= 0
    warning(['Average output power is nonpositive. Reverse the Iout sensor ', ...
        'polarity or verify the load model.']);
end

if PF > 1.001 || PF < -1.001
    warning('Calculated PF is outside the expected range. Check signal alignment.');
end

if efficiency > 100.5
    warning(['Calculated efficiency exceeds 100.5%%. Check signal polarity, ', ...
        'time alignment, and DC-bus drift.']);
end

if has_iout && abs(pout_method_difference) > 0.5
    warning(['Logged-Iout output power differs from Vout^2/RL by %.3f%%. ', ...
        'Check Iout polarity, load-switch state, and signal alignment.'], ...
        pout_method_difference);
end

%% Print results
fprintf('\n');
fprintf('CrCM PFC steady-state PF and efficiency measurements\n');
fprintf('----------------------------------------------------\n');
fprintf('Measurement interval      : %.6f s to %.6f s\n', tm(1), tm(end));
fprintf('Measurement duration      : %.6f s\n', measurement_time);
fprintf('Nominal line cycles       : %.3f cycles at %.1f Hz\n', ...
    line_cycles, line_frequency);
fprintf('Uniform analysis rate     : %.3f MHz\n', analysis_fs/1e6);
fprintf('\n');

fprintf('INPUT\n');
fprintf('Vac RMS                   : %.6f V\n', Vac_rms);
fprintf('Iac RMS                   : %.6f A\n', Iac_rms);
fprintf('Input real power          : %.6f W\n', Pin);
fprintf('Input apparent power      : %.6f VA\n', apparent_power);
fprintf('Source-side true PF       : %.6f\n', PF);

if isfinite(PF_lf)
    fprintf('Filtered-envelope PF      : %.6f\n', PF_lf);
else
    fprintf('Filtered-envelope PF      : not calculated\n');
end

fprintf('\n');
fprintf('OUTPUT\n');
fprintf('Output average power      : %.6f W\n', Pout);
fprintf('Resistive-load estimate   : %.6f W\n', Pout_resistive);

if has_iout
    fprintf('Logged Iout average       : %.6f A\n', Iout_avg);
    fprintf('Logged Iout RMS           : %.6f A\n', Iout_rms);
    fprintf('Power-method difference   : %.6f %%\n', pout_method_difference);
else
    fprintf('Output-power method       : Vout^2/RL\n');
end

fprintf('Modeled efficiency        : %.6f %%\n', efficiency);
fprintf('\n');

fprintf('OUTPUT VOLTAGE\n');
fprintf('Average output voltage    : %.6f V\n', Vout_avg);
fprintf('RMS output voltage        : %.6f V\n', Vout_rms);
fprintf('Output ripple p-p         : %.6f V\n', Vout_ripple_pp);
fprintf('First-half Vout average   : %.6f V\n', Vout_first_half);
fprintf('Second-half Vout average  : %.6f V\n', Vout_second_half);
fprintf('Vout window drift         : %.6f V\n', Vout_window_drift);
fprintf('Average capacitor dE/dt   : %.6f W\n', Pcap_average);
fprintf('\n');

fprintf('REQUIREMENTS\n');
fprintf('PF > %.2f                  : %s\n', ...
    pf_requirement, pass_fail(PF > pf_requirement));
fprintf('Efficiency > %.1f %%       : %s\n', ...
    eff_requirement, pass_fail(efficiency > eff_requirement));
fprintf('\n');

%% Local helper functions
function [t, x] = crop_timeseries(ts, t_start, t_end)
    % Crop first so the script does not interpolate the entire simulation.
    cropped = getsampleusingtime(ts, t_start, t_end);

    t = double(cropped.Time(:));
    x = double(squeeze(cropped.Data));
    x = x(:);

    if numel(t) < 2
        error('A logged signal has fewer than two samples in the requested window.');
    end

    % interp1 requires a strictly increasing time vector.
    [t, unique_index] = unique(t, 'stable');
    x = x(unique_index);

    if numel(t) < 2
        error('A logged signal does not contain two unique time samples.');
    end
end

function result = pass_fail(condition)
    if condition
        result = 'PASS';
    else
        result = 'FAIL';
    end
end
