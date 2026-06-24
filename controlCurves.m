function out = controlCurves(R, PN, ORlim, lambdaop, thetaCop, CPmax, ...
                              etaM, etaE, Vin, Vout, blade, b)

rho  = 1.225;
NV   = 25;
NVf  = 15;

VN0  = (PN/(etaM*etaE) / (0.5*rho*pi*R^2*CPmax))^(1/3);
ORN0 = lambdaop * VN0;

    function tc = robustFzero(lam, CPobj, bracket_lo, bracket_hi, fallback)
        f = @(tc) CPfun(lam, tc, b, blade) - CPobj;
        try
            if f(bracket_lo)*f(bracket_hi) < 0
                tc = fzero(f, [bracket_lo, bracket_hi]);
                return;
            end
            tg = linspace(bracket_lo, bracket_hi, 32);
            fg = arrayfun(f, tg);
            idx = find(diff(sign(fg)) ~= 0, 1);
            if ~isempty(idx)
                tc = fzero(f, [tg(idx), tg(idx+1)]);
            else
                tc = fallback;
            end
        catch
            tc = fallback;
        end
    end

% =====================================================================
if (ORlim <= ORN0)
% =====================================================================

    VORN = ORlim / lambdaop;
    KV   = KVpow3(R, PN, ORlim, lambdaop, thetaCop, etaM, etaE, blade, b);
    VN   = (ORlim/lambdaop) / KV;

    V1  = linspace(Vin,          VORN,  NV);
    V2  = linspace(VORN*1.001,   VN,    NV);
    V3  = linspace(VN*1.001,     Vout,  NVf);

    % Tramos para curva SIN restricción
    V12 = linspace(VORN*1.001,   VN0,   NV);   
    V3s = linspace(VN0*1.001,    Vout,  NVf); 

    % V22 solo si VN0 < VN
    if VN0 < VN
        V22 = linspace(VN0*1.001, VN, NVf);
    else
        V22 = [];
    end

    % --- Intervalo 1: Vin ≤ V ≤ VORN
    lambda1 = lambdaop * ones(1,NV);
    thetaC1 = thetaCop * ones(1,NV);
    Omega1  = V1 * lambdaop / R;
    P1      = 0.5*etaM*etaE*rho*pi*R^2*CPmax * V1.^3;
    CP1     = CPmax * ones(1,NV);
    Q1      = P1 ./ Omega1;
    CQ1     = CP1 ./ lambda1;

    % --- Intervalo 2 CON rest.: VORN < V ≤ VN 
    lambda2 = ORlim ./ V2;
    thetaC2 = thetaCop * ones(1,NV);
    CP2     = zeros(1,NV);
    for i = 1:NV
        CP2(i) = CPfun(lambda2(i), thetaCop, b, blade);
    end
    P2     = 0.5*etaM*etaE*rho*pi*R^2 * CP2 .* V2.^3;
    Omega2 = ORlim/R * ones(1,NV);
    Q2     = P2 ./ Omega2;
    CQ2    = CP2 ./ lambda2;

    % --- Intervalo 3 CON rest.: VN < V ≤ Vout
    lambda3 = ORlim ./ V3;
    Omega3  = ORlim/R * ones(1,NVf);
    CPobj3  = PN/(etaM*etaE) ./ (0.5*rho*pi*R^2 * V3.^3);
    P3      = PN * ones(1,NVf);
    Q3      = PN/(ORlim/R) * ones(1,NVf);
    CP3     = CPobj3;
    CQ3     = CP3 ./ lambda3;

    thetaC3Pitchvect = zeros(1,NVf);
    thetaC3ASvect    = zeros(1,NVf);
    thetaC1P  = thetaCop;   thetaC2P  = 30*pi/180;
    thetaC1AS = -30*pi/180; thetaC2AS = thetaCop;
    for i = 1:NVf
        thetaC3Pitchvect(i) = robustFzero(lambda3(i), CPobj3(i), thetaC1P,  thetaC2P,  thetaC1P);
        thetaC1P  = thetaC3Pitchvect(i);
        thetaC3ASvect(i)    = robustFzero(lambda3(i), CPobj3(i), thetaC1AS, thetaC2AS, thetaC2AS);
        thetaC2AS = thetaC3Pitchvect(i);
    end

    % Tramo 12 SIN rest.: VORN → VN0 
    lambda12 = lambdaop * ones(1,NV);
    thetaC12 = thetaCop * ones(1,NV);
    P12      = 0.5*etaM*etaE*rho*pi*R^2*CPmax * V12.^3;
    CP12     = CPmax * ones(1,NV);
    Omega12  = V12 * lambdaop / R;
    Q12      = P12 ./ Omega12;
    CQ12     = CPmax ./ lambda12;

    % Tramo 22 SIN rest.
    if ~isempty(V22)
        Omega22  = lambdaop*VN0/R * ones(1,NVf);
        lambda22 = lambdaop*VN0 ./ V22;
        CPobj22  = PN/(etaM*etaE) ./ (0.5*rho*pi*R^2 * V22.^3);
        P22      = PN * ones(1,NVf);
        Q22      = PN/(lambdaop*VN0/R) * ones(1,NVf);
        CP22     = CPobj22;
        CQ22     = CP22 ./ lambda22;

        thetaC22Pitchvect = zeros(1,NVf);
        thetaC22ASvect    = zeros(1,NVf);
        thetaC1P  = thetaCop;   thetaC2P  = 30*pi/180;
        thetaC1AS = -30*pi/180; thetaC2AS = thetaCop;
        for i = 1:NVf
            thetaC22Pitchvect(i) = robustFzero(lambda22(i), CPobj22(i), thetaC1P,  thetaC2P,  thetaC1P);
            thetaC1P  = thetaC22Pitchvect(i);
            thetaC22ASvect(i)    = robustFzero(lambda22(i), CPobj22(i), thetaC1AS, thetaC2AS, thetaC2AS);
            thetaC2AS = thetaC22Pitchvect(i);
        end
    else
        V22=[]; Omega22=[]; lambda22=[]; P22=[]; Q22=[]; CP22=[]; CQ22=[];
        thetaC22Pitchvect=[]; thetaC22ASvect=[];
    end

    % Tramo 3 SIN rest.
    lambda3s = lambdaop*VN0 ./ V3s;
    Omega3s  = lambdaop*VN0/R * ones(1,NVf);
    CPobj3s  = PN/(etaM*etaE) ./ (0.5*rho*pi*R^2 * V3s.^3);
    P3s      = PN * ones(1,NVf);
    Q3s      = PN/(lambdaop*VN0/R) * ones(1,NVf);
    CP3s     = CPobj3s;
    CQ3s     = CP3s ./ lambda3s;

    thetaC3sPitchvect = zeros(1,NVf);
    thetaC3sASvect    = zeros(1,NVf);
    
    if ~isempty(thetaC22Pitchvect)
        thetaC1P  = thetaC22Pitchvect(end);
        thetaC2AS_init = thetaC22Pitchvect(end);
    else
        thetaC1P  = thetaCop;
        thetaC2AS_init = thetaCop;
    end
    thetaC2P  = 30*pi/180;
    thetaC1AS = -30*pi/180;
    thetaC2AS = thetaC2AS_init;
    for i = 1:NVf
        thetaC3sPitchvect(i) = robustFzero(lambda3s(i), CPobj3s(i), thetaC1P,  thetaC2P,  thetaC1P);
        thetaC1P  = thetaC3sPitchvect(i);
        thetaC3sASvect(i)    = robustFzero(lambda3s(i), CPobj3s(i), thetaC1AS, thetaC2AS, thetaC2AS);
        thetaC2AS = thetaC3sPitchvect(i);
    end

    % Ensamblar curva SIN restricción completa
    V1221vect       = [V1,   V12,  V22,  V3s];
    lambda1221      = [lambda1, lambda12, lambda22, lambda3s];
    thetaC1221Pitch = [thetaC1, thetaC12, thetaC22Pitchvect, thetaC3sPitchvect];
    thetaC1221AS    = [thetaC1, thetaC12, thetaC22ASvect,    thetaC3sASvect];
    P1221           = [P1,   P12,  P22,  P3s];
    CP1221          = [CP1,  CP12, CP22, CP3s];
    Omega1221       = [Omega1, Omega12, Omega22, Omega3s];
    Q1221           = [Q1,   Q12,  Q22,  Q3s];
    CQ1221          = [CQ1,  CQ12, CQ22, CQ3s];

