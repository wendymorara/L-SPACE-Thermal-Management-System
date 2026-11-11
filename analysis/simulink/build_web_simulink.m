function mdl = build_web_simulink(P, R, mdl)
%BUILD_WEB_SIMULINK  Programmatically build the WEB thermal model in Simulink.
%
%   mdl = build_web_simulink(P, R)
%   mdl = build_web_simulink(P, R, 'my_model_name')
%
%     P  parameters from thermal_params()
%     R  a result from simulate_web(): supplies geometry, option values and
%        the boundary-condition time series (air, sky, ground, solar,
%        internal load, heater mode), so both models see identical inputs
%
%   The Simulink model solves the same two-node network as simulate_web.m
%   but independently: a variable-step stiff solver (ode23t) with
%   zero-crossing detection replaces the fixed-step Euler loop, and a pair of
%   Relay blocks replaces the hand-coded heater thermostat.
%
%   Block diagram
%     From Workspace (T_air, T_sky, T_gnd, Q_sol, Q_int, mode)
%       -> Fcn "dH/dt"   -> Integrator "H"   -> Lookup "T(H)"  = T_int
%       -> Fcn "dTs/dt"  -> Integrator "T_s"                   = T_skin
%     T_int -> Gain(-1) -> Relay "operating band" --+
%                       -> Relay "survival band"  --+-> Switch (mode) = Q_htr
%
%   Requires MATLAB R2021b or newer with Simulink (no Simscape).

if nargin < 3, mdl = 'web_thermal_model'; end
o = R.opts;  g = R.g;
eps_ = P.coat.options{o.coat_idx, 3};
sig  = P.sigma;
h    = R.E.h;

% ---- workspace data for the From Workspace blocks ---------------------
t = R.t;
mode = double(R.T_on > P.htr.surv_on_K + 1);       % 1 = operating band commanded
assignin('base', 'sl_Tair', [t R.env.T_air]);
assignin('base', 'sl_Tsky', [t R.env.T_sky]);
assignin('base', 'sl_Tgnd', [t R.env.T_gnd]);
assignin('base', 'sl_Qsol', [t R.env.Q_sol]);
assignin('base', 'sl_Qint', [t R.Q_int]);
assignin('base', 'sl_mode', [t mode]);

% ---- enthalpy -> temperature table (exact piecewise-linear PCM model) -
Tm = P.pcm.Tm;  C = R.C_I;  Lat = R.Lat;  span = 400;     % +/-400 K covers any case
if Lat > 0
    bp  = [-C*span, 0, Lat, Lat + C*span];
    tab = [Tm - span, Tm, Tm, Tm + span];
else
    bp  = [-C*span, 0, C*span];
    tab = [Tm - span, Tm, Tm + span];
end
T0 = o.T0;
if T0 >= Tm, H0 = Lat + C*(T0 - Tm); else, H0 = C*(T0 - Tm); end

% ---- new model ---------------------------------------------------------
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
set_param(mdl, 'StopTime', num2str(t(end)), 'Solver', 'ode23t', ...
    'MaxStep', '10', 'RelTol', '1e-6', 'AbsTol', '1e-6', ...
    'ReturnWorkspaceOutputs', 'on');

% layout helper: column c, row r -> [left top right bottom]
pos = @(c, r, w, ht) [40 + 170*c, 40 + 70*r, 40 + 170*c + w, 40 + 70*r + ht];

% boundary-condition sources
src = {'Tair','sl_Tair'; 'Tsky','sl_Tsky'; 'Tgnd','sl_Tgnd'; ...
       'Qsol','sl_Qsol'; 'Qint','sl_Qint'; 'Mode','sl_mode'};
for k = 1:size(src,1)
    add_block('simulink/Sources/From Workspace', [mdl '/' src{k,1}], ...
        'VariableName', src{k,2}, 'Interpolate', 'on', ...
        'OutputAfterFinalValue', 'Holding final value', 'Position', pos(0, k-1, 90, 30));
end

% interior node: dH/dt = Q_int + Q_htr - G_ins (T_I - T_S) - G_leak (T_I - T_air)
%   mux order: u(1) Q_int, u(2) Q_htr, u(3) T_I, u(4) T_S, u(5) T_air
add_block('simulink/Signal Routing/Mux', [mdl '/MuxH'], 'Inputs', '5', 'Position', pos(2, 0, 8, 200));
add_fcn([mdl '/dHdt'], sprintf('u(1)+u(2)-%.10g*(u(3)-u(4))-%.10g*(u(3)-u(5))', ...
    g.G_ins, P.leak.G), pos(3, 1, 180, 40));
add_block('simulink/Continuous/Integrator', [mdl '/H'], ...
    'InitialCondition', sprintf('%.10g', H0), 'Position', pos(4.4, 1, 40, 40));
add_block('simulink/Lookup Tables/1-D Lookup Table', [mdl '/T_of_H'], ...
    'Table', mat2str(tab, 12), 'BreakpointsForDimension1', mat2str(bp, 12), ...
    'ExtrapMethod', 'Linear', 'Position', pos(5.2, 1, 60, 40));

