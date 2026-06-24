function [F,extravars] = eqnsNew(X, params)

% Dependent variables:

a   = X(1);
ap  = X(2);
phi = X(3);

% Input parameters:

x          = params.x;
theta_C    = params.thetac;
xR         = params.xR;
b          = params.b;
lambda     = params.lambda;
polardata  = params.polardata;


thetaG     = params.thetaG;
sigma      = params.sigma;

% Definition of tip-losses factor (eT and eR are safeguards) and absolute velocity

eT = 1e-3;      
eR = xR/10;     

f     = (2/pi)^2*acos(exp(-b/2*(1 -(x-eT))/(x*sin(phi))))*...
                 acos(exp(-b/2*((x+eR)-xR)/(x*sin(phi))));
UR2   = (1-a/f)^2 + lambda^2*x^2*(1+ap/f)^2;

% Read polars (in terms of alpha)

alpha = phi - (thetaG + theta_C);

cl = interp1(polardata(:,1), polardata(:,2), rad2deg(alpha),'linear','extrap');
cd = interp1(polardata(:,1), polardata(:,3), rad2deg(alpha),'linear','extrap');

% Lissaman correction in thrust term

aT  = 0.3262;
CT1 = 1.816;
dCT = 8*x*(1-a)*a*(a<aT) +...
      2*x*(CT1 - 4*(sqrt(CT1) - 1)*(1-a))*(a>=aT);

% Equilibrium + definition of phi angle

F(1) = dCT - sigma*UR2*(cl*cos(phi) + cd*sin(phi));
F(2) = 8*x^2*lambda*(1-a)*ap - sigma*UR2*(cl*sin(phi) - cd*cos(phi));
F(3) = phi - atan2(1-a/f,lambda*x*(1+ap/f));

% Pack extra output vars in a struct

extravars.alpha  = alpha;
extravars.cl     = cl;
extravars.cd     = cd;
extravars.f      = f;
extravars.UR     = sqrt(UR2);

end
