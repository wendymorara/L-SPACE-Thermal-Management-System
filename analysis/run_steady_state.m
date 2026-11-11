%RUN_STEADY_STATE  Hand-calculation level energy balance and heater sizing.
%
%   Reproduces the 2023 PDR question ("what heater power keeps the payload
%   in its operating band?") with a closed energy balance, for:
%     - the 2023 design (polycarbonate shell, black paint, no insulation)
%     - the 2026 baseline (75 mm silica aerogel WEB, black paint)
%   in the hot and cold operational environments.
%
%   Two levels of hand calculation:
%     sol-mean   : sol-averaged air/sky temperatures and absorbed solar
%     worst-inst : coldest air temperature and zero sun (heater sizing)
%
%   Outputs: results/steady_state.csv and a printed summary.

here = fileparts(mfilename('fullpath'));
addpath(here);
P = thermal_params();
if ~exist(fullfile(here,'results'),'dir'), mkdir(fullfile(here,'results')); end

T_set = P.htr.on_K;                       % hold the interior at 295.15 K
designs = { '2023 PDR design', 3, 0.0232, 2;      % polycarbonate 23.2 mm [PDR]
            '2026 baseline',   1, P.ins.t, P.coat.baseline };
cases = {'hot','cold'};
rows = {};
fprintf('\n%-16s %-5s %7s %8s %8s %9s %9s\n', 'Design','Case','G_ins','T_skin','Q_loss','P_req','P_peak');
fprintf('%-16s %-5s %7s %8s %8s %9s %9s\n', '','','[W/K]','[K]','[W]','mean [W]','worst [W]');
for d = 1:size(designs,1)
    g = web_geometry(P, designs{d,3}, P.ins.options{designs{d,2},2});
    alpha = P.coat.options{designs{d,4},2};
    for c = 1:numel(cases)
        E = P.env.(cases{c});
        t = linspace(0, P.sol, 2000)';
        env = environment_series(P, E, t, g, alpha);
        Ta = mean(env.T_air);
        % sol-mean hand calculation
        sm = steady_balance(P, g, designs{d,4}, T_set, Ta, Ta - E.sky_dep, Ta, ...
                            E.h, mean(env.Q_sol), P.load.baseline);
        % worst instantaneous: coldest air, no sun
        Tmin = E.T_air_min;
        wi = steady_balance(P, g, designs{d,4}, T_set, Tmin, Tmin - E.sky_dep, Tmin, ...
                            E.h, 0, P.load.baseline);
        fprintf('%-16s %-5s %7.3f %8.1f %8.1f %9.1f %9.1f\n', designs{d,1}, cases{c}, ...
                g.G_ins, sm.T_S, sm.Q_loss, sm.P_req, wi.P_req);
        rows(end+1,:) = {designs{d,1}, cases{c}, g.G_ins, sm.T_S, sm.Q_loss, sm.P_req, wi.P_req}; %#ok<SAGROW>
    end
end
write_csv(fullfile(here,'results','steady_state.csv'), ...
    {'design','case','G_ins_W_per_K','T_skin_K','Q_loss_W','P_req_mean_W','P_req_worst_W'}, rows);

% ---- heater sizing (2026 baseline) ---------------------------------------
P_worst = rows{end,7};                    % cold case, worst instantaneous
P_min_installed = P_worst / (P.htr.max_duty * P.htr.V_factor);
fprintf('\nHeater sizing (2026 baseline, cold worst-instantaneous):\n');
fprintf('  required power           %6.1f W\n', P_worst);
fprintf('  / max duty %.2f / bus-voltage factor %.2f\n', P.htr.max_duty, P.htr.V_factor);
fprintf('  minimum installed        %6.1f W\n', P_min_installed);
if P.htr.P_max >= P_min_installed, verdict = 'meets rule'; else, verdict = 'DOES NOT meet rule'; end
fprintf('  selected per string      %6.1f W  (%s)\n', P.htr.P_max, verdict);
