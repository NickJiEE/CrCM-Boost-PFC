%% pfc_component_stress_v6_flexible_steady_cases.m
% Component-stress verification for the CrCM boost PFC model.
%
% Run the Simulink model first, then run this script.
% Logged signals are expected in out.logsout or logsout.
%
% cfg.caseName options:
%   "startup" : startup analysis using cfg.startupWindow
%
%   Any string beginning with "steady_" uses cfg.steadyWindow.
%
% Important interpretation:
%   Startup RMS and average values over the full 0.25 s window are only
%   interval diagnostics. They are NOT continuous component ratings.
%   Startup component selection should use peak, pulse energy, I^2*t,
%   maximum voltage, and maximum reverse voltage.
%
% Statistics method:
%   Logged Simscape signals may contain irregular time steps and abrupt
%   switching transitions. Direct trapz integration can create artificial
%   triangular area across ideal switching edges. This script therefore:
%       1. removes duplicate timestamps while retaining the final value,
%       2. resamples on a uniform grid,
%       3. uses previous-value interpolation,
%       4. calculates mean, RMS, energy, and I^2*t from that grid.
%
% Charge-balance correction:
%   For settled operation, the average output-capacitor current must
%   agree with C*dV/dt. If logged switched-current edges create a small
%   DC-area error, the script removes only that inferred DC bias and
%   reports charge-balanced estimates for iCout and iBoostDiode. Peaks
%   remain the directly measured values. No new simulation is required.
%
% Required logged signals:
%   Iac, Iprecharge, Ibypass, Ibridge, iBridgeD1, iL, Isource,
%   iBoostDiode, iCout, iCx, Iout, Vac, Vac_bridge, Vout, Vds,
%   VBoostDiodeAK, VBridgeD1AK, OVP, OCP, BypassCmd, LoadCmd,
%   ControllerEnable, Ton_cmd_fast, GateCmd
%
% Bridge-diode approach:
%   One diode is used as the representative device because all four bridge
%   diodes are identical and symmetric in steady state. Ibridge is retained
%   so the worst bridge-path startup peak is still captured.

clearvars -except out logsout

%% User settings
% Use a descriptive steady-state name so each CSV is unique.
% Any name beginning with "steady_" is treated as a steady-state case.
cfg.caseName = "steady_264V_60Hz_full";

cfg.startupWindow = [0.0 0.5];
cfg.steadyWindow  = [4.8 5.0];

cfg.tBypass       = 0.200;
cfg.bypassWindow  = [0.195 0.210];

% Controller enable is 0.210 s and the startup pulse is at 0.211 s.
cfg.gateStartupWindow = [0.211 0.5];
% Excludes startup pulse, bypass transient, and load-connection transient.
cfg.postSequenceGateWindow = [0.230 0.5];

% Uniform statistics grid. Match this to the controller/electrical logging
% resolution. At 100 ns, a 0.2 s steady-state window contains 2e6 samples.
cfg.statsSampleTime   = 100e-9;  % s
cfg.controlSampleTime = 100e-9;  % s

cfg.Rprecharge    = 82;       % ohm
cfg.RfilterTotal  = 0.10;     % ohm, both 1 mH filter windings combined
cfg.RdsOn         = 0.30;     % ohm
cfg.Cout          = 220e-6;   % F
cfg.currentLimit  = 4.0;      % A, MOSFET on-state/OCP threshold
cfg.ovpThreshold  = 420;      % V

cfg.writeCSV      = true;
cfg.csvPrefix     = "pfc_component_stress";
% Output filenames include cfg.caseName, for example:
% pfc_component_stress_steady_120V_60Hz_full.csv

% Apply a DC charge-balance correction to settled switched currents.
% This is a post-processing estimate, not a replacement for a future
% synchronized measurement or direct ideal-capacitor voltage signal.
cfg.applyChargeBalanceCorrection = true;

%% Get logsout
if exist('out','var') && isa(out,'Simulink.SimulationOutput')
    try
        logs = out.logsout;
    catch
        error('The SimulationOutput object "out" does not contain logsout.');
    end
elseif exist('logsout','var')
    logs = logsout;
else
    error('No logged dataset found. Expected out.logsout or logsout.');
end

names = string(getElementNames(logs));

% Centralized case classification:
%   "startup" is the only startup case.
%   Any descriptive name beginning with "steady_" is steady state.
isStartupCase = cfg.caseName == "startup";
isSteadyCase  = startsWith(cfg.caseName,"steady_");

