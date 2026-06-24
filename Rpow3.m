function R = Rpow3(vn,KV,PN,lambdaop,thetaCop,etaM,etaE,blade,b)

rho = 1.225;

CPn = CPfun(lambdaop*KV,thetaCop,b,blade);

R   = (2*PN/(etaM*etaE*rho*pi*CPn*vn^3))^(1/2);
