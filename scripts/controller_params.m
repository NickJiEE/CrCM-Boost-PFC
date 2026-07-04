% ZCD/Timer
Ts_ctrl = 100e-9;       % 100 ns controller sample time

Izcd    = 0.02;         % ZCD threshold [A]
Ilimit  = 4.0;          % cycle-by-cycle current limit [A]
Vovp    = 420;          % output overvoltage protection [V]

Vgate   = 10;           % commanded gate voltage [V]
Tstart  = 0.211;        % initial startup pulse time [s]

% Voltage Loop
Vref      = 400;
Ts_v    = 100e-6;       % voltage loop: 10 kHz update rate

fc_vout = 20;           % Vout measurement-filter cutoff [Hz]
alpha = exp(-2*pi*fc_vout*Ts_v);

Kp = 0.05e-6;           % seconds per volt
Ki = 2e-7;              % 1/volt

Ton_min = 0.2e-6;
Ton_max = 8.0e-6;
Ton_startup_max = 7.5e-6;

% Ton_I_min = -1.0e-6;
% Ton_I_max =  1.0e-6;

% Dynamic Ton Limit
% Ton_I_min = -Ton_ff - Ton_P;
% Ton_I_max = Ton_upper - Ton_ff - Ton_P;

K_Ton_max = 1.25;

% Input-voltage feedforward reference point
Favg          = 20;          % 1/20 Hz = 50 ms window
Vin_rms       = 90;          % actual AC source RMS voltage [V]
Vin_peak      = Vin_rms*sqrt(2);

Vin_nom       = 90;          % voltage where Ton_nom was calibrated [V RMS]
Ton_nom       = 7.1e-6;      % calibrated on-time at Vin_nom [s]

Kff           = Ton_nom*Vin_nom^2;

Vin_ff_min    = 80;          % prevents division by a very small value
Vin_ff_max    = 280;

% Frequency clamp
Fsw_max = 500e3;
Tcycle_min = 1/Fsw_max;

Ncycle_min = ceil(Tcycle_min/Ts_ctrl);
Tcycle_actual = Ncycle_min*Ts_ctrl;
Fsw_actual_max = 1/Tcycle_actual;