if ~(isStartupCase || isSteadyCase)
    error(['cfg.caseName must be "startup" or begin with "steady_". ' ...
        'Examples: "steady_120V_60Hz_full" or "steady_nominal".']);
end

if isStartupCase
    window = cfg.startupWindow;
    gateWindow = intersectWindow( ...
        cfg.startupWindow,cfg.gateStartupWindow);
    postGateWindow = intersectWindow( ...
        cfg.startupWindow,cfg.postSequenceGateWindow);
    contextLabel = "StartupTransient";
else
    window = cfg.steadyWindow;
    gateWindow = cfg.steadyWindow;
    postGateWindow = cfg.steadyWindow;
    contextLabel = "SteadyState";
end

fprintf('\nPFC component-stress verification\n');
fprintf('Case                       : %s\n',char(cfg.caseName));
fprintf('Main analysis interval     : %.6f s to %.6f s\n',window(1),window(2));
fprintf('Gate/timing interval       : %.6f s to %.6f s\n', ...
    gateWindow(1),gateWindow(2));
fprintf('Statistics sample time     : %.3f ns\n',cfg.statsSampleTime*1e9);

if isStartupCase
    fprintf('Post-sequence gate interval: %.6f s to %.6f s\n', ...
        postGateWindow(1),postGateWindow(2));
    fprintf(['NOTE: Startup interval RMS/average values are diagnostics only; ' ...
        'do not use them as continuous ratings.\n']);
end

%% Signals
currentSignals = [
    "Iac"
    "Iprecharge"
    "Ibypass"
    "Ibridge"
    "iBridgeD1"
    "iL"
    "Isource"
    "iBoostDiode"
    "iCout"
    "iCx"
    "Iout"
];

voltageSignals = [
    "Vac"
    "Vac_bridge"
    "Vout"
    "Vds"
    "VBoostDiodeAK"
    "VBridgeD1AK"
];

logicSignals = [
    "OVP"
    "OCP"
    "BypassCmd"
    "LoadCmd"
    "ControllerEnable"
];

rows = {};
correctionRows = {};

%% Current stress
fprintf('\nCURRENT STRESS\n');
fprintf('--------------------------------------------------------------------------\n');

for k = 1:numel(currentSignals)
    name = currentSignals(k);

    if ~hasSignal(names,name)
        fprintf('%-18s : not logged\n',char(name));
        continue;
    end

    [t,x] = readSignal(logs,name);
    [tw,xw] = selectWindow(t,x,window);
    s = signalStats(tw,xw,cfg.statsSampleTime);

    if isStartupCase
        [~,idxPeak] = max(abs(xw));
        fprintf('%-18s : abs peak = %9.5f A at %.9f s\n', ...
            char(name),s.absPeak,tw(idxPeak));
    else
        fprintf('%-18s : abs peak = %9.5f A | RMS = %9.5f A | avg = %9.5f A\n', ...
            char(name),s.absPeak,s.rms,s.avg);
    end

    rows(end+1,:) = {char(name),'Current',char(contextLabel), ...
        window(1),window(2),s.max,s.min,s.absPeak,s.rms,s.avg,s.p2p}; %#ok<SAGROW>
end

%% Voltage stress
fprintf('\nVOLTAGE STRESS\n');
fprintf('--------------------------------------------------------------------------\n');

for k = 1:numel(voltageSignals)
    name = voltageSignals(k);

    if ~hasSignal(names,name)
        fprintf('%-18s : not logged\n',char(name));
        continue;
    end

    [t,x] = readSignal(logs,name);
    [tw,xw] = selectWindow(t,x,window);
    s = signalStats(tw,xw,cfg.statsSampleTime);

    if isStartupCase
        [~,idxMax] = max(xw);
        [~,idxMin] = min(xw);

        fprintf('%-18s : max = %10.5f V at %.9f s | min = %10.5f V at %.9f s\n', ...
            char(name),s.max,tw(idxMax),s.min,tw(idxMin));
    else
        fprintf('%-18s : max = %10.5f V | min = %10.5f V | p-p = %9.5f V\n', ...
            char(name),s.max,s.min,s.p2p);
    end

    rows(end+1,:) = {char(name),'Voltage',char(contextLabel), ...
        window(1),window(2),s.max,s.min,s.absPeak,s.rms,s.avg,s.p2p}; %#ok<SAGROW>
end

%% Protection and sequencing
fprintf('\nPROTECTION AND SEQUENCING\n');
fprintf('--------------------------------------------------------------------------\n');

