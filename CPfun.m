function CP = CPfun(lambda,thetaC,b,blade)

xvec     = blade.xvec;
xcuts    = blade.xcuts;
airfoils = blade.airfoils;

xR    = blade.xR;
edges = [xR, xcuts(:).', 1];            % [xR, x1, x2, ..., 1]
bin   = discretize(xvec, edges);         % 1..numel(proflabels)


polars = cell(size(airfoils));

for k = 1:numel(airfoils)
    polars{k} = read_polars(['data-', airfoils{k}, '.csv']);
end

options = optimoptions('fsolve','Display','off');

a   = zeros(size(xvec));
ap  = a ;
phi = a;

%% Initial guess for the solver

a0   = 0.1;
ap0  = 0.5;
phi0 = 0.6;

for j = 1:length(xvec)

    x         = xvec(j);
    polardata = polars{bin(j)};

    params.lambda     = lambda;
    params.thetac     = thetaC;
    params.b          = b;

    params.x          = x;

    params.xR         = xR;
    params.polardata  = polardata;
    params.sigma      = blade.sigma(j);
    params.thetaG     = blade.thetaG(j);

    sol     = fsolve(@(X) eqnsNew(X,params), [a0; ap0; phi0], options);

    a(j)   = sol(1);
    ap(j)  = sol(2);
    phi(j) = sol(3);

    a0   = a(j);
    ap0  = ap(j);
    phi0 = phi(j);

end

dCP = 8*lambda^2*xvec.^3.*(1-a).*ap;    % Power coeff per unit span
CP  = trapz(xvec, dCP);              % Global power coeff = int^1_x_R (dCP) dx

