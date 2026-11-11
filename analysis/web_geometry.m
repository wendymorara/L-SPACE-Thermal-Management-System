function g = web_geometry(P, t_ins, k_ins)
%WEB_GEOMETRY  Areas and conductances of the insulated Warm Electronics Box.
%
%   g = web_geometry(P, t_ins, k_ins)
%     t_ins  insulation thickness [m]
%     k_ins  insulation effective thermal conductivity [W/m/K]
%
%   The insulation shell's conductance uses the geometric-mean area of the
%   inner and outer surfaces, the standard correction for a thick box wall.

L = P.web.L; W = P.web.W; H = P.web.H;
g.A_in = 2*(L*W + L*H + W*H);

Lo = L + 2*t_ins; Wo = W + 2*t_ins; Ho = H + 2*t_ins;
g.Lo = Lo; g.Wo = Wo; g.Ho = Ho;
g.A_top   = Lo*Wo;
g.A_bot   = Lo*Wo;
g.A_sides = 2*(Lo*Ho + Wo*Ho);
g.A_out   = g.A_top + g.A_bot + g.A_sides;

% View-factor-weighted areas: top sees sky, bottom sees ground,
% vertical sides see half sky / half ground.
g.A_sky = g.A_top + 0.5*g.A_sides;
g.A_gnd = g.A_bot + 0.5*g.A_sides;

if t_ins > 0
    g.G_ins = k_ins * sqrt(g.A_in * g.A_out) / t_ins;   % [W/K]
else
    g.G_ins = Inf;
end
g.V_ins = Lo*Wo*Ho - L*W*H;                              % insulation volume [m^3]
g.C_skin = g.A_out * P.skin.t_sheet * P.skin.rho * P.skin.cp;  % [J/K]
end
