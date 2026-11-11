function env = environment_series(P, E, t, g, alpha, const_env)
%ENVIRONMENT_SERIES  Time series of boundary conditions for one case.
%
%   env = environment_series(P, E, t, g, alpha, const_env)
%     E          environment case struct (P.env.hot / cold / storm)
%     t          time vector since local midnight [s]
%     g          geometry struct from web_geometry
%     alpha      exterior solar absorptance [-]
%     const_env  true -> hold every boundary at its sol-mean value
%                (used by the verification tests)
%
%   Returns T_air, T_sky, T_gnd [K] and Q_sol [W] absorbed by the skin.

if nargin < 6, const_env = false; end
sol = P.sol;

T_mean = 0.5*(E.T_air_max + E.T_air_min);
T_amp  = 0.5*(E.T_air_max - E.T_air_min);
env.T_air = T_mean + T_amp*cos(2*pi*(t/sol - P.env.t_peak_frac));
env.T_gnd = env.T_air;                    % [ASM A-13]
env.T_sky = env.T_air - E.sky_dep;        % [ASM A-12]

S = mars_solar(E.Ls, P.site.lat_deg, E.tau, E.albedo, mod(t, sol), sol);
up = S.el > 0;
A_proj = zeros(size(t));
A_proj(up) = g.A_top*sind(S.el(up)) + g.Ho*cosd(S.el(up)) .* ...
    (g.Lo*abs(sind(S.az(up))) + g.Wo*abs(cosd(S.az(up))));
Q_beam    = S.Gb  .* A_proj;
Q_diffuse = S.Gdh .* (g.A_top + 0.5*g.A_sides);
Q_albedo  = E.albedo * S.Gh .* (g.A_bot + 0.5*g.A_sides);
env.Q_sol = alpha * (Q_beam + Q_diffuse + Q_albedo);
env.S = S;

if const_env
    env.T_air(:) = mean(env.T_air);
    env.T_gnd(:) = mean(env.T_gnd);
    env.T_sky(:) = mean(env.T_sky);
    env.Q_sol(:) = mean(env.Q_sol);
end
end
