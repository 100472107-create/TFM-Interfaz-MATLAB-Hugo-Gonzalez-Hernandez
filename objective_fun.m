function [F,auxvars] = objective_fun(theta, params)

alpha  = params.alpha;
x      = params.x;
xR     = params.xR;
lambda = params.lambda;
b      = params.b; 
k      = params.k;
clcd   = params.clcd;

phi = theta + alpha;

eT = 1e-3;
eR = xR/10;

f  = (2/pi)^2*acos(exp(-b/2*(1 -(x-eT))/(x*sin(phi))))*...
              acos(exp(-b/2*((x+eR)-xR)/(x*sin(phi))));

f = max(f,0);

a  = f/k*(k*cos(phi) + sin(phi))*(cos(phi) - x*lambda*sin(phi));
ap = a/(x*lambda)*(k*sin(phi) - cos(phi))/(k*cos(phi)+sin(phi));

F  = 8*lambda^2*x^3*(1-a)*ap;

auxvars.a   = a; 
auxvars.ap  = ap;
auxvars.phi = phi;
auxvars.f   = f;

UR2   = (1-a/f)^2 + lambda^2*x^2*(1+ap/f)^2;
auxvars.sigma = 8*x*(1-a)*a/(UR2*(clcd(1)*cos(phi) + clcd(2)*sin(phi)));

end