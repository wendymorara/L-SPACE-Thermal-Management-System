function [E_Wh, P_avg, P_t] = solar_array_energy(P, E)
%SOLAR_ARRAY_ENERGY  Energy per sol from the two tilted side panels.
%
%   [E_Wh, P_avg, P_t] = solar_array_energy(P, E)
%   Used only to check the Thermal <-> Electrical Power interface: can the
%   array supply the heater energy the thermal design asks for?
%
%   Two panels (P.sa.area total) tilted P.sa.tilt from horizontal, facing
%   opposite azimuths. Irradiance on a tilted plane = beam*cos(incidence)
%   + isotropic diffuse*(1+cos(beta))/2 + ground albedo*Gh*(1-cos(beta))/2.

t = linspace(0, P.sol, 2000)';
S = mars_solar(E.Ls, P.site.lat_deg, E.tau, E.albedo, t, P.sol);
b = P.sa.tilt;  z = 90 - S.el;
P_t = zeros(size(t));
for az_p = [0 180]                              % the two panels
    cos_i = cosd(b)*cosd(z) + sind(b)*sind(z).*cosd(S.az - az_p);
    G_tilt = S.Gb.*max(cos_i,0) + S.Gdh*(1+cosd(b))/2 + E.albedo*S.Gh*(1-cosd(b))/2;
    P_t = P_t + G_tilt .* (P.sa.area/2) * P.sa.eff * P.sa.derate;
end
P_avg = mean(P_t);
E_Wh  = P_avg * P.sol / 3600;
end
