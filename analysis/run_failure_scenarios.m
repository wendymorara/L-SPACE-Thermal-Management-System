%RUN_FAILURE_SCENARIOS  Off-nominal cases for the test plan and risk analysis.
%
%   F1  One heater string lost; the redundant string runs at minimum bus
%       voltage (30 W x 0.81). Cold science sol: is the payload warm by scan start?
%   F2  All heater power lost (both strings or the heater bus) during cold
%       standby: cold soak. How long until the battery's -20 C discharge limit
%       (253.15 K), and where does the box settle?
%   F3  Low power in a dust storm: heaters limited to 10 W. Survival held?
%   F4  Heater stuck ON in hot standby, with and without the 308 K
%       independent over-temperature cutoff.
%
%   Output: results/failure_scenarios.csv

here = fileparts(mfilename('fullpath'));
addpath(here);
P = thermal_params();
res = fullfile(here, 'results');
rows = {};

%% F1 - single string at minimum bus voltage
o = struct('mode','scheduled','science',true,'n_sols',4,'P_htr',P.htr.P_max*P.htr.V_factor);
R = simulate_web(P, P.env.cold, o);
pass = R.Tmin_window >= P.req.T_op_min && R.Tmax_window <= P.req.T_op_max;
fprintf('F1 single string %.1f W: scan window %.1f-%.1f K -> %s\n', o.P_htr, ...
        R.Tmin_window, R.Tmax_window, pass_fail(pass));
rows(end+1,:) = {'F1','One heater string lost, other at min bus voltage (24.3 W), cold science sol', ...
    'Scan-window payload temperature [K]', sprintf('%.1f-%.1f', R.Tmin_window, R.Tmax_window), ...
    '293.15-303.15', pass_fail(pass)};

%% F2 - total heater loss, cold soak from the standby set point
o = struct('mode','survival','science',false,'n_sols',4,'heater_off_after',0,'T0',P.htr.surv_off_K);
R = simulate_web(P, P.env.cold, o);
k = find(R.T_I < 253.15, 1);
t253 = (R.t(k) - R.t(1)) / 3600;
T_end = mean(R.T_I(R.t >= 3*P.sol));
fprintf('F2 total heater loss: 267 K -> 253 K in %.1f h; settles near %.0f K\n', t253, T_end);
rows(end+1,:) = {'F2','All heater power lost during cold standby (cold soak)', ...
    'Time from 267 K to battery limit 253 K [h]', sprintf('%.1f', t253), ...
    'sets the fault-response time', 'n/a'};
rows(end+1,:) = {'F2b','All heater power lost: long-term settling temperature', ...
    'Sol-mean interior temperature after 3 sols [K]', sprintf('%.0f', T_end), ...
    'information only', 'n/a'};

%% F3 - dust storm, heater power limited to 10 W
o = struct('mode','survival','science',false,'n_sols',4,'P_htr',10);
R = simulate_web(P, P.env.storm, o);
pass = R.Tmin >= P.req.T_surv_min;
fprintf('F3 storm, 10 W heaters: Tmin %.1f K, duty %.0f %% -> %s\n', R.Tmin, 100*R.duty, pass_fail(pass));
rows(end+1,:) = {'F3','Dust storm with heater power limited to 10 W', ...
    'Minimum interior temperature [K] (duty cycle)', sprintf('%.1f (%.0f %%)', R.Tmin, 100*R.duty), ...
    '>= 263.15 (TCS-02 survival limit)', pass_fail(pass)};

%% F4 - heater stuck on, hot standby, with / without cutoff
for cut = [Inf P.htr.T_cutoff]
    o = struct('mode','scheduled','science',false,'n_sols',2,'stuck_on_after',0.5*P.sol,'T_cutoff',cut);
    R = simulate_web(P, P.env.hot, o);
    Tpk = max(R.T_I);
    if isinf(cut)
        label = 'Heater stuck ON in hot standby, no cutoff';  crit = 'information only'; v = 'n/a';
    else
        label = 'Heater stuck ON in hot standby, 308 K cutoff';
        crit = '<= 313.15 (payload non-operating max, assumed)'; v = pass_fail(Tpk <= 313.15);
    end
    fprintf('F4 %s: peak %.1f K\n', label, Tpk);
    rows(end+1,:) = {'F4', label, 'Peak interior temperature [K]', sprintf('%.1f', Tpk), crit, v}; %#ok<SAGROW>
end

write_csv(fullfile(res,'failure_scenarios.csv'), ...
    {'id','scenario','metric','result','criterion','verdict'}, rows);
