function P = thermal_params()
%THERMAL_PARAMS  Single source of truth for every input to the thermal model.
%
%   P = thermal_params() returns a struct of parameters for the L'SPACE
%   polar rover Thermal Control Subsystem (TCS). Every value is tagged in a
%   comment as one of:
%       [PDR]  taken from the 2023 L'SPACE Team 20 PDR
%       [SRC]  taken from a cited external source (see docs/sources.md)
%       [ASM]  engineering assumption made for this analysis (see
%              docs/thermal_subsystem_design.md, "Assumptions register")
%       [DES]  design decision made in this revision
%
%   Units are SI throughout (m, kg, s, W, J, K).

%% Physical constants
P.sigma = 5.670374419e-8;      % Stefan-Boltzmann [W/m^2/K^4]
P.sol   = 88775;               % length of a Mars sol [s] [PDR]

%% Mission / site
P.site.lat_deg   = 85;         % north polar layered deposits ridge route [ASM A-01]
P.site.Ls_hot    = 90;         % northern summer solstice: highest sun [ASM A-02]
P.site.Ls_cold   = 125;        % end of 90-sol mission: lowest sun [ASM A-02]

%% Warm Electronics Box (WEB) geometry - inner envelope [ASM A-03]
% Sized to enclose MSolo (15.5 x 20 x 46 cm [PDR]), the neutron
% spectrometer, avionics, battery and the PCM module.
P.web.L = 0.50;  P.web.W = 0.30;  P.web.H = 0.25;   % [m]

%% Interior node thermal mass [J/K]
% mass [kg] x specific heat [J/kg/K]
P.int.parts = { ...
    'MSolo mass spectrometer',  6.0, 800;   % mass [PDR], cp [ASM A-04]
    'Neutron spectrometer',     1.6, 800;   % mass [PDR], cp [ASM A-04]
    'Avionics (CPU, SSR, radio)',1.0, 800;  % [ASM A-05]
    'Li-ion battery',           1.5, 1000;  % [ASM A-05]
    'WEB inner panels + plate', 1.5, 900};  % aluminium [ASM A-05]
P.int.C = sum(cell2mat(P.int.parts(:,2)) .* cell2mat(P.int.parts(:,3)));

%% Outer skin node
P.skin.t_sheet = 0.0005;       % 0.5 mm aluminium face sheet [ASM A-06]
P.skin.rho     = 2700;         % [kg/m^3]
P.skin.cp      = 900;          % [J/kg/K]

%% Insulation options  {name, k [W/m/K], density [kg/m^3]}
P.ins.options = { ...
    'Silica aerogel',        0.010, 15;    % k at Mars pressure [SRC Wordsworth 2019]; rho [SRC JPL 1995]
    'MLI in Mars CO2',       0.015, 40;    % gas conduction degrades MLI [SRC Fesmire]; values [ASM A-07]
    'Polycarbonate (2023)',  0.22, 1200};  % the 2023 shell: k [PDR], rho [ASM]
P.ins.baseline = 1;            % aerogel [DES]
P.ins.t        = 0.075;        % 75 mm baseline thickness [DES, from trade]

%% Parasitic conductance interior -> chassis (at air temperature) [W/K]
% 4 G-10 standoffs, d = 10 mm, L = 25 mm, k = 0.29 W/m/K          [ASM A-08]
% 30 x AWG26 copper conductors, 0.128 mm^2, 0.15 m run, k = 400    [ASM A-08]
% MSolo inlet / aperture closure allowance                          [ASM A-08]
G_standoff = 4 * 0.29 * (pi*0.005^2) / 0.025;
G_harness  = 30 * 400 * 0.128e-6 / 0.15;
G_aperture = 0.005;
P.leak.G = G_standoff + G_harness + G_aperture;

%% Exterior coating options {name, alpha_solar, epsilon_IR}
P.coat.options = { ...
    'White paint',            0.15, 0.88;   % alpha [PDR success criteria]; eps [ASM A-09]
    'Black AZ-1000-ECB (2023)',0.97, 0.89;  % [PDR / AZ Technology datasheet]
    'Low-e (VDA tape)',       0.12, 0.04};  % typical handbook values [ASM A-09]
P.coat.baseline = 2;           % black AZ-1000-ECB [DES, from trade]