for k = 1:numel(logicSignals)
    name = logicSignals(k);

    if ~hasSignal(names,name)
        fprintf('%-18s : not logged\n',char(name));
        continue;
    end

    [t,x] = readSignal(logs,name);
    [tw,xw] = selectWindow(t,x,window);

    active = xw > 0.5;
    trise = firstRise(tw,active);

    if isnan(trise)
        fprintf('%-18s : max = %.3f | no rising edge in window\n', ...
            char(name),max(xw));
    else
        fprintf('%-18s : max = %.3f | first rise = %.9f s\n', ...
            char(name),max(xw),trise);
    end
end

%% Startup-specific checks
if isStartupCase
    fprintf('\nSTARTUP-SPECIFIC STRESS\n');
    fprintf('--------------------------------------------------------------------------\n');

    % Precharge resistor:
    % If Iprecharge is logged directly, integrate the full startup window.
    % Also report energy accumulated before the bypass command.
    if hasSignal(names,"Iprecharge")
        [tR,iR] = readSignal(logs,"Iprecharge");

        [trTotal,irTotal] = selectWindow(tR,iR,window);
        preWindow = [window(1),min(cfg.tBypass,window(2))];
        [trPre,irPre] = selectWindow(tR,iR,preWindow);

        [prePeak,idxPeak] = max(abs(irTotal));

        energyBeforeBypass = cfg.Rprecharge * ...
            zohIntegral(trPre,irPre.^2,cfg.statsSampleTime);
        totalStartupEnergy = cfg.Rprecharge * ...
            zohIntegral(trTotal,irTotal.^2,cfg.statsSampleTime);
        prechargeI2t = zohIntegral( ...
            trTotal,irTotal.^2,cfg.statsSampleTime);

        fprintf('Precharge source             : Iprecharge\n');
        fprintf('Precharge current peak       : %.6f A at %.9f s\n', ...
            prePeak,trTotal(idxPeak));
        fprintf('Precharge power peak         : %.3f W\n', ...
            prePeak^2*cfg.Rprecharge);
        fprintf('Energy before bypass         : %.6f J\n',energyBeforeBypass);
        fprintf('Total observed startup energy: %.6f J\n',totalStartupEnergy);
        fprintf('Precharge current I^2*t      : %.6f A^2*s\n',prechargeI2t);

    elseif hasSignal(names,"Iac")
        [tR,iR] = readSignal(logs,"Iac");
        preWindow = [window(1),min(cfg.tBypass,window(2))];
        [trPre,irPre] = selectWindow(tR,iR,preWindow);

        [prePeak,idxPeak] = max(abs(irPre));

        estimatedEnergy = cfg.Rprecharge * ...
            zohIntegral(trPre,irPre.^2,cfg.statsSampleTime);
        estimatedI2t = zohIntegral( ...
            trPre,irPre.^2,cfg.statsSampleTime);

        fprintf('Precharge source             : Iac estimate before bypass\n');
        fprintf('Precharge current peak       : %.6f A at %.9f s\n', ...
            prePeak,trPre(idxPeak));
        fprintf('Precharge power peak         : %.3f W\n', ...
            prePeak^2*cfg.Rprecharge);
        fprintf('Estimated energy before bypass: %.6f J\n',estimatedEnergy);
        fprintf('Estimated current I^2*t      : %.6f A^2*s\n',estimatedI2t);
        warning('Iprecharge not logged. Total post-bypass resistor energy is unavailable.');
    else
        fprintf('Precharge current            : not logged and cannot be estimated\n');
    end

    % Bypass-switch event.
    if hasSignal(names,"Ibypass")
        [tb,ib] = readSignal(logs,"Ibypass");
        bypassLabel = "Ibypass";
    elseif hasSignal(names,"Iac")
        [tb,ib] = readSignal(logs,"Iac");
        bypassLabel = "Iac approximation";
        warning('Ibypass not logged. Using Iac near the bypass event.');
    else
        tb = [];
        ib = [];
        bypassLabel = "";
    end

    if ~isempty(tb)
        [tbw,ibw] = selectWindow(tb,ib,cfg.bypassWindow);
        [bypassPeak,kp] = max(abs(ibw));
        bypassI2t = zohIntegral(tbw,ibw.^2,cfg.statsSampleTime);

        fprintf('Bypass current source        : %s\n',char(bypassLabel));
        fprintf('Bypass-event peak            : %.6f A\n',bypassPeak);
        fprintf('Bypass-event peak time       : %.9f s\n',tbw(kp));
        fprintf('Bypass-window current I^2*t  : %.6f A^2*s\n',bypassI2t);
    end

    % Output overvoltage margin.
    if hasSignal(names,"Vout")
        [t,v] = readSignal(logs,"Vout");
        [tw,vw] = selectWindow(t,v,window);

        [voutMax,kp] = max(vw);
        ovpMargin = cfg.ovpThreshold-voutMax;

        fprintf('Vout startup maximum         : %.6f V at %.9f s\n', ...
            voutMax,tw(kp));
        fprintf('OVP margin                   : %.6f V\n',ovpMargin);

        if ovpMargin < 0
            warning('Vout exceeded the configured OVP threshold.');
        end
    end

    % Boost-inductor peak is a magnetic saturation check, not an OCP check.
    if hasSignal(names,"iL")
        [t,i] = readSignal(logs,"iL");
        [tw,iw] = selectWindow(t,i,window);

        [iLPeak,kp] = max(abs(iw));

        fprintf('Boost-inductor startup peak  : %.6f A at %.9f s\n', ...
            iLPeak,tw(kp));
        fprintf('Compare this with the inductor saturation-current rating.\n');
    end

    % OCP protects controlled MOSFET on-state current.
    if hasSignal(names,"Isource")
        [t,i] = readSignal(logs,"Isource");
        [tw,iw] = selectWindow(t,i,window);

        [mosfetPeak,kp] = max(abs(iw));
        ocpMargin = cfg.currentLimit-mosfetPeak;

        fprintf('MOSFET startup current peak  : %.6f A at %.9f s\n', ...
            mosfetPeak,tw(kp));
        fprintf('OCP current margin           : %.6f A\n',ocpMargin);

        if ocpMargin < 0
            warning('MOSFET branch current exceeded the configured current limit.');
        end
    else
        fprintf('Isource                      : not logged; OCP margin not calculated\n');
    end

    % Time-aligned bridge-side overshoot relative to the source.
    if hasSignal(names,"Vac") && hasSignal(names,"Vac_bridge")
        [tSrc,vSrc] = readSignal(logs,"Vac");
        [tBr,vBr] = readSignal(logs,"Vac_bridge");

        commonWindow = [
            max([window(1),tSrc(1),tBr(1)]), ...
            min([window(2),tSrc(end),tBr(end)])
        ];

        [tBrW,vBrW] = selectWindow(tBr,vBr,commonWindow);
        vSrcAtBridgeTime = interp1(tSrc,vSrc,tBrW,'linear');

        deltaAbs = abs(vBrW)-abs(vSrcAtBridgeTime);
        [alignedOvershoot,kp] = max(deltaAbs);

        fprintf('Time-aligned bridge overshoot: %.6f V at %.9f s\n', ...
            alignedOvershoot,tBrW(kp));
        fprintf('Source voltage at that time : %.6f V\n',vSrcAtBridgeTime(kp));
        fprintf('Bridge voltage at that time : %.6f V\n',vBrW(kp));
    end
