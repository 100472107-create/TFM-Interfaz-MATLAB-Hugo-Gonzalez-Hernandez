function Vn = VNpow3(R,KV,PN,lambdaop,thetaCop,etaM,etaE,blade,b)

rho = 1.225;

CPn = CPfun(lambdaop*KV,thetaCop,b,blade);

Vn = (2*PN/(etaM*etaE*rho*pi*CPn*R^2))^(1/3);