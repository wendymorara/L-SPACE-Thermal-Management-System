%RUN_TRANSIENT_CASES  Design-case transient simulations and mission energy.
%
%   Runs the 2026 baseline design through every design case, compares the
%   two operating concepts, and computes the survival time on battery:
%
%     Concept A  hold 293-303 K all mission (2023 requirement read literally)
%     Concept B  hold 293-303 K from warm-up through each scan; hold the
%                263 K survival set point otherwise (proposed)
%
%   Outputs (results/):
%     cases_summary.csv      one row per design case
%     mission_energy.csv     heater energy over 90 sols, concepts A and B
%     ts_<case>.csv          last-sol time series for plotting

here = fileparts(mfilename('fullpath'));
addpath(here);
P = thermal_params();
res = fullfile(here, 'results');
if ~exist(res,'dir'), mkdir(res); end

n_sci = numel(P.ops.science_sols);
n_std = P.ops.n_sols - n_sci;

% {id, label, env, mode, science}
C = { 'hot_sci_B',  'Hot, science sol, concept B',   'hot',  'scheduled',   true;
      'hot_std_B',  'Hot, standby sol, concept B',   'hot',  'scheduled',   false;
      'cold_sci_B', 'Cold, science sol, concept B',  'cold', 'scheduled',   true;
      'cold_std_B', 'Cold, standby sol, concept B',  'cold', 'scheduled',   false;
      'hot_sci_A',  'Hot, science sol, concept A',   'hot',  'operational', true;
      'hot_std_A',  'Hot, standby sol, concept A',   'hot',  'operational', false;
      'cold_sci_A', 'Cold, science sol, concept A',  'cold', 'operational', true;
      'cold_std_A', 'Cold, standby sol, concept A',  'cold', 'operational', false;
      'storm_surv', 'Dust storm, survival',          'storm','survival',    false };

rows = {}; E = struct();
fprintf('%-32s %8s %8s %9s %9s %7s %6s\n','Case','Tmin[K]','Tmax[K]','scanMin','scanMax','E[Wh]','PCM');
for i = 1:size(C,1)
    o = struct('mode', C{i,4}, 'science', C{i,5}, 'n_sols', 4);
    R = simulate_web(P, P.env.(C{i,3}), o);
    E.(C{i,1}) = R.E_htr_Wh;
    [Ea, ~] = solar_array_energy(P, P.env.(C{i,3}));
    fprintf('%-32s %8.1f %8.1f %9.1f %9.1f %7.0f %6.2f\n', C{i,2}, R.Tmin, R.Tmax, ...
        R.Tmin_window, R.Tmax_window, R.E_htr_Wh, R.melt_max);
    rows(end+1,:) = {C{i,1}, C{i,2}, R.Tmin, R.Tmax, R.Tmin_window, R.Tmax_window, ...
        R.E_htr_Wh, R.duty, R.melt_max, Ea}; %#ok<SAGROW>

    % last-sol time series, decimated to 1-minute resolution
    last = find(R.t >= (o.n_sols-1)*P.sol);   % plot the final sol
    k = last(1:6:end);
    write_csv(fullfile(res, ['ts_' C{i,1} '.csv']), ...
        {'t_h','T_int_K','T_skin_K','T_air_K','Q_htr_W','Q_int_W','Q_sol_W','pcm_melt'}, ...
        [(R.t(k)-R.t(last(1)))/3600, R.T_I(k), R.T_S(k), R.env.T_air(k), ...
         R.Q_htr(k), R.Q_int(k), R.env.Q_sol(k), R.melt(k)]);
end
write_csv(fullfile(res,'cases_summary.csv'), ...
    {'id','case','Tmin_K','Tmax_K','scan_Tmin_K','scan_Tmax_K','heater_Wh_per_sol', ...
     'heater_duty','pcm_melt_max','array_Wh_per_sol'}, rows);

% ---- mission heater energy: 18 science sols + 72 standby sols ------------
mrows = {};
for env_ = {'hot','cold'}
    for con = {'A','B'}
        sci = E.([env_{1} '_sci_' con{1}]);  std = E.([env_{1} '_std_' con{1}]);
        tot = n_sci*sci + n_std*std;
        mrows(end+1,:) = {env_{1}, con{1}, sci, std, tot/1000}; %#ok<SAGROW>
    end
end
write_csv(fullfile(res,'mission_energy.csv'), ...
    {'environment','concept','science_sol_Wh','standby_sol_Wh','mission_kWh'}, mrows);
fprintf('\nMission heater energy (%d science + %d standby sols):\n', n_sci, n_std);
for r = 1:size(mrows,1)
    fprintf('  %-4s concept %s : %6.1f kWh\n', mrows{r,1}, mrows{r,2}, mrows{r,5});
end
for env_ = {'hot','cold'}
    a = mrows{strcmp(mrows(:,1),env_{1}) & strcmp(mrows(:,2),'A'),5};
    b = mrows{strcmp(mrows(:,1),env_{1}) & strcmp(mrows(:,2),'B'),5};
    fprintf('  %-4s saving with concept B: %4.0f %%\n', env_{1}, 100*(1-b/a));
end

% ---- survival on battery alone (array fully obscured) --------------------
P_surv = E.storm_surv / (P.sol/3600);            % average survival heater power [W]
P_bus  = P_surv + P.load.baseline;               % heater + baseline load
t_surv = P.batt.usable_Wh / P_bus;               % [h]
fprintf('\nSurvival with no solar input: %.1f W heater + %.1f W load -> %.1f h on %d Wh battery\n', ...
        P_surv, P.load.baseline, t_surv, P.batt.usable_Wh);
write_csv(fullfile(res,'survival.csv'), {'heater_avg_W','load_W','battery_Wh','survival_h'}, ...
    [P_surv, P.load.baseline, P.batt.usable_Wh, t_surv]);