% skin node: C_S dT_S/dt = G(T_I - T_S) + Q_sol - eps sig [A_sky(T_S^4 - T_sky^4)
%                          + A_gnd(T_S^4 - T_gnd^4)] - h A (T_S - T_air)
%   mux order: u(1) T_I, u(2) T_S, u(3) T_air, u(4) T_sky, u(5) T_gnd, u(6) Q_sol
add_block('simulink/Signal Routing/Mux', [mdl '/MuxS'], 'Inputs', '6', 'Position', pos(2, 4, 8, 240));
add_fcn([mdl '/dTsdt'], sprintf(['(%.10g*(u(1)-u(2))+u(6)-%.10g*(%.10g*(u(2)^4-u(4)^4)' ...
    '+%.10g*(u(2)^4-u(5)^4))-%.10g*(u(2)-u(3)))/%.10g'], ...
    g.G_ins, eps_*sig, g.A_sky, g.A_gnd, h*g.A_out, g.C_skin), pos(3, 5.5, 180, 40));
add_block('simulink/Continuous/Integrator', [mdl '/T_S'], ...
    'InitialCondition', sprintf('%.10g', T0 - 40), 'Position', pos(4.4, 5.5, 40, 40));

% heater: two relays on -T_I (Relay turns ON when input >= OnSwitchValue)
add_block('simulink/Math Operations/Gain', [mdl '/Negate'], 'Gain', '-1', 'Position', pos(6, 2.5, 40, 30));
add_block('simulink/Discontinuities/Relay', [mdl '/RelayOperating'], ...
    'OnSwitchValue',  sprintf('%.10g', -P.htr.on_K), ...
    'OffSwitchValue', sprintf('%.10g', -P.htr.off_K), ...
    'OnOutputValue',  sprintf('%.10g', o.P_htr), 'OffOutputValue', '0', ...
    'Position', pos(7, 2, 50, 30));
add_block('simulink/Discontinuities/Relay', [mdl '/RelaySurvival'], ...
    'OnSwitchValue',  sprintf('%.10g', -P.htr.surv_on_K), ...
    'OffSwitchValue', sprintf('%.10g', -P.htr.surv_off_K), ...
    'OnOutputValue',  sprintf('%.10g', o.P_htr), 'OffOutputValue', '0', ...
    'Position', pos(7, 3.2, 50, 30));
add_block('simulink/Signal Routing/Switch', [mdl '/ModeSwitch'], ...
    'Criteria', 'u2 > Threshold', 'Threshold', '0.5', 'Position', pos(8, 2.4, 40, 60));

% logging
logs = {'log_TI','T_I',6.2,0.2; 'log_TS','T_S',6.2,6.5; 'log_Qhtr','Q_htr',9,2.6};
for k = 1:size(logs,1)
    add_block('simulink/Sinks/To Workspace', [mdl '/' logs{k,1}], ...
        'VariableName', logs{k,2}, 'SaveFormat', 'Array', ...
        'Position', pos(logs{k,3}, logs{k,4}, 70, 30));
end

% ---- wiring ------------------------------------------------------------
L = @(a, b) add_line(mdl, a, b, 'autorouting', 'on');
% interior node
L('Qint/1', 'MuxH/1');  L('ModeSwitch/1', 'MuxH/2');  L('T_of_H/1', 'MuxH/3');
L('T_S/1',  'MuxH/4');  L('Tair/1', 'MuxH/5');
L('MuxH/1', 'dHdt/1');  L('dHdt/1', 'H/1');  L('H/1', 'T_of_H/1');
% skin node
L('T_of_H/1', 'MuxS/1'); L('T_S/1', 'MuxS/2'); L('Tair/1', 'MuxS/3');
L('Tsky/1', 'MuxS/4');   L('Tgnd/1', 'MuxS/5'); L('Qsol/1', 'MuxS/6');
L('MuxS/1', 'dTsdt/1');  L('dTsdt/1', 'T_S/1');
% heater control
L('T_of_H/1', 'Negate/1');
L('Negate/1', 'RelayOperating/1');  L('Negate/1', 'RelaySurvival/1');
L('RelayOperating/1', 'ModeSwitch/1');  L('Mode/1', 'ModeSwitch/2');
L('RelaySurvival/1', 'ModeSwitch/3');
% logging
L('T_of_H/1', 'log_TI/1');  L('T_S/1', 'log_TS/1');  L('ModeSwitch/1', 'log_Qhtr/1');

save_system(mdl, fullfile(fileparts(mfilename('fullpath')), [mdl '.slx']));
end

function add_fcn(path, expr, position)
% Fcn block: parameter is 'Expression' in current releases, 'Expr' in old ones.
add_block('simulink/User-Defined Functions/Fcn', path, 'Position', position);
try
    set_param(path, 'Expression', expr);
catch
    set_param(path, 'Expr', expr);
end
end
