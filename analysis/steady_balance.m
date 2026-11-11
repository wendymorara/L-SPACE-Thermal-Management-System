function s = steady_balance(P, g, coat_idx, T_I, T_air, T_sky, T_gnd, h, Q_sol, Q_int)
%STEADY_BALANCE  Algebraic (hand-calculation) energy balance of the WEB.
%
%   s = steady_balance(P, g, coat_idx, T_I, T_air, T_sky, T_gnd, h, Q_sol, Q_int)
%   Holds the interior at T_I and solves the outer-skin balance
%
%     G_ins (T_I - T_S) + Q_sol = eps*sigma*[A_sky (T_S^4 - T_sky^4)
%                                 + A_gnd (T_S^4 - T_gnd^4)] + h A (T_S - T_air)
%
%   for the skin temperature T_S, then returns the heat the interior loses
%   and the heater power needed to replace it:
%
%     Q_loss = G_ins (T_I - T_S) + G_leak (T_I - T_air)
%     P_req  = max(Q_loss - Q_int, 0)

eps_ = P.coat.options{coat_idx, 3};
f = @(Ts) g.G_ins*(T_I - Ts) + Q_sol ...
    - eps_*P.sigma*(g.A_sky*(Ts^4 - T_sky^4) + g.A_gnd*(Ts^4 - T_gnd^4)) ...
    - h*g.A_out*(Ts - T_air);
s.T_S    = fzero(f, [50 450]);
s.Q_ins  = g.G_ins*(T_I - s.T_S);
s.Q_leak = P.leak.G*(T_I - T_air);
s.Q_loss = s.Q_ins + s.Q_leak;
s.P_req  = max(s.Q_loss - Q_int, 0);
end
