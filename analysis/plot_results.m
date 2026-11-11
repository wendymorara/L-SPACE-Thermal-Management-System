%PLOT_RESULTS  MATLAB/Octave figures from the CSV files in results/.

here = fileparts(mfilename('fullpath'));
res  = fullfile(here, 'results');
out  = fullfile(fileparts(here), 'figures', 'matlab');
if ~exist(out, 'dir'), mkdir(out); end
P = thermal_params();

%% Figure 1 - cold science sol, concept B
d = dlmread(fullfile(res, 'ts_cold_sci_B.csv'), ',', 1, 0);
f = figure('visible', 'off', 'position', [100 100 900 600]);
subplot(2,1,1);
plot(d(:,1), d(:,2), 'linewidth', 2); hold on;
plot(d(:,1), d(:,3), d(:,1), d(:,4));
plot([0 d(end,1)], P.req.T_op_min*[1 1], 'k--', [0 d(end,1)], P.req.T_op_max*[1 1], 'k--');
ylabel('Temperature [K]'); legend('Payload (interior)', 'WEB skin', 'Air', 'location', 'southwest');
title('Cold case, science sol (concept B)'); grid on;
subplot(2,1,2);
plot(d(:,1), d(:,5), d(:,1), d(:,6)); ylabel('Power [W]'); xlabel('Local solar time [h]');
legend('Heater', 'Internal dissipation'); grid on;
print(f, fullfile(out, 'cold_science_sol.png'), '-dpng', '-r120'); close(f);

%% Figure 2 - insulation trade
fid = fopen(fullfile(res, 'trade_T1_insulation.csv')); fgetl(fid);
C = textscan(fid, '%q %f %f %f %f %f', 'delimiter', ','); fclose(fid);
f = figure('visible', 'off');
mats = unique(C{1});
for k = 1:numel(mats)
    sel = strcmp(C{1}, mats{k});
    plot(C{2}(sel), C{6}(sel), '-o', 'linewidth', 2); hold on;
end
xlabel('Insulation thickness [mm]'); ylabel('Insulation + equivalent array mass [kg]');
legend(mats); grid on; title('Trade T1: insulation');
print(f, fullfile(out, 'trade_insulation.png'), '-dpng', '-r120'); close(f);

%% Figure 3 - PCM trade
d = dlmread(fullfile(res, 'trade_T3_pcm.csv'), ',', 1, 0);
f = figure('visible', 'off');
ms = unique(d(:,1));
for k = 1:numel(ms)
    sel = d(:,1) == ms(k);
    plot(d(sel,2), d(sel,3), '-o', 'linewidth', 2); hold on;
end
plot([0 4], P.req.T_op_max*[1 1], 'k--');
xlabel('Scan duration [h]'); ylabel('Peak payload temperature [K]');
legend(strcat(cellstr(num2str(ms)), ' kg PCM'), 'location', 'northwest'); grid on;
title('Trade T3: PCM mass vs scan duration (hot case)');
print(f, fullfile(out, 'trade_pcm.png'), '-dpng', '-r120'); close(f);
fprintf('Figures written to %s\n', out);
