function [Pav3,Pmax] = avePow3(vin,vout,vn,KV,R,PN,CPmax,lambdaop,thetaCop,etaM,etaE,blade,b,k,c)

nv = 200;
ab = (vout-vin)/nv;
v  = vin:ab:vout;


rho = 1.225;    
K   = (1/2)*rho*pi*R^2;

P (v<vin)             = 0;
P (v>=vin & v<=vn*KV) = K*v(v>=vin & v<=vn*KV).^3*CPmax*etaM*etaE;

P (v>vn & v<=vout) = PN;
P (v>vout)         = 0;

% v >Vlim & <vn
if (KV<1)
    vv = v(v>vn*KV & v<=vn);
    if ~isempty(vv)
        for i = 1:length(vv)
            
            lambda = lambdaop*KV*vn/vv(i);
            CP     = CPfun(lambda,thetaCop,b,blade);
            Pvv(i) = K*vv(i)^3*CP*etaM*etaE;
        end
        P(v>vn*KV & v<=vn) = Pvv;
    end
end

pWeibull = k.*v.^(k-1)/(c^k).*exp(-(v/c).^k); % Weibull

Pv = P.*pWeibull;

Pav3 = trapz(v,Pv);
Pmax = max(Pv);