%% Phase change material: n-octadecane  [SRC Faden et al. 2019]
P.pcm.Tm   = 301.13;           % mean melting point [K]
P.pcm.L    = 236.98e3;         % latent heat of fusion [J/kg]
P.pcm.cp   = 2000;             % sensible heat (approx.) [ASM A-10]
P.pcm.m    = 1.0;              % baseline PCM mass [kg] [DES, from trade]
P.pcm.container_frac = 0.40;   % container + fins as fraction of PCM mass [ASM A-10]

%% Internal dissipation [W]  (all electrical power inside WEB becomes heat)
P.load.baseline = 1.0;         % comms 1 W + CPU ~0 W normal use [PDR]
P.load.science  = 38.0;        % MSolo 35 + NSS 1.5 + CPU 0.5 + comms 1 [PDR]
P.load.scan_h   = 2.0;         % scan duration per science sol [h] [ASM A-11]
P.load.scan_start_frac = 13/24.66; % scan starts ~13:00 LST (hottest) [ASM A-11]

%% Heater control (software thermostat on interior node)
P.htr.on_K      = 295.15;      % heater ON below  [DES]
P.htr.off_K     = 297.15;      % heater OFF above [DES]
P.htr.surv_on_K = 265.15;      % survival set point: 2 K above the 263.15 K limit [DES]
P.htr.surv_off_K= 267.15;
P.req.T_surv_min = 263.15;     % TCS-02 survival limit [DES]
P.htr.T_cutoff  = 308.15;      % series over-temperature cutoff per string [DES]
P.htr.P_max     = 30.0;        % installed heater capacity per string [W] [DES, sized in run_steady_state]
P.htr.V_factor  = 0.81;        % power at minimum bus voltage, (0.9 V_nom)^2 [ASM A-17]
P.htr.max_duty  = 0.70;        % sizing rule: worst-case duty cycle <= 70% [DES]

%% Operations concept
P.ops.warmup_h  = 6.0;        % pre-heat lead time before a scan [h] [DES, set by failure case F1]
P.ops.science_sols = [6 30 31 32 40 41 42 45 46 65 75:82]; % NSS/MSolo sols [PDR]
P.ops.n_sols    = 90;          % mission length [PDR]

%% Thermal requirements (see docs/thermal_subsystem_design.md section 3)
P.req.T_op_min = 293.15;       % TCS-01 [PDR TSS-3]
P.req.T_op_max = 303.15;       % TCS-01 [PDR TSS-3]

%% Environment cases
% Air temperature: Phoenix (68 N) average daily high -30 C / low -79 C
% over its first 61 sols [SRC NASA PIA11003], widened by +/-10 K design
% margin because Phoenix values are averages at a lower latitude [DES].
% Convection: 0.4 / 4.0 W/m^2/K worst-case hot / cold guideline
% [SRC Popok, TFAWS 2024, citing Mars Sample Return guidelines].
% Sky: clear Mars sky is colder than the air [SRC Popok 2024];
% depression values are [ASM A-12].  Ground = air temperature [ASM A-13].
P.env.hot  = struct('name','Hot operational', 'Ls',P.site.Ls_hot,  'tau',0.3, ...
    'albedo',0.40, 'T_air_max',253.15, 'T_air_min',204.15, 'sky_dep',30, 'h',0.4, ...
    'science',true);
P.env.cold = struct('name','Cold operational','Ls',P.site.Ls_cold, 'tau',1.0, ...
    'albedo',0.25, 'T_air_max',233.15, 'T_air_min',184.15, 'sky_dep',50, 'h',4.0, ...
    'science',false);
P.env.storm = struct('name','Dust storm survival','Ls',P.site.Ls_cold,'tau',3.0, ...
    'albedo',0.25, 'T_air_max',233.15, 'T_air_min',184.15, 'sky_dep',50, 'h',4.0, ...
    'science',false);
P.env.t_peak_frac = 14/24.66;  % air temperature peaks ~14:00 LST [ASM A-14]

%% Solar array (for the EPS interface check only)
P.sa.area  = 2 * 0.8 * 0.8;    % two 0.8 m x 0.8 m panels [PDR trade table]
P.sa.tilt  = 35;               % [deg] from horizontal [PDR]
P.sa.eff   = 0.28;             % triple-junction cell efficiency [ASM A-15]
P.sa.derate= 0.80;             % dust, temperature, wiring losses [ASM A-15]
P.batt.usable_Wh = 150;        % usable battery energy, PDR value TBD [ASM A-16]
end