end

%% Representative bridge-diode stress
fprintf('\nREPRESENTATIVE BRIDGE-DIODE STRESS\n');
fprintf('--------------------------------------------------------------------------\n');

if hasSignal(names,"iBridgeD1")
    [t,i] = readSignal(logs,"iBridgeD1");
    [tw,iw] = selectWindow(t,i,window);
    sD1 = signalStats(tw,iw,cfg.statsSampleTime);

    [d1Peak,kp] = max(iw);

    fprintf('D1 forward-current peak      : %.6f A at %.9f s\n', ...
        d1Peak,tw(kp));

    if isStartupCase
        fprintf('D1 startup current I^2*t     : %.6f A^2*s\n', ...
            zohIntegral(tw,iw.^2,cfg.statsSampleTime));
        fprintf('D1 RMS/average are intentionally omitted for startup.\n');
    else
        fprintf('D1 RMS current               : %.6f A\n',sD1.rms);
        fprintf('D1 average current           : %.6f A\n',sD1.avg);
    end
else
    fprintf('iBridgeD1                    : not logged\n');
end

if hasSignal(names,"Ibridge")
    [t,i] = readSignal(logs,"Ibridge");
    [tw,iw] = selectWindow(t,i,window);

    [bridgePathPeak,kp] = max(abs(iw));
    fprintf('Worst bridge-path peak       : %.6f A at %.9f s\n', ...
        bridgePathPeak,tw(kp));

    if isSteadyCase
        bridgeStats = signalStats(tw,iw,cfg.statsSampleTime);
        absBridgeStats = signalStats(tw,abs(iw),cfg.statsSampleTime);

        fprintf('Estimated per-diode RMS      : %.6f A\n', ...
            bridgeStats.rms/sqrt(2));
        fprintf('Estimated per-diode average  : %.6f A\n', ...
            absBridgeStats.avg/2);
    end
