function H = enthalpy_from_T(T, C, Lat, Tm)
%ENTHALPY_FROM_T  Inverse of the interior enthalpy model in simulate_web.
if T < Tm, H = C*(T - Tm); else, H = Lat + C*(T - Tm); end
end