% =====================================================================
else
% =====================================================================
%   Caso SIN limitación de velocidad de punta
% =====================================================================

    VN   = (PN/(etaE*etaM) / (0.5*rho*pi*R^2*CPmax))^(1/3);
    VORN = VN;

    V1 = linspace(Vin,        VN,   NV);
    V3 = linspace(VN*1.001, Vout,   NVf);
    V2=[]; V12=[]; V22=[];

    lambda1 = lambdaop * ones(1,NV);
    thetaC1 = thetaCop * ones(1,NV);
    Omega1  = V1 * lambdaop / R;
    P1      = 0.5*etaM*etaE*rho*pi*R^2*CPmax * V1.^3;
    CP1     = CPmax * ones(1,NV);
    Q1      = P1 ./ Omega1;
    CQ1     = CP1 ./ lambda1;

    P2=[]; thetaC2=[]; Omega2=[]; Q2=[]; CP2=[]; CQ2=[]; lambda2=[];

    lambda3 = VN0*lambdaop ./ V3;
    Omega3  = lambdaop*VN/R * ones(1,NVf);
    CPobj3  = PN/(etaM*etaE) ./ (0.5*rho*pi*R^2 * V3.^3);
    P3      = PN * ones(1,NVf);
    Q3      = PN/(lambdaop*VN/R) * ones(1,NVf);
    CP3     = CPobj3;
    CQ3     = CP3 ./ lambda3;

    thetaC3Pitchvect = zeros(1,NVf);
    thetaC3ASvect    = zeros(1,NVf);
    thetaC1P  = thetaCop;   thetaC2P  = 30*pi/180;
    thetaC1AS = -30*pi/180; thetaC2AS = thetaCop;
    for i = 1:NVf
        thetaC3Pitchvect(i) = robustFzero(lambda3(i), CPobj3(i), thetaC1P,  thetaC2P,  thetaC1P);
        thetaC1P  = thetaC3Pitchvect(i);
        thetaC3ASvect(i)    = robustFzero(lambda3(i), CPobj3(i), thetaC1AS, thetaC2AS, thetaC2AS);
        thetaC2AS = thetaC3Pitchvect(i);
    end

    % Sin limitación
    V1221vect=[]; lambda1221=[]; thetaC1221Pitch=[]; thetaC1221AS=[];
    P1221=[]; CP1221=[]; Omega1221=[]; Q1221=[]; CQ1221=[];

end

out.Vvect           = [V1, V2, V3];
out.lambda          = [lambda1, lambda2, lambda3];
out.thetaCPitch     = [thetaC1, thetaC2, thetaC3Pitchvect];
out.thetaCAS        = [thetaC1, thetaC2, thetaC3ASvect];
out.Pvect           = [P1,  P2,  P3];
out.CPvect          = [CP1, CP2, CP3];
out.Omegavect       = [Omega1, Omega2, Omega3];
out.Qvect           = [Q1,  Q2,  Q3];
out.CQvect          = [CQ1, CQ2, CQ3];

out.V1plus2         = [V1, V2];
out.thetaC1plus2    = [thetaC1, thetaC2];

out.V1221vect       = V1221vect;
out.lambda1221      = lambda1221;
out.thetaC1221Pitch = thetaC1221Pitch;
out.thetaC1221AS    = thetaC1221AS;
out.P1221           = P1221;
out.CP1221          = CP1221;
out.Omega1221       = Omega1221;
out.Q1221           = Q1221;
out.CQ1221          = CQ1221;

out.VN              = VN;
out.VORN            = VORN;
out.ORlimActive     = (ORlim <= ORN0);

end