else
    fprintf('Ibridge                      : not logged\n');
end

if hasSignal(names,"VBridgeD1AK")
    [t,v] = readSignal(logs,"VBridgeD1AK");
    [tw,vw] = selectWindow(t,v,window);

    [minV,kpRev] = min(vw);
    [maxV,kpFwd] = max(vw);
    reverseVoltage = max(0,-minV);

    fprintf('D1 maximum reverse voltage   : %.6f V at %.9f s\n', ...
        reverseVoltage,tw(kpRev));
    fprintf('D1 maximum forward drop      : %.6f V at %.9f s\n', ...
        maxV,tw(kpFwd));
else
    fprintf('VBridgeD1AK                  : not logged\n');
end

%% Boost-diode voltage stress
fprintf('\nBOOST-DIODE VOLTAGE STRESS\n');
fprintf('--------------------------------------------------------------------------\n');

if hasSignal(names,"VBoostDiodeAK")
    [t,v] = readSignal(logs,"VBoostDiodeAK");
    [tw,vw] = selectWindow(t,v,window);

    [minV,kpRev] = min(vw);
    [maxV,kpFwd] = max(vw);
    reverseVoltage = max(0,-minV);

    fprintf('Maximum reverse voltage      : %.6f V at %.9f s\n', ...
        reverseVoltage,tw(kpRev));
    fprintf('Maximum forward drop         : %.6f V at %.9f s\n', ...
        maxV,tw(kpFwd));
else
    fprintf('VBoostDiodeAK                : not logged\n');
end

%% Steady-state estimates
if isSteadyCase
    fprintf('\nSTEADY-STATE ESTIMATES\n');
    fprintf('--------------------------------------------------------------------------\n');

    if hasSignal(names,"Iac")
        [t,i] = readSignal(logs,"Iac");
        [tw,iw] = selectWindow(t,i,window);
        s = signalStats(tw,iw,cfg.statsSampleTime);

        pFilterCopper = s.rms^2 * cfg.RfilterTotal;
        fprintf('EMI winding copper loss estimate : %.6f W\n',pFilterCopper);
    end

    if hasSignal(names,"Isource")
        [t,i] = readSignal(logs,"Isource");
        [tw,iw] = selectWindow(t,i,window);
        s = signalStats(tw,iw,cfg.statsSampleTime);

        pMosfetConduction = s.rms^2 * cfg.RdsOn;
        fprintf('MOSFET conduction loss estimate  : %.6f W\n',pMosfetConduction);
        fprintf('This excludes switching and gate-drive loss.\n');
    end
end

