function S = mars_solar(Ls, lat, tau, albedo, t, sol)
%MARS_SOLAR  Solar geometry and irradiance on the Mars surface.
%
%   S = mars_solar(Ls, lat, tau, albedo, t, sol)
%     Ls      areocentric solar longitude [deg]
%     lat     latitude [deg]
%     tau     atmospheric optical depth [-]
%     albedo  surface albedo, valid range 0.1 - 0.4 [-]
%     t       time since local midnight [s] (vector)
%     sol     length of a sol [s]
%
%   Returns struct S with fields (vectors the size of t):
%     el   solar elevation [deg]       az  solar azimuth from south, +west [deg]
%     Gob  top-of-atmosphere beam irradiance [W/m^2] (scalar)
%     Gb   direct beam, normal to the sun [W/m^2]
%     Gh   global irradiance on a horizontal surface [W/m^2]
%     Gbh  direct beam on a horizontal surface [W/m^2]
%     Gdh  diffuse on a horizontal surface [W/m^2]
%
%   Method: Appelbaum & Flood, "Solar radiation on Mars", NASA TM-102299
%   (1989) and updates NASA TM-103623 (1990), TM-105216 (1991). The
%   normalized net-flux function uses the published polynomial fit; the
%   coefficient tables were cross-checked against the open-source marsrad
%   package (Labreche, GPL-3). Polynomial error is up to ~7% for zenith
%   angles >= 80 deg.

e   = 0.093377;   % Mars orbital eccentricity
LsP = 248;        % Ls of perihelion [deg]
Mb  = 590;        % mean top-of-atmosphere irradiance at Mars [W/m^2]

S.Gob = Mb * (1 + e*cosd(Ls - LsP))^2 / (1 - e^2)^2;

delta = asind(sind(24.936) * sind(Ls));        % solar declination [deg]
omega = 360 * t / sol - 180;                    % hour angle [deg]

sin_el = sind(lat)*sind(delta) + cosd(lat)*cosd(delta)*cosd(omega);
S.el = asind(sin_el);
S.az = atan2d(sind(omega), cosd(omega)*sind(lat) - tand(delta)*cosd(lat));

z  = 90 - S.el;
up = S.el > 0;

S.Gb  = zeros(size(t));
S.Gh  = zeros(size(t));
S.Gb(up) = S.Gob * exp(-tau ./ cosd(z(up)));
S.Gh(up) = S.Gob * cosd(z(up)) .* netflux_poly(z(up), tau, albedo);
S.Gbh = S.Gb .* max(cosd(z), 0);
S.Gdh = max(S.Gh - S.Gbh, 0);
end

function p = netflux_poly(z, tau, al)
% Normalized net flux divided by (1 - albedo): sum p(i,j,k) tau^i (z/100)^j al^k
% Rows j = 0..5 (powers of z/100); columns i = 0..5 (powers of tau).
K0 = [ 1.002800  -0.228681   0.019613   0.000231  -0.000130   0.000003;
      -0.450073   1.335955  -1.131691   0.402126  -0.063967   0.003758;
       5.566705 -16.912405  13.739701  -4.756079   0.743740  -0.043159;
     -22.471579  64.909973 -52.509470  17.997548  -2.786548   0.160340;
      36.334497 -101.800319 79.895539 -26.762885   4.074117  -0.231476;
     -20.420490  53.207148 -39.949537  12.977108  -1.931169   0.107837];
K1 = [ 0.009814   0.226139  -0.117733   0.030579  -0.004090   0.000218;
      -0.156701   0.396821  -0.313648   0.099227  -0.013508   0.000651;
       1.361122  -3.758111   3.007907  -0.987457   0.141693  -0.007320;
      -4.365924  12.539250 -10.394165   3.486452  -0.513123   0.027401;
       5.991693 -17.498138  14.291370  -4.765323   0.703675  -0.037960;
      -2.915099   8.275686  -6.593125   2.173999  -0.320308   0.017335];
p = zeros(size(z));
zz = z / 100;
for j = 0:5
    for i = 0:5
        p = p + (K0(j+1,i+1) + K1(j+1,i+1)*al) * tau^i * zz.^j;
    end
end
end
