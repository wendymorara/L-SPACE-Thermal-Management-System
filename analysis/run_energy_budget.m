%RUN_ENERGY_BUDGET  Thermal energy balance of the WEB for each operating mode.
%
%   Control volume: the whole Warm Electronics Box (interior + skin).
%     IN   internal dissipation + heater + absorbed solar
%     OUT  IR radiation to sky and ground + convection to air + leaks to chassis
%     STORAGE  rate of change of stored heat (non-zero while warming or cooling)
%   Values are time averages over each mode's window, in watts. The closure
%   column (IN - OUT - STORAGE) should be ~0 and is a bookkeeping check.
%
%   Modes:
%     Standby   cold standby sol, whole sol
%     Warm-up   cold science sol, from warm-up start to scan start
%     Science   cold / hot science sol, the 2 h scan
%     Survival  dust storm, whole sol
%
%   Output: results/energy_budget.csv

here = fileparts(mfilename('fullpath'));
addpath(here);
P = thermal_params();
res = fullfile(here, 'results');

t_scan0 = P.load.scan_start_frac * P.sol;
t_scan1 = t_scan0 + P.load.scan_h*3600;
t_wu0   = t_scan0 - P.ops.warmup_h*3600;

% {label, env, mode, science, window start, window end (time of sol, s)}
M = { 'Standby (cold)',  'cold',  'scheduled', false, 0,       P.sol;
      'Warm-up (cold)',  'cold',  'scheduled', true,  t_wu0,   t_scan0;
      'Science (cold)',  'cold',  'scheduled', true,  t_scan0, t_scan1;
      'Science (hot)',   'hot',   'scheduled', true,  t_scan0, t_scan1;
      'Survival (storm)','storm', 'survival',  false, 0,       P.sol };

rows = {};
fprintf('%-17s %7s %7s %7s | %7s %7s %7s | %8s %8s\n', 'Mode [W]', 'Q_int', 'Q_htr', 'Q_sol', ...
        'Q_rad', 'Q_conv', 'Q_leak', 'storage', 'closure');
for i = 1:size(M,1)
    o = struct('mode', M{i,3}, 'science', M{i,4}, 'n_sols', 4);
    R = simulate_web(P, P.env.(M{i,2}), o);
    tsol = mod(R.t, P.sol);
    w = R.t >= 3*P.sol & R.t < 4*P.sol & tsol >= M{i,5} & tsol < M{i,6};
    idx = find(w);
    % stored energy change over the window (interior enthalpy + skin)
    % (uses the solver's enthalpy directly: on the PCM plateau, temperature
    %  alone cannot tell how much wax has melted)
    dE = (R.H(idx(end)+1) - R.H(idx(1))) + R.g.C_skin*(R.T_S(idx(end)+1) - R.T_S(idx(1)));
    dur = numel(idx) * R.opts.dt;
    Qi = mean(R.Q_int(w)); Qh = mean(R.Q_htr(w)); Qs = mean(R.env.Q_sol(w));
    Qr = mean(R.Q_rad(w)); Qc = mean(R.Q_conv(w)); Ql = mean(R.Q_leak(w));
    st = dE / dur;
    cl = Qi + Qh + Qs - Qr - Qc - Ql - st;
    fprintf('%-17s %7.2f %7.2f %7.2f | %7.2f %7.2f %7.2f | %8.2f %8.3f\n', M{i,1}, Qi, Qh, Qs, Qr, Qc, Ql, st, cl);
    rows(end+1,:) = {M{i,1}, dur/3600, Qi, Qh, Qs, Qr, Qc, Ql, st, cl}; %#ok<SAGROW>
end
write_csv(fullfile(res, 'energy_budget.csv'), ...
    {'mode','window_h','Q_internal_W','Q_heater_W','Q_solar_W','Q_radiation_W', ...
     'Q_convection_W','Q_leak_W','storage_W','closure_W'}, rows);
