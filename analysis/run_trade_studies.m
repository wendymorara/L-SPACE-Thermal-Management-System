%RUN_TRADE_STUDIES  Quantitative trade studies driven by the thermal model.
%
%   T1  insulation material x thickness  -> heater power vs mass
%   T2  exterior coating                 -> mission heater energy
%   T3  PCM mass x scan duration         -> peak payload temperature
%   T4  heating approach (RHUs)          -> mission heater energy
%
%   Every trade is evaluated with the same simulate_web() model used for
%   the design cases, so the numbers in the trade tables are traceable to
%   one verified model.
%
%   Outputs: results/trade_T1_insulation.csv ... trade_T4_heating.csv

here = fileparts(mfilename('fullpath'));
addpath(here);
P = thermal_params();
res = fullfile(here, 'results');
if ~exist(res,'dir'), mkdir(res); end
n_sci = numel(P.ops.science_sols);  n_std = P.ops.n_sols - n_sci;

% Equivalent mass of heater power: the PDR array (5.01 kg for two panels)
% delivers the cold-case average power below, so each watt of continuous
% heater power costs this much array mass.                         [ASM A-18]
[~, Pa_cold] = solar_array_energy(P, P.env.cold);
kg_per_W = 5.0115 / Pa_cold;
fprintf('Equivalent array mass: %.3f kg per W of continuous heater power\n\n', kg_per_W);

%% T1 - insulation material x thickness (cold standby sol, concept B)
th = [0.010 0.020 0.030 0.050 0.075 0.100 0.125];
rows = {};
fprintf('T1 insulation          t[mm]  Q_htr[W]  m_ins[kg]  m_equiv[kg]\n');
for m = 1:2                                     % aerogel, MLI-in-CO2
    for t_ = th
        o = struct('ins_idx', m, 't_ins', t_, 'mode','scheduled', 'science', false, ...
                   'P_htr', 200, 'n_sols', 4);  % large heater: measure demand, not capacity
        R = simulate_web(P, P.env.cold, o);
        m_ins = R.g.V_ins * P.ins.options{m,3};
        m_eq  = m_ins + kg_per_W * R.Qhtr_avg;
        fprintf('%-22s %5.0f %9.2f %10.2f %12.2f\n', P.ins.options{m,1}, 1000*t_, R.Qhtr_avg, m_ins, m_eq);
        rows(end+1,:) = {P.ins.options{m,1}, 1000*t_, R.Qhtr_avg, R.E_htr_Wh, m_ins, m_eq}; %#ok<SAGROW>
    end
end
write_csv(fullfile(res,'trade_T1_insulation.csv'), ...
    {'material','thickness_mm','heater_avg_W','heater_Wh_per_sol','insulation_kg','equivalent_kg'}, rows);

%% T2 - exterior coating (mission energy, concept B, hot and cold bounds)
rows = {};
fprintf('\nT2 coating                     hot[kWh]  cold[kWh]  scanTmax_hot[K]\n');
for k = 1:size(P.coat.options,1)
    tot = struct();
    for env_ = {'hot','cold'}
        o = struct('coat_idx',k,'mode','scheduled','n_sols',4);
        o.science = true;  Rs = simulate_web(P, P.env.(env_{1}), o);
        o.science = false; Rb = simulate_web(P, P.env.(env_{1}), o);
        tot.(env_{1}) = (n_sci*Rs.E_htr_Wh + n_std*Rb.E_htr_Wh)/1000;
        if strcmp(env_{1},'hot'), Tmx = Rs.Tmax_window; end
    end
    fprintf('%-30s %8.1f %10.1f %14.1f\n', P.coat.options{k,1}, tot.hot, tot.cold, Tmx);
    rows(end+1,:) = {P.coat.options{k,1}, P.coat.options{k,2}, P.coat.options{k,3}, tot.hot, tot.cold, Tmx}; %#ok<SAGROW>
end
write_csv(fullfile(res,'trade_T2_coating.csv'), ...
    {'coating','alpha','epsilon','mission_kWh_hot','mission_kWh_cold','scan_Tmax_hot_K'}, rows);

%% T3 - PCM mass x scan duration (hot science sol, concept B)
masses = [0 0.5 1.0 1.5 2.0];
scans  = [0.5 1 2 3 4];
Tmax = zeros(numel(masses), numel(scans));  melt = Tmax;
for i = 1:numel(masses)
    for j = 1:numel(scans)
        o = struct('m_pcm', masses(i), 'scan_h', scans(j), 'mode','scheduled', ...
                   'science', true, 'n_sols', 4);
        R = simulate_web(P, P.env.hot, o);
        Tmax(i,j) = R.Tmax_window;  melt(i,j) = R.melt_max;
    end
end
fprintf('\nT3 peak payload temperature [K], hot science sol (rows PCM kg, cols scan h)\n');
fprintf('%8s', 'kg|h'); fprintf('%8.1f', scans); fprintf('\n');
for i = 1:numel(masses)
    fprintf('%8.1f', masses(i)); fprintf('%8.1f', Tmax(i,:)); fprintf('\n');
end
rows = {};
for i = 1:numel(masses)
    for j = 1:numel(scans)
        rows(end+1,:) = {masses(i), scans(j), Tmax(i,j), melt(i,j)}; %#ok<SAGROW>
    end
end
write_csv(fullfile(res,'trade_T3_pcm.csv'), {'pcm_kg','scan_h','Tmax_K','melt_fraction'}, rows);

%% T4 - heating approach: electric heaters only vs + radioisotope heater units
rows = {};
fprintf('\nT4 heating approach      hot[kWh]  cold[kWh]  hot standby Tmax[K]\n');
for q = [0 4 8]
    tot = struct();
    for env_ = {'hot','cold'}
        o = struct('Q_rhu', q, 'mode','scheduled','n_sols',4);
        o.science = true;  Rs = simulate_web(P, P.env.(env_{1}), o);
        o.science = false; Rb = simulate_web(P, P.env.(env_{1}), o);
        tot.(env_{1}) = (n_sci*Rs.E_htr_Wh + n_std*Rb.E_htr_Wh)/1000;
        if strcmp(env_{1},'hot'), Tstb = Rb.Tmax; end
    end
    label = sprintf('Heaters + %d x 1 W RHU', q); if q == 0, label = 'Heaters only'; end
    fprintf('%-24s %8.1f %10.1f %18.1f\n', label, tot.hot, tot.cold, Tstb);
    rows(end+1,:) = {label, q, tot.hot, tot.cold, Tstb}; %#ok<SAGROW>
end
write_csv(fullfile(res,'trade_T4_heating.csv'), ...
    {'approach','rhu_W','mission_kWh_hot','mission_kWh_cold','hot_standby_Tmax_K'}, rows);
