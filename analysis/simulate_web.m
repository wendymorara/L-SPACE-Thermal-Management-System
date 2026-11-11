function R = simulate_web(P, E, o)
%SIMULATE_WEB  Transient two-node thermal model of the Warm Electronics Box.
%
%   R = simulate_web(P, E, o)
%     P  parameters from thermal_params()
%     E  environment case (P.env.hot, P.env.cold, P.env.storm)
%     o  options struct; any field left out takes the default below
%
%   Nodes
%     I  interior: payload, avionics, battery, PCM (enthalpy formulation)
%     S  outer skin: aluminium face sheet over the insulation
%
%   Heat flows
%     Q_int + Q_htr  -> I
%     I -> S         conduction through insulation, G_ins (T_I - T_S)
%     I -> chassis   parasitic leaks at air temperature, G_leak (T_I - T_air)
%     sun -> S       absorbed solar (beam + diffuse + ground albedo)
%     S -> sky, gnd  IR radiation, eps*sigma*A*(T_S^4 - T_env^4)
%     S -> air       convection h*A*(T_S - T_air)
%
%   Integration: explicit Euler with fixed step o.dt and a discrete
%   bang-bang heater controller sampled every step (the same structure a
%   flight thermostat / software controller has). Convergence in dt is
%   checked in tests/run_verification.m.

d.n_sols   = 4;          % simulated sols (last two are reported)
d.dt       = 10;         % time step [s]
d.ins_idx  = P.ins.baseline;
d.t_ins    = P.ins.t;
d.coat_idx = P.coat.baseline;
d.m_pcm    = P.pcm.m;
d.P_htr    = P.htr.P_max;
d.mode     = 'operational';   % 'operational' | 'survival' | 'scheduled'
d.warmup_h = P.ops.warmup_h;            % 'scheduled': operating band starts this long before the scan [h]
d.Q_rhu    = 0;               % radioisotope heater units, constant heat [W]
d.science  = E.science;
d.scan_h   = P.load.scan_h;
d.const_env= false;
d.T0       = 296.15;
d.Q_int_override = [];        % constant internal load for tests [W]
% failure injection (all times in seconds from t = 0)
d.heater_off_after = Inf;     % all heater power lost after this time (power loss / both strings failed)
d.stuck_on_after   = Inf;     % active string stuck ON after this time
d.T_cutoff         = Inf;     % independent over-temperature cutoff that opens a stuck string [K]
if nargin < 3, o = struct(); end
fn = fieldnames(d);
for i = 1:numel(fn)
    if ~isfield(o, fn{i}), o.(fn{i}) = d.(fn{i}); end
end

k_ins = P.ins.options{o.ins_idx, 2};
alpha = P.coat.options{o.coat_idx, 2};
eps_  = P.coat.options{o.coat_idx, 3};
g = web_geometry(P, o.t_ins, k_ins);

t = (0:o.dt:o.n_sols*P.sol)';
N = numel(t);
env = environment_series(P, E, t, g, alpha, o.const_env);

% ---- internal dissipation schedule -------------------------------------
Q_int = P.load.baseline * ones(N,1);
if o.science && ~strcmp(o.mode, 'survival')
    tsol = mod(t, P.sol);
    t0 = P.load.scan_start_frac * P.sol;
    on = tsol >= t0 & tsol < t0 + o.scan_h*3600;
    Q_int(on) = P.load.science;
end
if ~isempty(o.Q_int_override), Q_int(:) = o.Q_int_override; end
Q_int = Q_int + o.Q_rhu;

% ---- heater set points (per time step) -----------------------------------
%   operational : operating band all sol (the 2023 requirement as written)
%   survival    : survival band all sol
%   scheduled   : operating band from warm-up start to scan end on science
%                 sols, survival band otherwise (proposed concept of ops)
T_on  = P.htr.on_K  * ones(N,1);
T_off = P.htr.off_K * ones(N,1);
if strcmp(o.mode, 'survival') || strcmp(o.mode, 'scheduled')
    in_window = false(N,1);
    if strcmp(o.mode, 'scheduled') && o.science
        tsol = mod(t, P.sol);
        t0 = P.load.scan_start_frac*P.sol - o.warmup_h*3600;
        in_window = tsol >= t0 & tsol < P.load.scan_start_frac*P.sol + o.scan_h*3600;
    end
    T_on(~in_window)  = P.htr.surv_on_K;
    T_off(~in_window) = P.htr.surv_off_K;
end