%% Charge-balanced current estimates
% This section corrects only the inferred DC-area bias of settled switched
% currents. Directly measured peaks are not changed.
if cfg.applyChargeBalanceCorrection && ...
        isSteadyCase && ...
        hasSignal(names,"iCout")

    % Prefer the internal ideal-capacitor voltage if it is available.
    % Otherwise use Vout as an approximation. Vout includes ESR voltage.
    if hasSignal(names,"VcapIdeal")
        capacitorVoltageSignal = "VcapIdeal";
    elseif hasSignal(names,"Vout")
        capacitorVoltageSignal = "Vout";
    else
        capacitorVoltageSignal = "";
    end

    if strlength(capacitorVoltageSignal) > 0
        [ti,ic] = readSignal(logs,"iCout");
        [tiw,icw] = selectWindow(ti,ic,window);
        [~,icUniform,~] = uniformPreviousSamples( ...
            tiw,icw,cfg.statsSampleTime);

        rawCapAverage = mean(icUniform);
        rawCapRMS = sqrt(mean(icUniform.^2));
        rawCapRippleRMS = sqrt(mean((icUniform-rawCapAverage).^2));

        [tv,vc] = readSignal(logs,capacitorVoltageSignal);
        [tvw,vcw] = selectWindow(tv,vc,window);

        voltageDuration = tvw(end)-tvw(1);
        expectedCapAverage = ...
            cfg.Cout*(vcw(end)-vcw(1))/voltageDuration;

        capDCBias = rawCapAverage-expectedCapAverage;
        icCorrected = icUniform-capDCBias;

        correctedCapAverage = mean(icCorrected);
        correctedCapRMS = sqrt(mean(icCorrected.^2));
        correctedCapRippleRMS = sqrt( ...
            mean((icCorrected-correctedCapAverage).^2));

        fprintf('\nCHARGE-BALANCED CURRENT ESTIMATES\n');
        fprintf('--------------------------------------------------------------------------\n');
        fprintf('Capacitor voltage signal     : %s\n', ...
            char(capacitorVoltageSignal));
        fprintf('Raw iCout average            : %.9f A\n',rawCapAverage);
        fprintf('Expected iCout average C*dV/dt: %.9f A\n', ...
            expectedCapAverage);
        fprintf('Inferred iCout DC-area bias  : %.9f A\n',capDCBias);
        fprintf('Corrected iCout average      : %.9f A\n', ...
            correctedCapAverage);
        fprintf('Raw iCout RMS                : %.9f A\n',rawCapRMS);
        fprintf('Corrected iCout RMS          : %.9f A\n',correctedCapRMS);
        fprintf('iCout ripple RMS             : %.9f A\n', ...
            correctedCapRippleRMS);
        fprintf('Raw ripple RMS               : %.9f A\n',rawCapRippleRMS);
        fprintf(['The correction removes only the inferred DC bias; ' ...
            'the measured current peaks remain unchanged.\n']);

        correctionRows(end+1,:) = { ...
            'iCout','Capacitor charge balance', ...
            rawCapAverage,expectedCapAverage,capDCBias, ...
            rawCapRMS,correctedCapRMS,correctedCapRippleRMS}; %#ok<SAGROW>

        % Charge-balanced boost-diode average:
        % In settled operation, iBoostDiode_avg = Iout_avg + iCout_avg.
        if hasSignal(names,"iBoostDiode") && hasSignal(names,"Iout")
            [td,id] = readSignal(logs,"iBoostDiode");
            [tdw,idw] = selectWindow(td,id,window);
            [~,idUniform,~] = uniformPreviousSamples( ...
                tdw,idw,cfg.statsSampleTime);

            [to,io] = readSignal(logs,"Iout");
            [tow,iow] = selectWindow(to,io,window);
            ioutStats = signalStats(tow,iow,cfg.statsSampleTime);

            rawDiodeAverage = mean(idUniform);
            rawDiodeRMS = sqrt(mean(idUniform.^2));

            targetDiodeAverage = ioutStats.avg+expectedCapAverage;
            diodeDCBias = rawDiodeAverage-targetDiodeAverage;
            idCorrected = idUniform-diodeDCBias;

            correctedDiodeAverage = mean(idCorrected);
            correctedDiodeRMS = sqrt(mean(idCorrected.^2));
            correctedDiodeRippleRMS = sqrt( ...
                mean((idCorrected-correctedDiodeAverage).^2));

            fprintf('\nBoost-diode charge balance\n');
            fprintf('Raw iBoostDiode average      : %.9f A\n', ...
                rawDiodeAverage);
            fprintf('Iout average                 : %.9f A\n',ioutStats.avg);
            fprintf('Charge-balanced diode average: %.9f A\n', ...
                targetDiodeAverage);
            fprintf('Inferred diode DC-area bias  : %.9f A\n', ...
                diodeDCBias);
            fprintf('Corrected diode average      : %.9f A\n', ...
                correctedDiodeAverage);
            fprintf('Raw boost-diode RMS          : %.9f A\n', ...
                rawDiodeRMS);
            fprintf('Corrected boost-diode RMS    : %.9f A\n', ...
                correctedDiodeRMS);
            fprintf('Boost-diode ripple RMS       : %.9f A\n', ...
                correctedDiodeRippleRMS);

            correctionRows(end+1,:) = { ...
                'iBoostDiode','Output-stage charge balance', ...
                rawDiodeAverage,targetDiodeAverage,diodeDCBias, ...
                rawDiodeRMS,correctedDiodeRMS, ...
                correctedDiodeRippleRMS}; %#ok<SAGROW>
        else
            fprintf('\niBoostDiode or Iout is not logged; diode correction skipped.\n');
        end

        if capacitorVoltageSignal == "Vout"
            fprintf(['\nCaution: Vout includes capacitor ESR voltage. Because the ' ...
                'steady-state window contains an integer number of line ' ...
                'cycles, this is normally a useful approximation, but ' ...
                'VcapIdeal would be preferable if logged in a future run.\n']);
        end
    else
        fprintf('\nCHARGE-BALANCED CURRENT ESTIMATES\n');
        fprintf('--------------------------------------------------------------------------\n');
        fprintf('Neither VcapIdeal nor Vout is logged; correction skipped.\n');
    end
