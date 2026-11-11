%RUN_ALL  Reproduce every number and figure in the L'SPACE thermal design.
%
%   Run from MATLAB (R2016b or newer, no toolboxes) or GNU Octave 8+:
%       >> cd analysis
%       >> run_all
%
%   Steps
%     1. tests/run_verification   model verification (must pass first)
%     2. run_steady_state         hand-calculation balance + heater sizing
%     3. run_transient_cases      design cases, mission energy, survival
%     4. run_energy_budget        heat balance per operating mode
%     5. run_failure_scenarios    heater loss, cold soak, low power, stuck heater
%     6. run_trade_studies        insulation, coating, PCM, heating trades
%     7. plot_results             figures -> ../figures/matlab/

here = fileparts(mfilename('fullpath'));
cd(here);
steps = {'tests/run_verification', 'run_steady_state', 'run_transient_cases', ...
         'run_energy_budget', 'run_failure_scenarios', 'run_trade_studies', 'plot_results'};
for i = 1:numel(steps)
    fprintf('\n==================== %s ====================\n', steps{i});
    run(fullfile(here, [steps{i} '.m']));
    cd(here);
end
fprintf('\nAll steps complete. Results in analysis/results/, figures in figures/matlab/.\n');