% ---- interior enthalpy <-> temperature (PCM plateau at Tm) ---------------
C_I  = P.int.C + o.m_pcm*(P.pcm.cp + P.pcm.container_frac*900);
Lat  = o.m_pcm * P.pcm.L;
Tm   = P.pcm.Tm;
T_of_H = @(H) (H < 0).*(Tm + H/C_I) + (H >= 0 & H <= Lat).*Tm + ...
              (H > Lat).*(Tm + (H - Lat)/C_I);
if o.T0 >= Tm, H = Lat + C_I*(o.T0 - Tm); else, H = C_I*(o.T0 - Tm); end

C_S = g.C_skin;
T_S = o.T0 - 40;
G   = g.G_ins;  Gl = P.leak.G;  h = E.h;  sg = P.sigma;

T_I_v = zeros(N,1); T_S_v = zeros(N,1); Qh_v = zeros(N,1);
Qins_v = zeros(N,1); Qleak_v = zeros(N,1); melt_v = zeros(N,1);
Qrad_v = zeros(N,1); Qconv_v = zeros(N,1); H_v = zeros(N,1);
htr_on = false; cut_out = false;

for n = 1:N
    T_I = T_of_H(H);
    % heater controller (hysteresis)
    if T_I < T_on(n), htr_on = true; elseif T_I > T_off(n), htr_on = false; end
    if t(n) >= o.stuck_on_after && ~cut_out
        htr_on = true;                                  % failed switch
        if T_I >= o.T_cutoff, cut_out = true; end      % cutoff opens and latches
    end
    if cut_out && t(n) >= o.stuck_on_after, htr_on = false; end
    if t(n) >= o.heater_off_after, htr_on = false; end
    Qh = o.P_htr * htr_on;

    Qins  = G  * (T_I - T_S);
    Qleak = Gl * (T_I - env.T_air(n));
    Qrad  = eps_*sg*( g.A_sky*(T_S^4 - env.T_sky(n)^4) + g.A_gnd*(T_S^4 - env.T_gnd(n)^4) );
    Qconv = h * g.A_out * (T_S - env.T_air(n));

    T_I_v(n) = T_I; T_S_v(n) = T_S; Qh_v(n) = Qh;
    Qins_v(n) = Qins; Qleak_v(n) = Qleak; Qrad_v(n) = Qrad; Qconv_v(n) = Qconv; H_v(n) = H;
    melt_v(n) = min(max(H/max(Lat,eps), 0), 1);

    H   = H   + o.dt * (Q_int(n) + Qh - Qins - Qleak);
    T_S = T_S + o.dt * (Qins + env.Q_sol(n) - Qrad - Qconv) / C_S;
end

R.t = t; R.T_I = T_I_v; R.T_S = T_S_v; R.Q_htr = Qh_v; R.Q_int = Q_int;
R.Q_ins = Qins_v; R.Q_leak = Qleak_v; R.Q_rad = Qrad_v; R.Q_conv = Qconv_v; R.H = H_v; R.melt = melt_v; R.env = env;
R.g = g; R.opts = o; R.C_I = C_I; R.T_on = T_on; R.T_off = T_off; R.Lat = Lat; R.E = E;

% ---- summary over the last two sols (periodic steady state) -------------
% Two sols are averaged because the bang-bang heater cycles do not divide a
% sol evenly; a single-sol window aliases by about +/-2 %.
nwin = min(2, o.n_sols - 1);
last = t >= (o.n_sols - nwin)*P.sol & t < o.n_sols*P.sol;
R.Tmin = min(T_I_v(last));
R.Tmax = max(T_I_v(last));
R.E_htr_Wh = sum(Qh_v(last)) * o.dt / 3600 / nwin;   % heater energy per sol
R.duty = mean(Qh_v(last) > 0);
R.Qhtr_avg = mean(Qh_v(last));
R.melt_max = max(melt_v(last));
R.T_skin_range = [min(T_S_v(last)) max(T_S_v(last))];
R.Q_sol_avg = mean(env.Q_sol(last));
% temperature extremes while the operating band is commanded (science window)
win = last & (T_on > P.htr.surv_on_K + 1);
if any(win)
    % ignore the warm-up ramp: evaluate from the scan start onward
    tsol = mod(t, P.sol);
    scan = win & tsol >= P.load.scan_start_frac*P.sol;
    R.Tmin_window = min(T_I_v(scan)); R.Tmax_window = max(T_I_v(scan));
else
    R.Tmin_window = NaN; R.Tmax_window = NaN;
end
end
