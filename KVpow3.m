function KV = KVpow3(R,Pn,ORlim,lambdaop,thetaCop,etaM,etaE,blade,b)
          

f1 = @(x)eqKVpow3(x,R,Pn,ORlim,lambdaop,thetaCop,etaM,etaE,blade,b); 

options = optimset('Display','off');    

KV = fzero(f1,0.8,options);
end


function F = eqKVpow3(x,R,Pn,ORlim,lambdaop,thetaCop,etaM,etaE,blade,b)

    rho = 1.225;
   
    KV = x;
    vn = ORlim/(KV*lambdaop);

    CP = CPfun(lambdaop*KV,thetaCop,b,blade);
    
    F = Pn/(etaM*etaE)-(1/2)*rho*pi*R^2*vn^3*CP;
end
    
   