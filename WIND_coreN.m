function out = WIND_coreN(airfoils, xcuts, cfg)

% Core general para N perfiles y N-1 cortes.

% airfoils: cellstr {1xN} ej {'DU40','DU25','S825',...}
% xcuts: [1x(N-1)] cortes crecientes en x=r/R
% cfg: struct con b,xR,NX,lambdavec

if nargin < 3
    error('Uso: out = WIND_coreN(airfoils, xcuts, cfg)');
end

N = numel(airfoils);
if numel(xcuts) ~= N-1
    error('WIND_coreN: xcuts debe tener N-1 elementos.');
end

b = cfg.b;
xR = cfg.xR;
NX = cfg.NX;
lambdavec = cfg.lambdavec;

xcuts = sort(xcuts(:).');
if any(diff(xcuts) <= 0)
    error('WIND_coreN: xcuts deben ser estrictamente crecientes.');
end

% Grid radial
x1 = xR + 1e-12;
x2 = 1 - 1e-4;
xi = linspace(0,1,NX);
xvec = 0.5*(x1+x2) + 0.5*(x2-x1)*cos(pi*(1 - xi));

% Asignación de perfil por tramos
edges = [xR, xcuts, 1];
bin = discretize(xvec, edges);  % 1..N

% Leer polares por perfil y extraer óptimo (max Cl/Cd)
kop = zeros(1,N);
alphaop = zeros(1,N);
clop = zeros(1,N);
cdop = zeros(1,N);

for i = 1:N
    fn = ['data-', airfoils{i}, '.csv'];
    pol = read_polars(fn);
    [kop(i), I] = max(pol(:,2)./pol(:,3));
    alphaop(i) = pol(I,1)*pi/180;
    clop(i) = pol(I,2);
    cdop(i) = pol(I,3);
end

% Expandir por estación radial
alpha = zeros(1,NX);
k = zeros(1,NX);
clcd = zeros(2,NX);
for j = 1:NX
    idx = bin(j);
    alpha(j) = alphaop(idx);
    k(j) = kop(idx);
    clcd(1,j) = clop(idx);
    clcd(2,j) = cdop(idx);
end

% Optimización por lambda
params.xR = xR;
params.b  = b;

theta_range = [-0.1, pi];
NL = numel(lambdavec);

a      = zeros(NL,NX);
ap     = zeros(NL,NX);
phi    = zeros(NL,NX);
thetaG = zeros(NL,NX);
sigma  = zeros(NL,NX);
f      = zeros(NL,NX);
CP     = zeros(1,NL);

opt = optimoptions('fmincon','Display','off','Algorithm','interior-point');

for i = 1:NL
    params.lambda = lambdavec(i);
    theta0 = 0.5;

    for j = 1:NX
        params.x     = xvec(j);
        params.alpha = alpha(j);
        params.k     = k(j);
        params.clcd  = clcd(:,j);

        thetas = fmincon(@(th) -objective_fun(th,params), theta0, ...
                         [],[],[],[], theta_range(1), theta_range(2), [], opt);

        [~, aux] = objective_fun(thetas, params);

        a(i,j)      = aux.a;
        ap(i,j)     = aux.ap;
        phi(i,j)    = aux.phi;
        thetaG(i,j) = thetas;
        sigma(i,j)  = aux.sigma;
        f(i,j)      = aux.f;

        theta0 = thetas;
    end

    dCP   = 8*lambdavec(i)^2*xvec.^3.*(1-a(i,:)).*ap(i,:);
    CP(i) = trapz(xvec, dCP);
end

[CPstar, idxStar] = max(CP);
lambdaStar = lambdavec(idxStar);

out = struct();
out.b = b;
out.xR = xR;
out.NX = NX;
out.airfoils = airfoils;
out.xcuts = xcuts;

out.xvec = xvec;
out.lambdavec = lambdavec;
out.CP = CP;
out.lambdaStar = lambdaStar;
out.CPstar = CPstar;

out.aStar = a(idxStar,:);
out.apStar = ap(idxStar,:);
out.phiStar = phi(idxStar,:);
out.thetaGStar = thetaG(idxStar,:);
out.sigmaStar = sigma(idxStar,:);
out.fStar = f(idxStar,:);
end
