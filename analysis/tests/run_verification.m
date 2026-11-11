%RUN_VERIFICATION  Automated verification of the thermal model.
%
%   No physical test was performed for this project, so the model is
%   VERIFIED (it solves its equations correctly and agrees with independent
%   calculations) but NOT VALIDATED against measured hardware data.
%
%   V1  transient model converges to the algebraic hand calculation
%   V2  energy conservation: stored energy change = net heat in
%   V3  time-step convergence (dt = 10 s vs 5 s)
%   V4  solar geometry: max polar summer elevation = 90 - lat + declination
%   V5  PCM plateau duration = m*L / net heating power
%   V6  2023 PDR solar input reproduced from its own stated inputs
%
%   Prints PASS/FAIL per check and writes results/verification.csv.

here = fileparts(fileparts(mfilename('fullpath')));
addpath(here);
addpath(fileparts(mfilename('fullpath')));   % helper functions in tests/
P = thermal_params();
rows = {}; nfail = 0;

%% V1 - steady state agreement (constant environment, heater off, no PCM)
E = P.env.cold;  Qi = 5.0;
o = struct('const_env',true,'P_htr',0,'m_pcm',0,'science',false, ...
           'Q_int_override',Qi,'n_sols',12,'T0',240);
R = simulate_web(P, E, o);
T_sim = R.T_I(end);
% algebraic: find T_I such that Q_loss(T_I) = Q_int
g = R.g; env = R.env;
f = @(Ti) getfield(steady_balance(P, g, P.coat.baseline, Ti, env.T_air(1), ...
          env.T_sky(1), env.T_gnd(1), E.h, env.Q_sol(1), Qi), 'Q_loss') - Qi;
T_alg = fzero(f, [200 300]);
err = abs(T_sim - T_alg);
[rows, nfail] = record_check(rows, nfail, 'V1', 'Transient -> algebraic steady state', err, 0.05, 'K');

%% V2 - energy conservation over one diurnal sol (hot science, baseline)
o = struct('mode','scheduled','science',true,'n_sols',2);
R = simulate_web(P, P.env.hot, o);
dt = R.opts.dt;
H_of_T = @(T) enthalpy_from_T(T, R.C_I, R.opts.m_pcm*P.pcm.L, P.pcm.Tm);
dE_int  = H_of_T(R.T_I(end)) - H_of_T(R.T_I(1));
Q_net   = sum(R.Q_int(1:end-1) + R.Q_htr(1:end-1) - R.Q_ins(1:end-1) - R.Q_leak(1:end-1)) * dt;
rel = abs(dE_int - Q_net) / sum(abs(R.Q_int + R.Q_htr)) / dt;
[rows, nfail] = record_check(rows, nfail, 'V2', 'Interior energy balance residual', rel, 1e-3, '-');

%% V3 - time-step convergence
o10 = struct('mode','scheduled','science',true,'n_sols',3,'dt',10);
o5  = o10; o5.dt = 5;
R10 = simulate_web(P, P.env.cold, o10);
R5  = simulate_web(P, P.env.cold, o5);
dT  = max(abs([R10.Tmin - R5.Tmin, R10.Tmax - R5.Tmax]));
dEh = abs(R10.E_htr_Wh - R5.E_htr_Wh) / R5.E_htr_Wh;
[rows, nfail] = record_check(rows, nfail, 'V3a', 'dt 10 s vs 5 s: temperature extremes', dT, 0.2, 'K');
[rows, nfail] = record_check(rows, nfail, 'V3b', 'dt 10 s vs 5 s: heater energy', dEh, 0.02, '-');

%% V4 - solar geometry against the analytic polar result
S = mars_solar(90, P.site.lat_deg, 0.3, 0.25, linspace(0,P.sol,4001), P.sol);
el_expected = 90 - P.site.lat_deg + 24.936;
[rows, nfail] = record_check(rows, nfail, 'V4', 'Max solar elevation, Ls 90, 85 N', ...
                       abs(max(S.el) - el_expected), 0.01, 'deg');

%% V5 - PCM plateau duration
m = 1.0; Qin = 20;
o = struct('const_env',true,'P_htr',0,'m_pcm',m,'science',false,'Q_int_override',Qin, ...
           'n_sols',1,'T0',300.5,'t_ins',10,'ins_idx',1);   % 10 m insulation ~ adiabatic
R = simulate_web(P, P.env.cold, o);
on_plateau = R.T_I == P.pcm.Tm;
Q_net = Qin - mean(R.Q_ins(on_plateau) + R.Q_leak(on_plateau));   % losses while melting
plateau_s = sum(on_plateau) * R.opts.dt;
expected_s = m * P.pcm.L / Q_net;
[rows, nfail] = record_check(rows, nfail, 'V5', 'PCM plateau duration vs m*L/Q', ...
                       abs(plateau_s - expected_s)/expected_s, 0.01, '-');

%% V6 - reproduce the 2023 PDR hot-case solar term from its own inputs
Q_pdr = 590 * 1 * 0.97;       % q_solar * A * alpha as stated in the PDR inputs
[rows, nfail] = record_check(rows, nfail, 'V6', 'PDR Q_solar recomputed (PDR printed 572.3 W)', ...
                       abs(Q_pdr - 572.3), 0.1, 'W');

%% report
write_csv(fullfile(here,'results','verification.csv'), ...
    {'id','check','value','tolerance','unit','result'}, rows);
fprintf('\n%d of %d checks passed.\n', size(rows,1) - nfail, size(rows,1));
if nfail > 0
    error('run_verification:failed', '%d verification check(s) failed', nfail);
end
