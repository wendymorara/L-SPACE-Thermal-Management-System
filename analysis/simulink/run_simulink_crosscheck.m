%RUN_SIMULINK_CROSSCHECK  Code-to-code verification: Simulink vs MATLAB script.
%
%   Builds the Simulink model of the Warm Electronics Box, runs it on the
%   same inputs as simulate_web.m, and compares the two independent
%   solutions (different solver, different controller implementation).
%
%   Usage (MATLAB with Simulink):
%       >> cd analysis/simulink
%       >> run_simulink_crosscheck
%
%   Outputs: web_thermal_model.slx, ../results/simulink_crosscheck.csv,
%            ../../figures/matlab/simulink_crosscheck.png

here = fileparts(mfilename('fullpath'));
addpath(fileparts(here));                     % analysis/ functions
P = thermal_params();

cases = { 'Cold, science sol (concept B)', P.env.cold,  'scheduled', true;
          'Hot, science sol (concept B)',  P.env.hot,   'scheduled', true;
          'Dust storm, survival',          P.env.storm, 'survival',  false };

rows = {};
fprintf('%-32s %9s %9s %9s %9s %9s\n', 'Case', 'Tmax ML', 'Tmax SL', 'E_htr ML', 'E_htr SL', 'dE [%]');
for i = 1:size(cases,1)
    % 1) MATLAB script model (reference) - also produces the shared inputs
    o = struct('mode', cases{i,3}, 'science', cases{i,4}, 'n_sols', 4, 'dt', 10);
    R = simulate_web(P, cases{i,2}, o);

    % 2) Simulink model on identical inputs
    mdl = build_web_simulink(P, R);
    out = sim(mdl);
    tS  = out.get('tout');
    TI  = out.get('T_I');
    Qh  = out.get('Q_htr');

    % 3) compare over the last two sols (same window simulate_web reports)
    t0 = (o.n_sols - 2) * P.sol;
    w  = tS >= t0;
    E_sl  = trapz(tS(w), Qh(w)) / 3600 / 2;          % Wh per sol
    Tmax_sl = max(TI(w));  Tmin_sl = min(TI(w));
    dE = 100 * (E_sl - R.E_htr_Wh) / R.E_htr_Wh;
    fprintf('%-32s %9.2f %9.2f %9.1f %9.1f %9.2f\n', cases{i,1}, R.Tmax, Tmax_sl, ...
            R.E_htr_Wh, E_sl, dE);
    rows(end+1,:) = {cases{i,1}, R.Tmin, Tmin_sl, R.Tmax, Tmax_sl, R.E_htr_Wh, E_sl, dE}; %#ok<SAGROW>

    if i == 1   % overlay plot for the cold science sol
        f = figure('Position', [100 100 900 420]);
        plot(R.t/3600, R.T_I, 'LineWidth', 2); hold on;
        plot(tS/3600, TI, '--', 'LineWidth', 1.5);
        yline(P.req.T_op_min, 'k:'); yline(P.req.T_op_max, 'k:');
        xlabel('Time [h]'); ylabel('Payload temperature [K]'); grid on;
        legend('MATLAB script (Euler, dt = 10 s)', 'Simulink (ode23t)', 'Location', 'southeast');
        title('Code-to-code verification: cold science sol');
        figdir = fullfile(fileparts(fileparts(here)), 'figures', 'matlab');
        if ~exist(figdir, 'dir'), mkdir(figdir); end
        exportgraphics(f, fullfile(figdir, 'simulink_crosscheck.png'), 'Resolution', 150);
    end
end

write_csv(fullfile(fileparts(here), 'results', 'simulink_crosscheck.csv'), ...
    {'case','Tmin_matlab_K','Tmin_simulink_K','Tmax_matlab_K','Tmax_simulink_K', ...
     'heater_Wh_matlab','heater_Wh_simulink','heater_diff_pct'}, rows);

% Acceptance: the two solvers agree within 0.5 K and 3 % heater energy.
dT = max(abs([cell2mat(rows(:,2)) - cell2mat(rows(:,3)); cell2mat(rows(:,4)) - cell2mat(rows(:,5))]));
dEmax = max(abs(cell2mat(rows(:,8))));
fprintf('\nMax temperature difference %.3f K (limit 0.5), max energy difference %.2f %% (limit 3)\n', dT, dEmax);
if dT <= 0.5 && dEmax <= 3
    fprintf('V7 code-to-code check: PASS\n');
else
    fprintf('V7 code-to-code check: FAIL - inspect the overlay plot\n');
end
