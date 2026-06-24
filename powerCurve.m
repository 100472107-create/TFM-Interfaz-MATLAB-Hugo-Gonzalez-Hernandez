function out = powerCurve(R, PN, ORlim, lambdaop, thetaCop, CPmax, ...
                           etaM, etaE, Vin, Vout, blade, b, stopFcn)
% powerCurve  Calcula la curva de potencia de un aerogenerador.

% INPUTS:
%   R        : radio del rotor [m]
%   PN       : potencia nominal [W]
%   ORlim    : velocidad límite de punta de pala [m/s]
%   lambdaop
%   thetaCop : ángulo de paso óptimo [rad]
%   CPmax    : coeficiente de potencia máximo [-]
%   etaM     : eficiencia mecánica [-]
%   etaE     : eficiencia eléctrica [-]
%   Vin      : velocidad de arranque [m/s]
%   Vout     : velocidad de parada [m/s]
%   blade    : struct de pala
%   b        : número de palas [-]

if nargin < 13 || isempty(stopFcn)
    stopFcn = @() false;  
end

rho = 1.225;

% Calcular KV y VN
KV    = KVpow3(R, PN, ORlim, lambdaop, thetaCop, etaM, etaE, blade, b);
VN    = VNpow3(R, KV, PN, lambdaop, thetaCop, etaM, etaE, blade, b);

ORNL   = lambdaop * KV * VN;
VORN   = KV * VN;
P_VORN = 0.5 * rho * pi * R^2 * VORN^3 * CPmax * etaM * etaE;

% Vector de velocidades
dV = 0.05;
V  = [Vin:dV:KV*VN, KV*VN+dV:dV:VN, VN+dV:dV:Vout];

C = 0.5 * rho * pi * R^2;

% Curva de potencia
P = zeros(size(V));

P(V >= Vin & V <= VN*KV) = C * V(V >= Vin & V <= VN*KV).^3 * CPmax * etaM * etaE;
P(V > VN   & V <= Vout)  = PN;

% Región V > VORN y V <= VN (solo cuando KV < 1)
out.stopped = false;
if KV < 1
    vv = V(V > VN*KV & V <= VN);
    if ~isempty(vv)
        Pvv = zeros(size(vv));
        for i = 1:length(vv)
            if stopFcn()
                out.stopped = true;
                break;
            end
            lambda = lambdaop * KV * VN / vv(i);
            CP     = CPfun(lambda, thetaCop, b, blade);
            Pvv(i) = C * vv(i)^3 * CP * etaM * etaE;
        end
        P(V > VN*KV & V <= VN) = Pvv;
    end
end

% Recorte: ningún punto puede superar PN
P = min(P, PN);

out.V      = V;
out.P      = P;
out.VN     = VN;
out.KV     = KV;
out.VORN   = VORN;
out.ORNL   = ORNL;
out.P_VORN = P_VORN;
out.R      = R;

end