end

%% Gate and timing
fprintf('\nGATE AND TIMING\n');
fprintf('--------------------------------------------------------------------------\n');
fprintf('Active timing interval      : %.6f s to %.6f s\n', ...
    gateWindow(1),gateWindow(2));

if hasSignal(names,"Ton_cmd_fast")
    reportTonStats(logs,"Ton_cmd_fast",gateWindow, ...
        'Active-window Ton command',cfg.statsSampleTime);

    if isStartupCase && any(postGateWindow ~= gateWindow)
        reportTonStats(logs,"Ton_cmd_fast",postGateWindow, ...
            'Post-sequence Ton command',cfg.statsSampleTime);
    end
else
    fprintf('Ton_cmd_fast                : not logged\n');
end

if hasSignal(names,"GateCmd")
    reportGateStats(logs,"GateCmd",gateWindow, ...
        'Active-window gate pulses',cfg.controlSampleTime);

    if isStartupCase && any(postGateWindow ~= gateWindow)
        reportGateStats(logs,"GateCmd",postGateWindow, ...
            'Post-sequence gate pulses',cfg.controlSampleTime);
    end
else
    fprintf('GateCmd                     : not logged\n');
end

%% Save CSV
if ~isempty(rows)
    results = cell2table(rows,'VariableNames', ...
        {'Signal','Type','Context','WindowStart_s','WindowEnd_s', ...
         'Maximum','Minimum','AbsolutePeak','IntervalRMS', ...
         'IntervalAverage','Range'});

    disp(' ');
    disp(results);

    if cfg.writeCSV
        fileName = sprintf('%s_%s.csv',cfg.csvPrefix,char(cfg.caseName));
        writetable(results,fileName);
        fprintf('\nSaved summary table to %s\n',fileName);
    end
end

%% Save charge-balance correction CSV
if ~isempty(correctionRows)
    correctedResults = cell2table(correctionRows,'VariableNames', ...
        {'Signal','CorrectionMethod','RawAverage_A','TargetAverage_A', ...
         'RemovedDCBias_A','RawRMS_A','CorrectedRMS_A','RippleRMS_A'});

    fprintf('\nCharge-balance correction summary\n');
    disp(correctedResults);

    if cfg.writeCSV
        correctionFileName = sprintf('%s_%s_charge_balanced.csv', ...
            cfg.csvPrefix,char(cfg.caseName));
        writetable(correctedResults,correctionFileName);
        fprintf('Saved charge-balance table to %s\n',correctionFileName);
    end
end

fprintf('\nVerification complete.\n');

%% Local functions
function tf = hasSignal(names,name)
    tf = any(names == string(name));
end

function [t,x] = readSignal(logs,name)
    element = logs.get(char(name));
    ts = element.Values;

    t = double(ts.Time(:));
    x = double(squeeze(ts.Data));
    x = x(:);

    if numel(t) ~= numel(x)
        error('Signal %s is not scalar or has incompatible dimensions.',char(name));
    end

    valid = isfinite(t) & isfinite(x);
    t = t(valid);
    x = x(valid);

    if numel(t) < 2
        error('Signal %s does not contain enough valid samples.',char(name));
    end
end

function [tw,xw] = selectWindow(t,x,window)
    idx = t >= window(1) & t <= window(2);

    tw = t(idx);
    xw = x(idx);

    if numel(tw) < 2 || tw(end) <= tw(1)
        error('Not enough samples between %.9f s and %.9f s.', ...
            window(1),window(2));
    end
end

function w = intersectWindow(a,b)
    w = [max(a(1),b(1)),min(a(2),b(2))];

    if w(2) <= w(1)
        error('The requested analysis windows do not overlap.');
    end
end

function s = signalStats(t,x,Ts)
    % Peaks are taken directly from the original logged samples.
    s.max = max(x);
    s.min = min(x);
    s.absPeak = max(abs(x));
    s.p2p = s.max-s.min;

    [~,xu,dt] = uniformPreviousSamples(t,x,Ts);

    if isempty(xu)
        error('Uniform statistics grid contains no samples.');
    end

    s.avg = mean(xu);
    s.rms = sqrt(mean(xu.^2));
    s.sampledDuration = numel(xu)*dt;
end

function value = zohIntegral(t,x,Ts)
    [~,xu,dt] = uniformPreviousSamples(t,x,Ts);

    if isempty(xu)
        error('Uniform integration grid contains no samples.');
    end

    value = sum(xu)*dt;
end

function [tu,xu,dt] = uniformPreviousSamples(t,x,Ts)
    % Remove duplicate timestamps and retain the final value at each time.
    [tUnique,idx] = unique(t,'last');
    xUnique = x(idx);

    if numel(tUnique) < 2
        error('Signal does not contain enough unique timestamps.');
    end

    duration = tUnique(end)-tUnique(1);

    if duration <= 0
        error('Signal window has zero duration.');
    end

    if ~isscalar(Ts) || ~isfinite(Ts) || Ts <= 0
        error('Statistics sample time must be a positive finite scalar.');
    end

    numberOfSamples = floor(duration/Ts);

    if numberOfSamples < 2
        error(['Analysis window is too short for the selected statistics ' ...
            'sample time.']);
    end

    dt = Ts;
    tu = tUnique(1)+(0:numberOfSamples-1)'*dt;

    % Previous-value interpolation preserves abrupt switching transitions
    % instead of creating artificial triangular ramps.
    xu = interp1(tUnique,xUnique,tu,'previous','extrap');
end

function trise = firstRise(t,state)
    idx = find(diff(state)>0,1,'first')+1;

    if isempty(idx)
        trise = NaN;
    else
        trise = t(idx);
    end
end

function reportTonStats(logs,name,window,label,statsSampleTime)
    [t,ton] = readSignal(logs,name);
    [tw,tonw] = selectWindow(t,ton,window);
    s = signalStats(tw,tonw,statsSampleTime);

    fprintf('%s\n',label);
    fprintf('  interval                    : %.6f s to %.6f s\n', ...
        window(1),window(2));
    fprintf('  minimum                     : %.6f us\n',min(tonw)*1e6);
    fprintf('  maximum                     : %.6f us\n',max(tonw)*1e6);
    fprintf('  previous-value time average : %.6f us\n',s.avg*1e6);
end

function reportGateStats(logs,name,window,label,controlSampleTime)
    [t,g] = readSignal(logs,name);
    [tw,gw] = selectWindow(t,g,window);
    gs = gateStats(tw,gw);

    fprintf('%s\n',label);
    fprintf('  interval                    : %.6f s to %.6f s\n', ...
        window(1),window(2));

    if gs.numPulses >= 2
        fprintf('  pulses analyzed             : %d\n',gs.numPulses);
        fprintf('  pulse width min/avg/max     : %.6f / %.6f / %.6f us\n', ...
            gs.pwMin*1e6,gs.pwAvg*1e6,gs.pwMax*1e6);
        fprintf('  switching freq min/avg/max  : %.3f / %.3f / %.3f kHz\n', ...
            gs.fMin/1e3,gs.fAvg/1e3,gs.fMax/1e3);
        fprintf('  pulse-width resolution      : approximately %.3f us\n', ...
            controlSampleTime*1e6);
        fprintf('  average frequency uses pulse count divided by elapsed time.\n');
    else
        fprintf('  not enough gate pulses found in this interval.\n');
    end
end

function s = gateStats(t,g)
    s = struct( ...
        'numPulses',0, ...
        'pwMin',NaN,'pwAvg',NaN,'pwMax',NaN, ...
        'fMin',NaN,'fAvg',NaN,'fMax',NaN);

    if max(g) <= min(g)
        return;
    end

    threshold = 0.5*(min(g)+max(g));
    state = g > threshold;

    riseIdx = find(diff(state)==1)+1;
    fallIdx = find(diff(state)==-1)+1;

    widths = [];

    for k = 1:numel(riseIdx)
        nextFall = fallIdx(find(fallIdx>riseIdx(k),1,'first')); %#ok<FNDSB>

        if ~isempty(nextFall)
            widths(end+1,1) = t(nextFall)-t(riseIdx(k)); %#ok<AGROW>
        end
    end

    riseTimes = t(riseIdx);

    if numel(riseTimes) >= 2
        periods = diff(riseTimes);
        periods = periods(periods>0);
        freq = 1./periods;
    else
        freq = [];
    end

    s.numPulses = numel(widths);

    if ~isempty(widths)
        s.pwMin = min(widths);
        s.pwAvg = mean(widths);
        s.pwMax = max(widths);
    end

    if ~isempty(freq)
        s.fMin = min(freq);
        s.fMax = max(freq);

        elapsed = riseTimes(end)-riseTimes(1);
        if elapsed > 0
            s.fAvg = (numel(riseTimes)-1)/elapsed;
        end
    end
end
