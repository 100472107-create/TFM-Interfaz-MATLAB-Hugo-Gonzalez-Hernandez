function WIND_UI_live()

%% Estado compartido entre pestañas
appState = struct();
stopFlag = false;   % flag compartido para interrumpir bucles
appState.lambdaop = NaN;
appState.CPmax    = NaN;
appState.thetaCop = 0;
appState.blade    = [];
appState.b        = 3;
appState.resOpt   = [];   % resultados Optimización
appState.resAnal  = [];   % resultados Análisis
appState.resPC    = [];   % resultados Potencia & Control

%% Buscar perfiles disponibles
csvFiles = dir('data-*.csv');
if isempty(csvFiles)
    fig0 = uifigure('Visible','off');
    uialert(fig0, 'No se han encontrado archivos "data-*.csv" en la carpeta actual.', 'Faltan polares');
    delete(fig0);
    return;
end

airfoilNames = cell(1,numel(csvFiles));
for i = 1:numel(csvFiles)
    nm = csvFiles(i).name;
    nm = strrep(nm,'data-','');
    nm = strrep(nm,'.csv','');
    airfoilNames{i} = nm;
end
airfoilNames = sort(airfoilNames);

%% LISTAS BASE
allNames = string(airfoilNames);

% L1: RAÍZ (3 tramos)
L1_raiz = ["FX77-W-400","FX77-W-500","DU35","DU40","DU00-W2-350","FFA-W3-330blend","FFA-W3-360"];
L1 = allNames(ismember(allNames, L1_raiz));

% L2: ZONA MEDIA (3 tramos)
L2_zona_media = ["S809","S818","S815","DU25","DU30","DU91-W2-250","DU97-W-300","FFA-W3-211","FFA-W3-241","FFA-W3-270blend","FFA-W3-301","DU08-W-210","S814"];
L2 = allNames(ismember(allNames, L2_zona_media));

% L3: Punta (3 tramos)
L3_punta = ["NACA63215","NACA63618","RISOA18","NACA0012","S825","S826"];
L3 = allNames(ismember(allNames, L3_punta));

% L4: RAÍZ EXTERNA (4 tramos)
L4_raiz_externa = ["S815","DU25","DU30","DU91-W2-250","DU97-W-300","FFA-W3-270blend","FFA-W3-301"];
L4 = allNames(ismember(allNames, L4_raiz_externa));

% L5: ZONA MEDIA (4 tramos)
L5_zona_media = ["FFA-W3-211","FFA-W3-241","S809","S818","S814","DU08-W-210"];
L5 = allNames(ismember(allNames, L5_zona_media));

% L6: RAÍZ INTERNA(5 tramos)
L6_raiz_interna = ["FX77-W-400","FX77-W-500","DU40"];
L6 = allNames(ismember(allNames, L6_raiz_interna));

% L7: RAÍZ EXTERNA(5 tramos)
L7_raiz_externa = ["DU35","DU00-W2-350","FFA-W3-330blend","FFA-W3-360"];
L7 = allNames(ismember(allNames, L7_raiz_externa));

% Si alguna lista queda vacía:
if isempty(L1), L1 = allNames; end
if isempty(L2), L2 = allNames; end
if isempty(L3), L3 = allNames; end
if isempty(L4), L4 = allNames; end
if isempty(L5), L5 = allNames; end
if isempty(L6), L6 = allNames; end
if isempty(L7), L7 = allNames; end

%% Parámetros fijos (editables desde pestaña Opciones avanzadas)
cfg = struct();
cfg.b        = 3;
cfg.xR       = 0.05;
cfg.NX       = 80;
cfg.lambdaLo = 4;
cfg.lambdaHi = 11;
cfg.rho      = 1.225;
cfg.etaM     = 0.95;
cfg.etaE     = 0.95;
cfg.lambdavec = linspace(cfg.lambdaLo, cfg.lambdaHi, 60);

%% UI
fig = uifigure('Name','WIND - UI (N perfiles, cortes)','Position',[80 80 1200 700]);

gl = uigridlayout(fig,[1 2]);
gl.ColumnWidth = {360,'1x'};
gl.RowHeight = {'1x'};

pLeft = uipanel(gl,'Title','Inputs');  pLeft.Layout.Row = 1; pLeft.Layout.Column = 1;
pRight= uipanel(gl,'Title','Plots');   pRight.Layout.Row= 1; pRight.Layout.Column= 2;

% Panel izquierdo: TabGroup
glLeft = uigridlayout(pLeft,[1 1]);
glLeft.Padding = [0 0 0 0];
tg = uitabgroup(glLeft);
tabOpt  = uitab(tg,'Title','Optimización');
tabAnal = uitab(tg,'Title','Análisis');
tabPC   = uitab(tg,'Title','Potencia & Control');
tabAdv  = uitab(tg,'Title','⚙ Opciones');

% ================================================================
%  TAB 1 - OPTIMIZACIÓN 
% ================================================================
gL = uigridlayout(tabOpt,[7 2]);
gL.ColumnWidth = {130,'1x'};
gL.RowHeight   = {28, 10, '1x', 10, 40, 28, 50};
gL.Padding = [10 10 10 10];

% Selector de N
uilabel(gL,'Text','N perfiles');
ddN = uidropdown(gL,'Items',{'3','4','5'},'Value','3');

% separador
uilabel(gL,'Text',''); uilabel(gL,'Text','');

% Panel dinámico
pDyn = uipanel(gL,'Title','Perfiles & cortes');
pDyn.Layout.Row = 3;
pDyn.Layout.Column = [1 2];

% separador
uilabel(gL,'Text',''); uilabel(gL,'Text','');

% Botón RUN
btn = uibutton(gL,'Text','RUN Optimización','ButtonPushedFcn',@(~,~) onRun());
btn.Layout.Row = 5; btn.Layout.Column = [1 2];

% Estado
lblStatus = uilabel(gL,'Text','Listo.','FontColor',[0.3 0.3 0.3]);
lblStatus.Layout.Row = 6; lblStatus.Layout.Column = [1 2];

% Panel de diagnóstico
txtDiagOpt = uitextarea(gL,'Value','','Editable','off', ...
    'FontSize',11,'BackgroundColor',[0.97 0.97 0.97]);
txtDiagOpt.Layout.Row = 7; txtDiagOpt.Layout.Column = [1 2];

% ================================================================
%  TAB 2 - ANÁLISIS
% ================================================================
gAnal = uigridlayout(tabAnal,[14 2]);
gAnal.ColumnWidth = {160,'1x'};
gAnal.RowHeight   = [repmat({30},1,13), {80}];
gAnal.Padding     = [10 10 10 10];

% Fila 1
lbl1 = uilabel(gAnal,'Text','Potencia nominal PN [MW]');
lbl1.Layout.Row = 1; lbl1.Layout.Column = 1;
efPN = uieditfield(gAnal,'numeric','Value',15);
efPN.Layout.Row = 1; efPN.Layout.Column = 2;
% Fila 2
lbl2 = uilabel(gAnal,'Text','Vin [m/s]');
lbl2.Layout.Row = 2; lbl2.Layout.Column = 1;
efVin = uieditfield(gAnal,'numeric','Value',3);
efVin.Layout.Row = 2; efVin.Layout.Column = 2;
% Fila 3
lbl3 = uilabel(gAnal,'Text','Vout [m/s]');
lbl3.Layout.Row = 3; lbl3.Layout.Column = 1;
efVout = uieditfield(gAnal,'numeric','Value',25);
efVout.Layout.Row = 3; efVout.Layout.Column = 2;
% Fila 4
lbl4 = uilabel(gAnal,'Text','ΩR_lim [m/s]');
lbl4.Layout.Row = 4; lbl4.Layout.Column = 1;
efORlim = uieditfield(gAnal,'numeric','Value',80);
efORlim.Layout.Row = 4; efORlim.Layout.Column = 2;
% Fila 5
lbl5 = uilabel(gAnal,'Text','Weibull c [m/s]');
lbl5.Layout.Row = 5; lbl5.Layout.Column = 1;
efWc = uieditfield(gAnal,'numeric','Value',8);
efWc.Layout.Row = 5; efWc.Layout.Column = 2;
% Fila 6
lbl6 = uilabel(gAnal,'Text','Weibull k [-]');
lbl6.Layout.Row = 6; lbl6.Layout.Column = 1;
efWk = uieditfield(gAnal,'numeric','Value',2);
efWk.Layout.Row = 6; efWk.Layout.Column = 2;
% Fila 7
lbl7 = uilabel(gAnal,'Text','SP min/max [W/m^2]');
lbl7.Layout.Row = 7; lbl7.Layout.Column = 1;
glSP = uigridlayout(gAnal,[1 2]);
glSP.ColumnWidth = {'1x','1x'}; glSP.RowHeight = {'1x'}; glSP.Padding = [0 0 0 0];
glSP.Layout.Row = 7; glSP.Layout.Column = 2;
efSPmin = uieditfield(glSP,'numeric','Value',300);
efSPmax = uieditfield(glSP,'numeric','Value',600);
% Fila 8-9
lblLambda = uilabel(gAnal,'Text','λ_op (de Optimización): —','FontColor',[0.1 0.5 0.1]);
lblLambda.Layout.Row = 8; lblLambda.Layout.Column = [1 2];
lblCPmax = uilabel(gAnal,'Text','C_P,max (de Optimización): —','FontColor',[0.1 0.5 0.1]);
lblCPmax.Layout.Row = 9; lblCPmax.Layout.Column = [1 2];
% Fila 10
btnAnal = uibutton(gAnal,'Text','RUN Análisis', ...
                   'ButtonPushedFcn',@(~,~) onRunAnal());
btnAnal.Layout.Row = 10; btnAnal.Layout.Column = [1 2];
% Fila 11
lblStatusAnal = uilabel(gAnal,'Text','Listo.','FontColor',[0.3 0.3 0.3]);
lblStatusAnal.Layout.Row = 11; lblStatusAnal.Layout.Column = [1 2];
% Fila 12
btnStopAnal = uibutton(gAnal,'Text','STOP','Enable','off', ...
    'BackgroundColor',[0.85 0.2 0.2],'FontColor','white', ...
    'ButtonPushedFcn',@(~,~) setStopFlag());
btnStopAnal.Layout.Row = 12; btnStopAnal.Layout.Column = [1 2];
% Fila 13
lblAnalSep = uilabel(gAnal,'Text','');
lblAnalSep.Layout.Row = 13; lblAnalSep.Layout.Column = [1 2];
% Fila 14
txtDiagAnal = uitextarea(gAnal,'Value','','Editable','off', ...
    'FontSize',11,'BackgroundColor',[0.97 0.97 0.97]);
txtDiagAnal.Layout.Row = 14; txtDiagAnal.Layout.Column = [1 2];

% ================================================================
%  TAB 3 - CURVA DE POTENCIA
% ================================================================
gPC = uigridlayout(tabPC,[12 2]);
gPC.ColumnWidth = {160,'1x'};
gPC.RowHeight   = [repmat({30},1,11), {80}];
gPC.Padding     = [10 10 10 10];

lblPC1 = uilabel(gPC,'Text','Radio R [m]');
lblPC1.Layout.Row = 1; lblPC1.Layout.Column = 1;
efR = uieditfield(gPC,'numeric','Value',126);
efR.Layout.Row = 1; efR.Layout.Column = 2;

lblPC2 = uilabel(gPC,'Text','ΩR_lim [m/s]');
lblPC2.Layout.Row = 2; lblPC2.Layout.Column = 1;
efORlimPC = uieditfield(gPC,'numeric','Value',80);
efORlimPC.Layout.Row = 2; efORlimPC.Layout.Column = 2;

lblPC3 = uilabel(gPC,'Text','Potencia nominal PN [MW]');
lblPC3.Layout.Row = 3; lblPC3.Layout.Column = 1;
efPNpc = uieditfield(gPC,'numeric','Value',15);
efPNpc.Layout.Row = 3; efPNpc.Layout.Column = 2;

lblPC4 = uilabel(gPC,'Text','Vin [m/s]');
lblPC4.Layout.Row = 4; lblPC4.Layout.Column = 1;
efVinPC = uieditfield(gPC,'numeric','Value',3);
efVinPC.Layout.Row = 4; efVinPC.Layout.Column = 2;

lblPC5 = uilabel(gPC,'Text','Vout [m/s]');
lblPC5.Layout.Row = 5; lblPC5.Layout.Column = 1;
efVoutPC = uieditfield(gPC,'numeric','Value',25);
efVoutPC.Layout.Row = 5; efVoutPC.Layout.Column = 2;

lblLambdaPC = uilabel(gPC,'Text','λ_op (de Optimización): —','FontColor',[0.1 0.5 0.1]);
lblLambdaPC.Layout.Row = 6; lblLambdaPC.Layout.Column = [1 2];
lblCPmaxPC = uilabel(gPC,'Text','C_P,max (de Optimización): —','FontColor',[0.1 0.5 0.1]);
lblCPmaxPC.Layout.Row = 7; lblCPmaxPC.Layout.Column = [1 2];

btnPC = uibutton(gPC,'Text','RUN Potencia & Control', ...
                 'ButtonPushedFcn',@(~,~) onRunPC());
btnPC.Layout.Row = 8; btnPC.Layout.Column = [1 2];

lblStatusPC = uilabel(gPC,'Text','Listo.','FontColor',[0.3 0.3 0.3]);
lblStatusPC.Layout.Row = 9; lblStatusPC.Layout.Column = [1 2];
% Fila 10: boton STOP curva potencia
btnStopPC = uibutton(gPC,'Text','STOP','Enable','off', ...
    'BackgroundColor',[0.85 0.2 0.2],'FontColor','white', ...
    'ButtonPushedFcn',@(~,~) setStopFlag());
btnStopPC.Layout.Row = 10; btnStopPC.Layout.Column = [1 2];

% Fila 11: separadora
lblPCSep = uilabel(gPC,'Text','');
lblPCSep.Layout.Row = 11; lblPCSep.Layout.Column = [1 2];
% Fila 12: panel de diagnóstico
txtDiagPC = uitextarea(gPC,'Value','','Editable','off', ...
    'FontSize',11,'BackgroundColor',[0.97 0.97 0.97]);
txtDiagPC.Layout.Row = 12; txtDiagPC.Layout.Column = [1 2];


% ================================================================
%  Panel derecho
% ================================================================
glRight = uigridlayout(pRight,[1 1]);
glRight.Padding = [0 0 0 0];
tgR = uitabgroup(glRight);
tabPlotsOpt  = uitab(tgR,'Title','Optimización');
tabPlotsAnal = uitab(tgR,'Title','Análisis');
tabPlotsPC   = uitab(tgR,'Title','Curva de Potencia');
tabPlotsCC   = uitab(tgR,'Title','Curvas de Control');

% Plots Optimizacion
gR = uigridlayout(tabPlotsOpt,[2 2]);
gR.RowHeight = {'1x','1x'};
gR.ColumnWidth = {'1x','1x'};
gR.Padding = [10 10 10 10];

axCP = uiaxes(gR); axCP.Layout.Row=1; axCP.Layout.Column=[1 2];
title(axCP,'C_P(\lambda)'); xlabel(axCP,'\lambda'); ylabel(axCP,'C_P'); grid(axCP,'on'); hold(axCP,'on');

axInd = uiaxes(gR); axInd.Layout.Row=2; axInd.Layout.Column=1;
title(axInd,'a, a'', \sigma'); xlabel(axInd,'x=r/R'); grid(axInd,'on');

axGeom = uiaxes(gR); axGeom.Layout.Row=2; axGeom.Layout.Column=2;
title(axGeom,'\phi, \theta_G (en \lambda*)'); xlabel(axGeom,'x=r/R'); grid(axGeom,'on'); hold(axGeom,'on');

% Plots Analisis
gRAouter = uigridlayout(tabPlotsAnal,[1 1]);
gRAouter.Padding = [0 0 0 0];
tgAnal = uitabgroup(gRAouter);
tabFig1 = uitab(tgAnal,'Title','Fig 1. ISO-R / ISO-FC');
tabFig2 = uitab(tgAnal,'Title','Fig 2. V_ΩN / K_V');
tabFig3 = uitab(tgAnal,'Title','Fig 3. C_PN / C_P,max');

% Fig 1: ISO-R (izq) e ISO-FC (dcha)
gFig1 = uigridlayout(tabFig1,[1 2]); gFig1.Padding=[5 5 5 5];
gFig1.ColumnWidth = {'1x','1x'};
axA1 = uiaxes(gFig1); axA1.Layout.Row=1; axA1.Layout.Column=1;
grid(axA1,'on');
xlabel(axA1,'\Omega R_{NL} [m/s]'); ylabel(axA1,'V_N [m/s]');
axA2 = uiaxes(gFig1); axA2.Layout.Row=1; axA2.Layout.Column=2;
grid(axA2,'on');
xlabel(axA2,'\Omega R_{NL} [m/s]'); ylabel(axA2,'V_N [m/s]');

% Fig 2: V_OmegaN (izq) y K_V (dcha)
gFig2 = uigridlayout(tabFig2,[1 2]); gFig2.Padding=[5 5 5 5];
gFig2.ColumnWidth = {'1x','1x'};
axA3 = uiaxes(gFig2); axA3.Layout.Row=1; axA3.Layout.Column=1;
grid(axA3,'on');
xlabel(axA3,'\Omega R_{NL} [m/s]'); ylabel(axA3,'V_N [m/s]');
axA4 = uiaxes(gFig2); axA4.Layout.Row=1; axA4.Layout.Column=2;
grid(axA4,'on');
xlabel(axA4,'\Omega R_{NL} [m/s]'); ylabel(axA4,'V_N [m/s]');

% Fig 3: CPN/CPmax
gFig3 = uigridlayout(tabFig3,[1 1]); gFig3.Padding=[5 5 5 5];
axA5 = uiaxes(gFig3);
grid(axA5,'on');
xlabel(axA5,'\Omega R_{NL} [m/s]'); ylabel(axA5,'V_N [m/s]');

% Plot Curva de Potencia
gRPC = uigridlayout(tabPlotsPC,[1 1]);
gRPC.Padding = [10 10 10 10];
axPC = uiaxes(gRPC);
title(axPC,'Curva de Potencia P(V)');
xlabel(axPC,'V [m/s]'); ylabel(axPC,'P [MW]');
grid(axPC,'on'); hold(axPC,'on');

% Plots Curvas de Control
gRCCouter = uigridlayout(tabPlotsCC,[1 1]);
gRCCouter.Padding = [0 0 0 0];
tgCC = uitabgroup(gRCCouter);
tabCC1 = uitab(tgCC,'Title','Figura 1');
tabCC2 = uitab(tgCC,'Title','Figura 2');

% Fig 1
gCC1 = uigridlayout(tabCC1,[2 2]); gCC1.Padding=[5 5 5 5];
gCC1.RowHeight={'1x','1x'}; gCC1.ColumnWidth={'1x','1x'};
axCC_P  = uiaxes(gCC1); axCC_P.Layout.Row=1;  axCC_P.Layout.Column=1;
grid(axCC_P,'on'); hold(axCC_P,'on');
xlabel(axCC_P,'V [m/s]'); ylabel(axCC_P,'P [W]');
axCC_Q  = uiaxes(gCC1); axCC_Q.Layout.Row=1;  axCC_Q.Layout.Column=2;
grid(axCC_Q,'on'); hold(axCC_Q,'on');
xlabel(axCC_Q,'V [m/s]'); ylabel(axCC_Q,'Q [N·m]');
axCC_Om = uiaxes(gCC1); axCC_Om.Layout.Row=2; axCC_Om.Layout.Column=1;
grid(axCC_Om,'on'); hold(axCC_Om,'on');
xlabel(axCC_Om,'V [m/s]'); ylabel(axCC_Om,'\Omega [rad/s]');
axCC_th = uiaxes(gCC1); axCC_th.Layout.Row=2; axCC_th.Layout.Column=2;
grid(axCC_th,'on'); hold(axCC_th,'on');
xlabel(axCC_th,'V [m/s]'); ylabel(axCC_th,'\theta_C [rad]');

% Fig 2
gCC2 = uigridlayout(tabCC2,[2 1]); gCC2.Padding=[5 5 5 5];
gCC2.RowHeight={'1x','1x'};
axCC_CP = uiaxes(gCC2); axCC_CP.Layout.Row=1;
grid(axCC_CP,'on'); hold(axCC_CP,'on');
xlabel(axCC_CP,'V [m/s]'); ylabel(axCC_CP,'C_P');
axCC_CQ = uiaxes(gCC2); axCC_CQ.Layout.Row=2;
grid(axCC_CQ,'on'); hold(axCC_CQ,'on');
xlabel(axCC_CQ,'V [m/s]'); ylabel(axCC_CQ,'C_Q');


% ================================================================
%  TAB 4 - OPCIONES AVANZADAS
% ================================================================
gAdv = uigridlayout(tabAdv,[14 2]);
gAdv.ColumnWidth = {175,'1x'};
gAdv.RowHeight   = repmat({30},1,14);
gAdv.Padding     = [10 10 10 10];

lbSecFis = uilabel(gAdv,'Text','— Parámetros físicos —','FontWeight','bold');
lbSecFis.Layout.Row=1; lbSecFis.Layout.Column=[1 2];

lbRho = uilabel(gAdv,'Text','Densidad ρ [kg/m³]'); lbRho.Layout.Row=2; lbRho.Layout.Column=1;
efRho = uieditfield(gAdv,'numeric','Value',cfg.rho); efRho.Layout.Row=2; efRho.Layout.Column=2;

lbB = uilabel(gAdv,'Text','Nº palas b [-]'); lbB.Layout.Row=3; lbB.Layout.Column=1;
efB = uieditfield(gAdv,'numeric','Value',cfg.b,'RoundFractionalValues','on'); efB.Layout.Row=3; efB.Layout.Column=2;

lbNX = uilabel(gAdv,'Text','Resolución radial NX [-]'); lbNX.Layout.Row=4; lbNX.Layout.Column=1;
efNX = uieditfield(gAdv,'numeric','Value',cfg.NX,'RoundFractionalValues','on'); efNX.Layout.Row=4; efNX.Layout.Column=2;

lbLamLo = uilabel(gAdv,'Text','λ mínimo [-]'); lbLamLo.Layout.Row=5; lbLamLo.Layout.Column=1;
efLamLo = uieditfield(gAdv,'numeric','Value',cfg.lambdaLo); efLamLo.Layout.Row=5; efLamLo.Layout.Column=2;

lbLamHi = uilabel(gAdv,'Text','λ máximo [-]'); lbLamHi.Layout.Row=6; lbLamHi.Layout.Column=1;
efLamHi = uieditfield(gAdv,'numeric','Value',cfg.lambdaHi); efLamHi.Layout.Row=6; efLamHi.Layout.Column=2;

lbEtaM = uilabel(gAdv,'Text','Efic. mecánica ηₘ [-]'); lbEtaM.Layout.Row=7; lbEtaM.Layout.Column=1;
efEtaM = uieditfield(gAdv,'numeric','Value',cfg.etaM); efEtaM.Layout.Row=7; efEtaM.Layout.Column=2;

lbEtaE = uilabel(gAdv,'Text','Efic. eléctrica ηₑ [-]'); lbEtaE.Layout.Row=8; lbEtaE.Layout.Column=1;
efEtaE = uieditfield(gAdv,'numeric','Value',cfg.etaE); efEtaE.Layout.Row=8; efEtaE.Layout.Column=2;

btnApplyAdv = uibutton(gAdv,'Text','Aplicar cambios','ButtonPushedFcn',@(~,~) onApplyAdv());
btnApplyAdv.Layout.Row=9; btnApplyAdv.Layout.Column=[1 2];

lblAdvStatus = uilabel(gAdv,'Text','','FontColor',[0.2 0.5 0.2]);
lblAdvStatus.Layout.Row=10; lblAdvStatus.Layout.Column=[1 2];

lbSecGuard = uilabel(gAdv,'Text','— Guardar / Cargar caso —','FontWeight','bold');
lbSecGuard.Layout.Row=11; lbSecGuard.Layout.Column=[1 2];

btnSave = uibutton(gAdv,'Text','💾  Guardar caso...','ButtonPushedFcn',@(~,~) onSaveCase());
btnSave.Layout.Row=12; btnSave.Layout.Column=[1 2];

btnLoad = uibutton(gAdv,'Text','📂  Cargar caso...','ButtonPushedFcn',@(~,~) onLoadCase());
btnLoad.Layout.Row=13; btnLoad.Layout.Column=[1 2];

btnLoadRef = uibutton(gAdv,'Text','⚡  Cargar caso de referencia','ButtonPushedFcn',@(~,~) onLoadRef());
btnLoadRef.Layout.Row=14; btnLoadRef.Layout.Column=[1 2];

% Estado UI dinámico
ui = struct();
ui.ddProfiles = gobjects(0);
ui.slCuts     = gobjects(0);
ui.lblCuts    = gobjects(0);
ui.N          = str2double(ddN.Value);

rebuildDynamicPanel();
ddN.ValueChangedFcn = @(~,~) onNChanged();

%% ===== Callbacks =====

    function onNChanged()
        ui.N = str2double(ddN.Value);
        rebuildDynamicPanel();
    end

    function allowed = getAllowedListsByN(N)
        switch N
            case 3
                allowed = {cellstr(L1),cellstr(L2),cellstr(L3)};
            case 4
                allowed = {cellstr(L1),cellstr(L4),cellstr(L5),cellstr(L3)};
            case 5
                allowed = {cellstr(L6),cellstr(L7),cellstr(L4),cellstr(L5),cellstr(L3)};
            otherwise
                error('N no soportado');
        end

        for ii = 1:numel(allowed)
            if isempty(allowed{ii})
                allowed{ii} = cellstr(allNames);
            end
        end
    end

    function rebuildDynamicPanel()
        delete(pDyn.Children);

        N = ui.N;
        gap = 0.03; % separación mínima entre cortes

        % Filas: N perfiles + (N-1) cortes
        nRows = N + (N-1) + 1;

        gd = uigridlayout(pDyn,[nRows 2]);
        gd.ColumnWidth = {120,'1x'};
        gd.RowHeight = repmat({36},1,nRows);
        gd.Padding = [8 8 8 8];

        ui.ddProfiles = gobjects(1,N);
        ui.slCuts     = gobjects(1,max(N-1,0));

        row = 1;

        % Dropdowns perfiles (listas según N)
        allowed = getAllowedListsByN(N);

        for i = 1:N
            uilabel(gd,'Text',sprintf('Perfil %d',i));

            items = allowed{i};

            if isempty(items)
                items = airfoilNames;
            end
            if isstring(items)
                items = cellstr(items);
            end

            dd = uidropdown(gd,'Items',items,'Value',items{1});
            dd.Layout.Row = row;
            dd.Layout.Column = 2;

            ui.ddProfiles(i) = dd;
            row = row + 1;
        end

        % Sliders cortes
        for k = 1:N-1
            uilabel(gd,'Text',sprintf('Corte %d-%d',k,k+1));

            if N == 3
                v0 = [0.20, 0.80];
            elseif N == 4
                v0 = [0.20, 0.55, 0.85];
            else % N==5
                v0 = [0.18, 0.40, 0.65, 0.87];
            end
            v = v0(k);

            xmin = 0.10 + (k-1)*0.03;
            xmax = 0.98 - (N-1-k)*0.03;

            sl = uislider(gd,'Limits',[xmin xmax],'Value',min(max(v,xmin),xmax));
            sl.MajorTicks = 0:0.1:1;
            sl.MinorTicks = [];

            sl.Layout.Row = row; sl.Layout.Column = 2;

            % callbacks (secuencial)
            sl.ValueChangingFcn = @(s,e) enforceCuts(k, e.Value, gap);
            sl.ValueChangedFcn  = @(s,e) enforceCuts(k, s.Value, gap);

            ui.slCuts(k) = sl;
            row = row + 1;
        end

        ui.lblCuts = uilabel(gd,'Text','','WordWrap','on','HorizontalAlignment','center');
        ui.lblCuts.Layout.Row = row;
        ui.lblCuts.Layout.Column = [1 2];

        updateCutsText();
    end

    function enforceCuts(k, newValue, gap)
        ui.slCuts(k).Value = newValue;

        n = numel(ui.slCuts);

        for j = k+1:n
            if ui.slCuts(j).Value <= ui.slCuts(j-1).Value + gap
                ui.slCuts(j).Value = min( ...
                    ui.slCuts(j-1).Value + gap, ...
                    ui.slCuts(j).Limits(2));
            end
        end

        for j = k-1:-1:1
            if ui.slCuts(j).Value >= ui.slCuts(j+1).Value - gap
                ui.slCuts(j).Value = max( ...
                    ui.slCuts(j+1).Value - gap, ...
                    ui.slCuts(j).Limits(1));
            end
        end

        updateCutsText();
    end

    function updateCutsText()
        if isempty(ui.slCuts)
            ui.lblCuts.Text = '';
            return;
        end
        vals = arrayfun(@(s) s.Value, ui.slCuts);
        ui.lblCuts.Text = ['Posiciones de corte: [' sprintf('%.3f ', vals) ']'];
    end

    % RUN Optimización
    function onRun()
        try
            lblStatus.Text = 'Calculando...';
            drawnow;

            % leer perfiles
            N = ui.N;
            airfoils = cell(1,N);
            for i = 1:N
                airfoils{i} = ui.ddProfiles(i).Value;
            end

            % leer cortes
            xcuts = arrayfun(@(s) s.Value, ui.slCuts);

            % validación estricta
            if any(diff(xcuts) <= 0)
                lblStatus.Text = '⚠️ ERROR: los cortes deben ser crecientes. No se ha calculado.';
                return;
            end

            % Refinamiento iterativo de lambda
            lam_lo = cfg.lambdaLo;  lam_hi = cfg.lambdaHi;
            for iPass = 1:3
                cfg.lambdavec = linspace(lam_lo, lam_hi, 20);
                out_pass = WIND_coreN(airfoils, xcuts, cfg);
                halfSpan = (lam_hi - lam_lo) * 0.20;
                lam_lo = max(cfg.lambdaLo, out_pass.lambdaStar - halfSpan);
                lam_hi = min(cfg.lambdaHi, out_pass.lambdaStar + halfSpan);
                lblStatus.Text = sprintf('Pasada %d/3 — λ* ≈ %.3f', iPass, out_pass.lambdaStar);
                drawnow;
            end
            lambdaStar_refined = out_pass.lambdaStar;
            CPstar_refined     = out_pass.CPstar;

            % Pasada de visualización: curva CP(lambda) completa
            cfg.lambdavec = linspace(cfg.lambdaLo, cfg.lambdaHi, 60);
            out = WIND_coreN(airfoils, xcuts, cfg);
            % Sobreescribir lambdaStar y CPstar con el valor refinado
            out.lambdaStar = lambdaStar_refined;
            out.CPstar     = CPstar_refined;

            % guardar lambdaStar y CPstar en appState
            appState.lambdaop = out.lambdaStar;
            appState.CPmax    = out.CPstar;
            appState.b        = cfg.b;   % Construir blade con los nombres que espera CPfun/Rpow3
            blade = struct();
            blade.xvec     = out.xvec;
            blade.xcuts    = out.xcuts;
            blade.airfoils = out.airfoils;
            blade.xR       = out.xR;
            blade.sigma    = out.sigmaStar;  
            blade.thetaG   = out.thetaGStar; 
            appState.blade = blade;
            lblLambda.Text = sprintf('λ_op (de Optimización): %.4f', appState.lambdaop);
            lblCPmax.Text  = sprintf('C_P,max (de Optimización): %.4f', appState.CPmax);
            lblLambdaPC.Text = sprintf('λ_op (de Optimización): %.4f', appState.lambdaop);
            lblCPmaxPC.Text  = sprintf('C_P,max (de Optimización): %.4f', appState.CPmax);

            % Plots 
            cla(axCP); cla(axInd); cla(axGeom);

            plot(axCP, out.lambdavec, out.CP, 'o-');
            plot(axCP, out.lambdaStar, out.CPstar, '.r', 'MarkerSize', 25);
            title(axCP, sprintf('C_P(\\lambda) | \\lambda*=%.3f, C_P*=%.3f', out.lambdaStar, out.CPstar));
            xlim(axCP, [cfg.lambdaLo, cfg.lambdaHi]);

            % Eje izquierdo: sigma (azul discontinuo)
            yyaxis(axInd,'left');
            cla(axInd);
            plot(axInd, out.xvec, out.sigmaStar,'b--','LineWidth',1.5,'DisplayName','\sigma [-]');
            ylabel(axInd,'\sigma [-]');
            % Eje derecho: a (rojo) y a' (negro)
            yyaxis(axInd,'right');
            plot(axInd, out.xvec, out.aStar,  'r-', 'LineWidth',1.5,'DisplayName','a');
            hold(axInd,'on');
            plot(axInd, out.xvec, out.apStar, 'k-', 'LineWidth',1.5,'DisplayName','a''');
            ylabel(axInd,'a, a'' [-]');
            legend(axInd,'\sigma','a','a''','Location','best');
            title(axInd,'a, a'', \sigma (en \lambda*)');
            xlabel(axInd,'x=r/R');

            plot(axGeom, out.xvec, rad2deg(out.phiStar),    'k-', 'DisplayName','\phi [deg]');
            plot(axGeom, out.xvec, rad2deg(out.thetaGStar), 'r-', 'DisplayName','\theta_G [deg]');
            legend(axGeom,'Location','best');

            lblStatus.Text = 'OK ✅';

            % Diagnósticos
            diagLines = buildDiagOpt(out, airfoils);
            txtDiagOpt.Value = diagLines;
            % Alerta solo si Cp supera Betz
            if out.CPstar > 16/27
                uialert(fig, sprintf('C_P* = %.4f supera el límite de Betz (%.4f). Revisar polares o configuración.', ...
                    out.CPstar, 16/27), 'Resultado no físico', 'Icon','warning');
            end

            % Guardar resultados
            appState.resOpt = out;
        catch ME
            lblStatus.Text = ['ERROR: ' ME.message];
            rethrow(ME);
        end
    end

    % RUN Análisis
    function onRunAnal()
        try
            if isnan(appState.lambdaop) || isnan(appState.CPmax)
                lblStatusAnal.Text = 'Ejecuta primero RUN en la pestana Optimizacion.';
                return;
            end

            stopFlag = false;
            btnStopAnal.Enable = 'on';
            btnAnal.Enable = 'off';
            lblStatusAnal.Text = 'Calculando dimensionado...'; drawnow;

            % Inputs del usuario
            PN       = efPN.Value * 1e6;
            Vin      = efVin.Value;
            Vout     = efVout.Value;
            ORlim    = efORlim.Value;
            c        = efWc.Value;
            k        = efWk.Value;
            SPmin    = efSPmin.Value;
            SPmax    = efSPmax.Value;

            % Desde optimizacion
            lambdaop = appState.lambdaop;
            CPmax    = appState.CPmax;
            thetaCop = appState.thetaCop;
            blade    = appState.blade;
            b        = appState.b;

            etaM = cfg.etaM;
            etaE = cfg.etaE;
            rho  = cfg.rho;
            N    = 5;

            % Bucle VnORn
            ORNLvect = linspace(60, 100, N);
            VN_lo = 60/lambdaop * 1.05;
            VN_hi = min(100/lambdaop + 4, 16);  
            VNvect = linspace(VN_lo, VN_hi, N);

            ORNLmatrix    = zeros(N,N);
            VNmatrix_     = zeros(N,N);
            Rmatrix       = zeros(N,N);
            PAVE_PNmatrix = zeros(N,N);
            KVmatrix      = zeros(N,N);
            VORNmatrix    = zeros(N,N);
            CPN_maxmatrix = zeros(N,N);

            total = N*N; cnt = 0;
            for ORNLi = 1:N
                ORNL = ORNLvect(ORNLi);
                for VNi = 1:N
                    VN = VNvect(VNi);
                    KV = (ORNL/lambdaop)/VN;
                    R  = Rpow3(VN, KV, PN, lambdaop, thetaCop, etaM, etaE, blade, b);
                    [Pav,~] = avePow3(Vin, Vout, VN, KV, R, PN, CPmax, lambdaop, ...
                                      thetaCop, etaM, etaE, blade, b, k, c);
                    ORNLmatrix(ORNLi,VNi)    = ORNL;
                    VNmatrix_(ORNLi,VNi)     = VN;
                    Rmatrix(ORNLi,VNi)       = R;
                    PAVE_PNmatrix(ORNLi,VNi) = Pav/PN;
                    KVmatrix(ORNLi,VNi)      = KV;
                    VORNmatrix(ORNLi,VNi)    = KV*VN;
                    CPN_maxmatrix(ORNLi,VNi) = PN/(etaM*etaE)/(0.5*rho*pi*R^2*VN^3)/CPmax;
                    cnt = cnt+1;
                    lblStatusAnal.Text = sprintf('Calculo %d de %d...', cnt, total);
                    drawnow;
                    if stopFlag
                        lblStatusAnal.Text = 'Detenido por el usuario.';
                        btnStopAnal.Enable = 'off'; btnAnal.Enable = 'on';
                        return;
                    end
                end
            end

            % Interpolacion
            VNvect_f   = linspace(VN_lo, VN_hi, 40);
            ORNLvect_f = linspace(60, 100, 40);
            [ORgraf, VNgraf] = meshgrid(ORNLvect_f, VNvect_f);

            Rmat   = real(griddata(ORNLmatrix, VNmatrix_, Rmatrix,       ORgraf, VNgraf, 'linear'));
            FCmat  = real(griddata(ORNLmatrix, VNmatrix_, PAVE_PNmatrix, ORgraf, VNgraf, 'linear'));
            VORNm  = real(griddata(ORNLmatrix, VNmatrix_, VORNmatrix,    ORgraf, VNgraf, 'linear'));
            KVmat  = real(griddata(ORNLmatrix, VNmatrix_, KVmatrix,      ORgraf, VNgraf, 'linear'));
            CPNmat = real(griddata(ORNLmatrix, VNmatrix_, CPN_maxmatrix, ORgraf, VNgraf, 'linear'));

            % Clampear CPN a rango físico [0, 1]
            CPNmat = max(0, min(1, CPNmat));

            RmaxSP     = sqrt(PN/(pi*SPmin));
            RminSP     = sqrt(PN/(pi*SPmax));

            % Máximo aproximadamente 20 isolíneas de R
            Rstep      = max(2, ceil((floor(1.105*RmaxSP) - floor(0.95*RminSP)) / 20));
            Rcut       = floor(0.95*RminSP) : Rstep : floor(1.105*RmaxSP)+1;
            Rmat(Rmat < 0.5*RminSP | Rmat > 2*RmaxSP) = NaN;
            CPNmat(isnan(Rmat)) = NaN;
            PAVE_PNcut = [0.1 linspace(0.2,0.6,17) 0.7 0.8];
            % V_OmegaN: rango físico útil
            VORNcut    = linspace(max(3, min(VORNm(:))), min(15, max(VORNm(:))), 12);
            % KV: limitar a zona operativa práctica [0.5, 1.2]
            KVmat_phys = max(0.5, min(1.4, KVmat));
            KVcut      = linspace(0.5, 1.2, 8);
            CPN_maxcut = linspace(0.1, 1.0, 10);

            % Cambiar a pestana Analisis
            tgR.SelectedTab = tabPlotsAnal;

            % Fig 1 izq: ISO-R 
            cla(axA1); hold(axA1,'on');
            [~,hR1] = contour(axA1,ORgraf,VNgraf,Rmat,[RminSP,RmaxSP],'LineWidth',2);
            set(hR1,'LineColor','red','ShowText','on');
            [~,hRc] = contour(axA1,ORgraf,VNgraf,Rmat,Rcut);
            set(hRc,'LineColor','black','ShowText','on');
            pL1=plot(axA1,ORNLvect_f,ORNLvect_f./lambdaop,'b-','LineWidth',2);
            pO1=plot(axA1,[ORlim ORlim],[min(VNvect_f) max(VNvect_f)],'r--','LineWidth',2);
            px1a=plot(axA1,NaN,NaN,'r-','LineWidth',2); px1b=plot(axA1,NaN,NaN,'k-');
            legend(axA1,[px1a,px1b,pL1,pO1],'R limits','R [m]','\lambda_{op}','\Omega R_{lim}','Location','NE');
            title(axA1,'');
            xlabel(axA1,'\Omega R_{NL} [m/s]'); ylabel(axA1,'V_N [m/s]');
            xlim(axA1,[min(ORNLvect_f) max(ORNLvect_f)]);
            ylim(axA1,[min(VNvect_f) max(VNvect_f)]);

            % Fig 1 dcha: ISO-FC
            cla(axA2); hold(axA2,'on');
            [~,hR2]=contour(axA2,ORgraf,VNgraf,Rmat,[RminSP,RmaxSP],'LineWidth',2);
            set(hR2,'LineColor','red','ShowText','on');
            [~,hFC]=contour(axA2,ORgraf,VNgraf,FCmat,PAVE_PNcut);
            set(hFC,'LineColor','black','ShowText','on');
            pL2=plot(axA2,ORNLvect_f,ORNLvect_f./lambdaop,'b-','LineWidth',2);
            pO2=plot(axA2,[ORlim ORlim],[min(VNvect_f) max(VNvect_f)],'r--','LineWidth',2);
            px2a=plot(axA2,NaN,NaN,'r-','LineWidth',2); px2b=plot(axA2,NaN,NaN,'k-');
            legend(axA2,[px2a,px2b,pL2,pO2],'R limits','FC','\lambda_{op}','\Omega R_{lim}','Location','NE');
            title(axA2,'');
            xlabel(axA2,'\Omega R_{NL} [m/s]'); ylabel(axA2,'V_N [m/s]');
            xlim(axA2,[min(ORNLvect_f) max(ORNLvect_f)]);
            ylim(axA2,[min(VNvect_f) max(VNvect_f)]);

            % Fig 2 izq: V_OmegaN
            cla(axA3); hold(axA3,'on');
            [~,hR3]=contour(axA3,ORgraf,VNgraf,Rmat,[RminSP,RmaxSP],'LineWidth',2);
            set(hR3,'LineColor','red','ShowText','on');
            [~,hVO]=contour(axA3,ORgraf,VNgraf,VORNm,VORNcut);
            set(hVO,'LineColor','blue','ShowText','on');
            pL3=plot(axA3,ORNLvect_f,ORNLvect_f./lambdaop,'b-','LineWidth',2);
            pO3=plot(axA3,[ORlim ORlim],[min(VNvect_f) max(VNvect_f)],'r--','LineWidth',2);
            px3a=plot(axA3,NaN,NaN,'r-','LineWidth',2); px3b=plot(axA3,NaN,NaN,'b-');
            legend(axA3,[px3a,px3b,pL3,pO3],'R limits','V_{\Omega N} [m/s]','\lambda_{op}','\Omega R_{lim}','Location','NE');
            title(axA3,'');
            xlabel(axA3,'\Omega R_{NL} [m/s]'); ylabel(axA3,'V_N [m/s]');
            xlim(axA3,[min(ORNLvect_f) max(ORNLvect_f)]);
            ylim(axA3,[min(VNvect_f) max(VNvect_f)]);

            % Fig 2 dcha: KV
            cla(axA4); hold(axA4,'on');
            [~,hR4]=contour(axA4,ORgraf,VNgraf,Rmat,[RminSP,RmaxSP],'LineWidth',2);
            set(hR4,'LineColor','red','ShowText','on');
            [~,hKV]=contour(axA4,ORgraf,VNgraf,KVmat_phys,KVcut);
            set(hKV,'LineColor','black','ShowText','on');
            pL4=plot(axA4,ORNLvect_f,ORNLvect_f./lambdaop,'b-','LineWidth',2);
            px4a=plot(axA4,NaN,NaN,'r-','LineWidth',2); px4b=plot(axA4,NaN,NaN,'k-');
            legend(axA4,[px4a,px4b,pL4],'R limits','K_V','\lambda_{op}','Location','NE');
            title(axA4,'');
            xlabel(axA4,'\Omega R_{NL} [m/s]'); ylabel(axA4,'V_N [m/s]');
            xlim(axA4,[min(ORNLvect_f) max(ORNLvect_f)]);
            ylim(axA4,[min(VNvect_f) max(VNvect_f)]);

            % Fig 3: CPN/CPmax
            cla(axA5); hold(axA5,'on');
            [~,hR5]=contour(axA5,ORgraf,VNgraf,Rmat,[RminSP,RmaxSP],'LineWidth',2);
            set(hR5,'LineColor','red','ShowText','on');
            [~,hCP]=contour(axA5,ORgraf,VNgraf,CPNmat,CPN_maxcut);
            set(hCP,'LineColor','black','ShowText','on');
            pL5=plot(axA5,ORNLvect_f,ORNLvect_f./lambdaop,'b-','LineWidth',2);
            px5a=plot(axA5,NaN,NaN,'r-','LineWidth',2); px5b=plot(axA5,NaN,NaN,'k-');
            legend(axA5,[px5a,px5b,pL5],'R limits','C_{PN}/C_{P,max}','\lambda_{op}','Location','NE');
            title(axA5,'');
            xlabel(axA5,'\Omega R_{NL} [m/s]'); ylabel(axA5,'V_N [m/s]');
            xlim(axA5,[min(ORNLvect_f) max(ORNLvect_f)]);
            ylim(axA5,[min(VNvect_f) max(VNvect_f)]);

            btnStopAnal.Enable = 'off';
            btnAnal.Enable = 'on';
            lblStatusAnal.Text = sprintf('OK  R_SP,min=%.1f m | R_SP,max=%.1f m', RminSP, RmaxSP);

            % Diagnósticos
            diagLines = buildDiagAnal(Rmat, FCmat, CPNmat, KVmat_phys, RminSP, RmaxSP);
            txtDiagAnal.Value = diagLines;

            % Guardar resultados para redibujar al cargar caso
            appState.resAnal = struct('ORgraf',ORgraf,'VNgraf',VNgraf, ...
                'Rmat',Rmat,'FCmat',FCmat,'VORNm',VORNm,'KVmat_phys',KVmat_phys, ...
                'CPNmat',CPNmat,'Rcut',Rcut,'PAVE_PNcut',PAVE_PNcut, ...
                'VORNcut',VORNcut,'KVcut',KVcut,'CPN_maxcut',CPN_maxcut, ...
                'RminSP',RminSP,'RmaxSP',RmaxSP, ...
                'ORNLvect_f',ORNLvect_f,'VNvect_f',VNvect_f, ...
                'lambdaop',lambdaop,'ORlim',ORlim);
        catch ME
            lblStatusAnal.Text = ['ERROR: ' ME.message];
            rethrow(ME);
        end
    end


    % RUN Curva de Potencia
    function onRunPC()
        try
            if isnan(appState.lambdaop) || isnan(appState.CPmax)
                lblStatusPC.Text = 'Ejecuta primero RUN en Optimizacion.';
                return;
            end
            lblStatusPC.Text = 'Calculando curva de potencia...'; drawnow;

            R        = efR.Value;
            ORlimPC  = efORlimPC.Value;
            PNpc     = efPNpc.Value * 1e6;
            VinPC    = efVinPC.Value;
            VoutPC   = efVoutPC.Value;

            lambdaop = appState.lambdaop;
            CPmax    = appState.CPmax;
            thetaCop = appState.thetaCop;
            blade    = appState.blade;
            b        = appState.b;
            etaM = cfg.etaM; etaE = cfg.etaE;

            stopFlag = false;
            btnStopPC.Enable = 'on';
            btnPC.Enable = 'off';

            pc = powerCurve(R, PNpc, ORlimPC, lambdaop, thetaCop, CPmax, ...
                            etaM, etaE, VinPC, VoutPC, blade, b, @() stopFlag);

            btnStopPC.Enable = 'off';
            btnPC.Enable = 'on';

            if pc.stopped
                lblStatusPC.Text = 'Detenido por el usuario.';
                return;
            end

            tgR.SelectedTab = tabPlotsPC;

            cla(axPC); hold(axPC,'on');
            plot(axPC, pc.V, pc.P*1e-6, 'b-', 'LineWidth', 2);
            pVN   = plot(axPC, pc.VN,   PNpc*1e-6,     'o', ...
                         'MarkerSize',7, 'MarkerEdgeColor',[0.8 0.1 0.1], ...
                         'MarkerFaceColor',[1 0.5 0.5]);
            pVORN = plot(axPC, pc.VORN, pc.P_VORN*1e-6,'s', ...
                         'MarkerSize',7, 'MarkerEdgeColor',[0.1 0.1 0.8], ...
                         'MarkerFaceColor',[0.5 0.5 1]);
            yline(axPC, PNpc*1e-6,'r--','LineWidth',1.5);
            xlabel(axPC,'V [m/s]'); ylabel(axPC,'P [MW]');
            title(axPC, sprintf('Curva de Potencia | R=%.1f m, V_N=%.2f m/s, K_V=%.3f', R, pc.VN, pc.KV));
            legend(axPC, 'P(V)', ...
                   sprintf('V_N=%.2f m/s (potencia nominal)',    pc.VN), ...
                   sprintf('V_{\\OmegaN}=%.2f m/s (\\Omega=\\Omega_N)',pc.VORN), ...
                   'P_N', 'Location','SE');
            ylim(axPC,[0, 1.1*PNpc*1e-6]);
            grid(axPC,'on');

            lblStatusPC.Text = sprintf('Curva de potencia OK. Calculando curvas de control...');
            drawnow;

            % Curvas de control
            cc = controlCurves(R, PNpc, ORlimPC, lambdaop, thetaCop, CPmax, ...
                               etaM, etaE, VinPC, VoutPC, blade, b);

            % Fig 1: P, Q, Omega, thetaC
            drawCC(axCC_P,  'V [m/s]','P [W]',          '',  cc.V1221vect, cc.P1221,      cc.Vvect, cc.Pvect);
            drawCC(axCC_Q,  'V [m/s]','Q [N·m]',        '',  cc.V1221vect, cc.Q1221,      cc.Vvect, cc.Qvect);
            drawCC(axCC_Om, 'V [m/s]','\Omega [rad/s]', '',  cc.V1221vect, cc.Omega1221,  cc.Vvect, cc.Omegavect);

            cla(axCC_th); hold(axCC_th,'on');
            legHandles = gobjects(0);
            legLabels  = {};
            if ~isempty(cc.V1221vect)
                h1 = plot(axCC_th, cc.V1221vect, cc.thetaC1221Pitch,'m-','LineWidth',2);
                h2 = plot(axCC_th, cc.V1221vect, cc.thetaC1221AS,   'g-','LineWidth',2);
                legHandles = [legHandles, h1, h2];
                legLabels  = [legLabels, {'V.P. Sin rest.','A.S. Sin rest.'}];
            end
            h3 = plot(axCC_th, cc.Vvect, cc.thetaCPitch,  'b-','LineWidth',2);
            h4 = plot(axCC_th, cc.Vvect, cc.thetaCAS,      'r-','LineWidth',2);
            h5 = plot(axCC_th, cc.V1plus2, cc.thetaC1plus2,'k-','LineWidth',2);
            legHandles = [legHandles, h3, h4, h5];
            legLabels  = [legLabels, {'V.P. Con rest.','A.S. Con rest.','\theta_0'}];
            xlabel(axCC_th,'V [m/s]'); ylabel(axCC_th,'\theta_C [rad]');
            xlim(axCC_th,[min(cc.Vvect), max(cc.Vvect)]);
            legend(axCC_th, legHandles, legLabels, 'Location','Best');
            grid(axCC_th,'on');

            % Fig 2: CP, CQ
            drawCC(axCC_CP, 'V [m/s]','C_P','', cc.V1221vect, cc.CP1221, cc.Vvect, cc.CPvect);
            drawCC(axCC_CQ, 'V [m/s]','C_Q','', cc.V1221vect, cc.CQ1221, cc.Vvect, cc.CQvect);

            lblStatusPC.Text = sprintf('OK  V_N=%.2f m/s | K_V=%.3f | VORN=%.2f m/s', pc.VN, pc.KV, pc.VORN);

            % Diagnósticos
            diagLines = buildDiagPC(pc, cc, PNpc);
            txtDiagPC.Value = diagLines;

            % Guardar resultados para redibujar al cargar caso
            appState.resPC = struct('pc',pc,'cc',cc,'PNpc',PNpc,'R',R);
        catch ME
            lblStatusPC.Text = ['ERROR: ' ME.message];
            rethrow(ME);
        end
    end

    % Boton STOP
    function setStopFlag()
        stopFlag = true;
    end

    % Aplicar parámetros de Opciones avanzadas
    function onApplyAdv()
        cfg.rho      = efRho.Value;
        cfg.b        = round(efB.Value);
        cfg.NX       = round(efNX.Value);
        cfg.lambdaLo = efLamLo.Value;
        cfg.lambdaHi = efLamHi.Value;
        cfg.etaM     = efEtaM.Value;
        cfg.etaE     = efEtaE.Value;
        cfg.lambdavec = linspace(cfg.lambdaLo, cfg.lambdaHi, 60);
        appState.b   = cfg.b;
        lblAdvStatus.Text = sprintf('✅ Aplicado: b=%d | NX=%d | λ=[%.1f,%.1f] | ρ=%.3f', ...
            cfg.b, cfg.NX, cfg.lambdaLo, cfg.lambdaHi, cfg.rho);
    end

    % Guardar caso
    function onSaveCase()
        % Recoger todos los inputs de la UI
        caseData = struct();
        caseData.appState = appState;
        caseData.cfg      = cfg;
        % Optimización
        caseData.N_perfiles = ui.N;
        airfoilsSel = cell(1,ui.N);
        for i = 1:ui.N
            airfoilsSel{i} = ui.ddProfiles(i).Value;
        end
        caseData.airfoils = airfoilsSel;
        caseData.xcuts    = arrayfun(@(s) s.Value, ui.slCuts);
        % Análisis
        caseData.PN    = efPN.Value;
        caseData.Vin   = efVin.Value;
        caseData.Vout  = efVout.Value;
        caseData.ORlim = efORlim.Value;
        caseData.Wc    = efWc.Value;
        caseData.Wk    = efWk.Value;
        caseData.SPmin = efSPmin.Value;
        caseData.SPmax = efSPmax.Value;
        % Potencia & Control
        caseData.R       = efR.Value;
        caseData.ORlimPC = efORlimPC.Value;
        caseData.PNpc    = efPNpc.Value;
        caseData.VinPC   = efVinPC.Value;
        caseData.VoutPC  = efVoutPC.Value;
        % Opciones avanzadas
        caseData.rho  = efRho.Value;
        caseData.etaM = efEtaM.Value;
        caseData.etaE = efEtaE.Value;

        [fname, fpath] = uiputfile('*.mat','Guardar caso como...','caso_viento.mat');
        if isequal(fname,0), return; end
        save(fullfile(fpath,fname),'-struct','caseData');
        lblAdvStatus.Text = sprintf('✅ Caso guardado: %s', fname);
    end

    % Cargar caso
    function onLoadCase()
        [fname, fpath] = uigetfile('*.mat','Seleccionar caso...','*.mat');
        if isequal(fname,0), return; end
        loadCaseFromFile(fullfile(fpath,fname));
        lblAdvStatus.Text = sprintf('✅ Caso cargado: %s', fname);
    end

    % Cargar caso de referencia
    function onLoadRef()
        refFile = fullfile(fileparts(mfilename('fullpath')),'caso_referencia.mat');
        if ~isfile(refFile)
            uialert(fig,'No se encontró "caso_referencia.mat" en la carpeta de la toolbox.', ...
                    'Caso de referencia no encontrado');
            return;
        end
        loadCaseFromFile(refFile);
        lblAdvStatus.Text = '✅ Caso de referencia cargado.';
    end

    % Función interna: aplica un .mat a toda la UI
    function loadCaseFromFile(filepath)
        S = load(filepath);

        % appState y cfg
        if isfield(S,'appState'), appState = S.appState; end
        if isfield(S,'cfg'),      cfg      = S.cfg;      end

        % Reconstruir lambdavec
        if ~isfield(cfg,'lambdavec')
            cfg.lambdavec = linspace(cfg.lambdaLo, cfg.lambdaHi, 60);
        end

        % Opciones avanzadas
        if isfield(S,'rho'),  efRho.Value  = S.rho;  cfg.rho  = S.rho;  end
        if isfield(S,'etaM'), efEtaM.Value = S.etaM; cfg.etaM = S.etaM; end
        if isfield(S,'etaE'), efEtaE.Value = S.etaE; cfg.etaE = S.etaE; end
        efB.Value      = cfg.b;
        efNX.Value     = cfg.NX;
        efLamLo.Value  = cfg.lambdaLo;
        efLamHi.Value  = cfg.lambdaHi;

        % Inputs de Análisis
        if isfield(S,'PN'),    efPN.Value    = S.PN;    end
        if isfield(S,'Vin'),   efVin.Value   = S.Vin;   end
        if isfield(S,'Vout'),  efVout.Value  = S.Vout;  end
        if isfield(S,'ORlim'), efORlim.Value = S.ORlim; end
        if isfield(S,'Wc'),    efWc.Value    = S.Wc;    end
        if isfield(S,'Wk'),    efWk.Value    = S.Wk;    end
        if isfield(S,'SPmin'), efSPmin.Value = S.SPmin; end
        if isfield(S,'SPmax'), efSPmax.Value = S.SPmax; end

        % Inputs de Potencia & Control
        if isfield(S,'R'),       efR.Value       = S.R;       end
        if isfield(S,'ORlimPC'), efORlimPC.Value = S.ORlimPC; end
        if isfield(S,'PNpc'),    efPNpc.Value    = S.PNpc;    end
        if isfield(S,'VinPC'),   efVinPC.Value   = S.VinPC;   end
        if isfield(S,'VoutPC'),  efVoutPC.Value  = S.VoutPC;  end

        % Optimización: N perfiles y dropdowns
        if isfield(S,'N_perfiles') && isfield(S,'airfoils')
            % Cambiar N si hace falta
            newN = S.N_perfiles;
            ddN.Value = num2str(newN);
            ui.N = newN;
            rebuildDynamicPanel();
            drawnow;
            % Asignar perfiles cargados
            for ii = 1:min(newN, numel(S.airfoils))
                items = ui.ddProfiles(ii).Items;
                if ismember(S.airfoils{ii}, items)
                    ui.ddProfiles(ii).Value = S.airfoils{ii};
                end
            end
            % Asignar cortes
            if isfield(S,'xcuts') && numel(S.xcuts) == newN-1
                for ii = 1:numel(S.xcuts)
                    ui.slCuts(ii).Value = min(max(S.xcuts(ii), ...
                        ui.slCuts(ii).Limits(1)), ui.slCuts(ii).Limits(2));
                end
                updateCutsText();
            end
        end

        % Actualizar labels de appState
        if ~isnan(appState.lambdaop)
            lblLambda.Text   = sprintf('λ_op (de Optimización): %.4f', appState.lambdaop);
            lblCPmax.Text    = sprintf('C_P,max (de Optimización): %.4f', appState.CPmax);
            lblLambdaPC.Text = sprintf('λ_op (de Optimización): %.4f', appState.lambdaop);
            lblCPmaxPC.Text  = sprintf('C_P,max (de Optimización): %.4f', appState.CPmax);
        end

        % Redibujar las gráficas guardadas en el caso
        redrawAll();

        uialert(fig, ...
            'Caso cargado. Las gráficas muestran los resultados guardados. Pulsa RUN para recalcular con los parámetros actuales.', ...
            'Caso cargado', 'Icon','info');
    end

    % Redibujar todas las gráficas guardadas 
    function redrawAll()
        % Optimización
        if ~isempty(appState.resOpt)
            out = appState.resOpt;
            cla(axCP); cla(axInd); cla(axGeom);
            plot(axCP, out.lambdavec, out.CP, 'o-');
            plot(axCP, out.lambdaStar, out.CPstar, '.r', 'MarkerSize', 25);
            title(axCP, sprintf('C_P(\\lambda) | \\lambda*=%.3f, C_P*=%.3f', out.lambdaStar, out.CPstar));
            xlim(axCP, [cfg.lambdaLo, cfg.lambdaHi]);

            yyaxis(axInd,'left'); cla(axInd);
            plot(axInd, out.xvec, out.sigmaStar,'b--','LineWidth',1.5);
            ylabel(axInd,'\sigma [-]');
            yyaxis(axInd,'right');
            plot(axInd, out.xvec, out.aStar,  'r-', 'LineWidth',1.5); hold(axInd,'on');
            plot(axInd, out.xvec, out.apStar, 'k-', 'LineWidth',1.5);
            ylabel(axInd,'a, a'' [-]');
            legend(axInd,'\sigma','a','a''','Location','best');
            title(axInd,'a, a'', \sigma (en \lambda*)'); xlabel(axInd,'x=r/R');

            plot(axGeom, out.xvec, rad2deg(out.phiStar),    'k-', 'DisplayName','\phi [deg]');
            plot(axGeom, out.xvec, rad2deg(out.thetaGStar), 'r-', 'DisplayName','\theta_G [deg]');
            legend(axGeom,'Location','best');
        end

        % Análisis
        if ~isempty(appState.resAnal)
            d = appState.resAnal;
            cla(axA1); hold(axA1,'on');
            [~,hR1]=contour(axA1,d.ORgraf,d.VNgraf,d.Rmat,[d.RminSP,d.RmaxSP],'LineWidth',2);
            set(hR1,'LineColor','red','ShowText','on');
            [~,hRc]=contour(axA1,d.ORgraf,d.VNgraf,d.Rmat,d.Rcut);
            set(hRc,'LineColor','black','ShowText','on');
            pL1=plot(axA1,d.ORNLvect_f,d.ORNLvect_f./d.lambdaop,'b-','LineWidth',2);
            pO1=plot(axA1,[d.ORlim d.ORlim],[min(d.VNvect_f) max(d.VNvect_f)],'r--','LineWidth',2);
            px1a=plot(axA1,NaN,NaN,'r-','LineWidth',2); px1b=plot(axA1,NaN,NaN,'k-');
            legend(axA1,[px1a,px1b,pL1,pO1],'R limits','R [m]','\lambda_{op}','\Omega R_{lim}','Location','NE');
            title(axA1,'');
            xlabel(axA1,'\Omega R_{NL} [m/s]'); ylabel(axA1,'V_N [m/s]');
            xlim(axA1,[min(d.ORNLvect_f) max(d.ORNLvect_f)]);
            ylim(axA1,[min(d.VNvect_f) max(d.VNvect_f)]);

            cla(axA2); hold(axA2,'on');
            [~,hR2]=contour(axA2,d.ORgraf,d.VNgraf,d.Rmat,[d.RminSP,d.RmaxSP],'LineWidth',2);
            set(hR2,'LineColor','red','ShowText','on');
            [~,hFC]=contour(axA2,d.ORgraf,d.VNgraf,d.FCmat,d.PAVE_PNcut);
            set(hFC,'LineColor','black','ShowText','on');
            pL2=plot(axA2,d.ORNLvect_f,d.ORNLvect_f./d.lambdaop,'b-','LineWidth',2);
            pO2=plot(axA2,[d.ORlim d.ORlim],[min(d.VNvect_f) max(d.VNvect_f)],'r--','LineWidth',2);
            px2a=plot(axA2,NaN,NaN,'r-','LineWidth',2); px2b=plot(axA2,NaN,NaN,'k-');
            legend(axA2,[px2a,px2b,pL2,pO2],'R limits','FC','\lambda_{op}','\Omega R_{lim}','Location','NE');
            title(axA2,'');
            xlabel(axA2,'\Omega R_{NL} [m/s]'); ylabel(axA2,'V_N [m/s]');
            xlim(axA2,[min(d.ORNLvect_f) max(d.ORNLvect_f)]);
            ylim(axA2,[min(d.VNvect_f) max(d.VNvect_f)]);

            cla(axA3); hold(axA3,'on');
            [~,hR3]=contour(axA3,d.ORgraf,d.VNgraf,d.Rmat,[d.RminSP,d.RmaxSP],'LineWidth',2);
            set(hR3,'LineColor','red','ShowText','on');
            [~,hVO]=contour(axA3,d.ORgraf,d.VNgraf,d.VORNm,d.VORNcut);
            set(hVO,'LineColor','black','ShowText','on');
            pL3=plot(axA3,d.ORNLvect_f,d.ORNLvect_f./d.lambdaop,'b-','LineWidth',2);
            pO3=plot(axA3,[d.ORlim d.ORlim],[min(d.VNvect_f) max(d.VNvect_f)],'r--','LineWidth',2);
            px3a=plot(axA3,NaN,NaN,'r-','LineWidth',2); px3b=plot(axA3,NaN,NaN,'k-');
            legend(axA3,[px3a,px3b,pL3,pO3],'R limits','V_{\Omega N} [m/s]','\lambda_{op}','\Omega R_{lim}','Location','NE');
            title(axA3,'');
            xlabel(axA3,'\Omega R_{NL} [m/s]'); ylabel(axA3,'V_N [m/s]');
            xlim(axA3,[min(d.ORNLvect_f) max(d.ORNLvect_f)]);
            ylim(axA3,[min(d.VNvect_f) max(d.VNvect_f)]);

            cla(axA4); hold(axA4,'on');
            [~,hR4]=contour(axA4,d.ORgraf,d.VNgraf,d.Rmat,[d.RminSP,d.RmaxSP],'LineWidth',2);
            set(hR4,'LineColor','red','ShowText','on');
            [~,hKV]=contour(axA4,d.ORgraf,d.VNgraf,d.KVmat_phys,d.KVcut);
            set(hKV,'LineColor','black','ShowText','on');
            pL4=plot(axA4,d.ORNLvect_f,d.ORNLvect_f./d.lambdaop,'b-','LineWidth',2);
            px4a=plot(axA4,NaN,NaN,'r-','LineWidth',2); px4b=plot(axA4,NaN,NaN,'k-');
            legend(axA4,[px4a,px4b,pL4],'R limits','K_V','\lambda_{op}','Location','NE');
            title(axA4,'');
            xlabel(axA4,'\Omega R_{NL} [m/s]'); ylabel(axA4,'V_N [m/s]');
            xlim(axA4,[min(d.ORNLvect_f) max(d.ORNLvect_f)]);
            ylim(axA4,[min(d.VNvect_f) max(d.VNvect_f)]);

            cla(axA5); hold(axA5,'on');
            [~,hR5]=contour(axA5,d.ORgraf,d.VNgraf,d.Rmat,[d.RminSP,d.RmaxSP],'LineWidth',2);
            set(hR5,'LineColor','red','ShowText','on');
            [~,hCPN]=contour(axA5,d.ORgraf,d.VNgraf,d.CPNmat,d.CPN_maxcut);
            set(hCPN,'LineColor','black','ShowText','on');
            pL5=plot(axA5,d.ORNLvect_f,d.ORNLvect_f./d.lambdaop,'b-','LineWidth',2);
            px5a=plot(axA5,NaN,NaN,'r-','LineWidth',2); px5b=plot(axA5,NaN,NaN,'k-');
            legend(axA5,[px5a,px5b,pL5],'R limits','C_{PN}/C_{P,max}','\lambda_{op}','Location','NE');
            title(axA5,'');
            xlabel(axA5,'\Omega R_{NL} [m/s]'); ylabel(axA5,'V_N [m/s]');
            xlim(axA5,[min(d.ORNLvect_f) max(d.ORNLvect_f)]);
            ylim(axA5,[min(d.VNvect_f) max(d.VNvect_f)]);
        end

        % Potencia & Control
        if ~isempty(appState.resPC)
            d   = appState.resPC;
            pc  = d.pc;
            cc  = d.cc;
            PNpc = d.PNpc;
            R    = d.R;

            cla(axPC); hold(axPC,'on');
            plot(axPC, pc.V, pc.P*1e-6, 'b-', 'LineWidth', 2);
            pVN   = plot(axPC, pc.VN,   PNpc*1e-6, 'o', ...
                         'MarkerSize',7,'MarkerEdgeColor',[0.8 0.1 0.1],'MarkerFaceColor',[1 0.5 0.5]);
            pVORN = plot(axPC, pc.VORN, pc.P_VORN*1e-6, 's', ...
                         'MarkerSize',7,'MarkerEdgeColor',[0.1 0.1 0.8],'MarkerFaceColor',[0.5 0.5 1]);
            yline(axPC, PNpc*1e-6,'r--','LineWidth',1.5);
            xlabel(axPC,'V [m/s]'); ylabel(axPC,'P [MW]');
            title(axPC, sprintf('Curva de Potencia | R=%.1f m, V_N=%.2f m/s, K_V=%.3f', R, pc.VN, pc.KV));
            legend(axPC,'P(V)', ...
                   sprintf('V_N=%.2f m/s',pc.VN), ...
                   sprintf('V_{\\OmegaN}=%.2f m/s',pc.VORN), ...
                   'P_N','Location','SE');
            ylim(axPC,[0, 1.1*PNpc*1e-6]);
            grid(axPC,'on');

            drawCC(axCC_P,  'V [m/s]','P [W]',         '', cc.V1221vect, cc.P1221,     cc.Vvect, cc.Pvect);
            drawCC(axCC_Q,  'V [m/s]','Q [N·m]',       '', cc.V1221vect, cc.Q1221,     cc.Vvect, cc.Qvect);
            drawCC(axCC_Om, 'V [m/s]','\Omega [rad/s]','', cc.V1221vect, cc.Omega1221, cc.Vvect, cc.Omegavect);

            cla(axCC_th); hold(axCC_th,'on');
            legHandles = gobjects(0); legLabels = {};
            if ~isempty(cc.V1221vect)
                h1 = plot(axCC_th, cc.V1221vect, cc.thetaC1221Pitch,'m-','LineWidth',2);
                h2 = plot(axCC_th, cc.V1221vect, cc.thetaC1221AS,   'g-','LineWidth',2);
                legHandles = [legHandles, h1, h2];
                legLabels  = [legLabels, {'V.P. Sin rest.','A.S. Sin rest.'}];
            end
            h3 = plot(axCC_th, cc.Vvect, cc.thetaCPitch,  'b-','LineWidth',2);
            h4 = plot(axCC_th, cc.Vvect, cc.thetaCAS,      'r-','LineWidth',2);
            h5 = plot(axCC_th, cc.V1plus2, cc.thetaC1plus2,'k-','LineWidth',2);
            legHandles = [legHandles, h3, h4, h5];
            legLabels  = [legLabels, {'V.P. Con rest.','A.S. Con rest.','\theta_0'}];
            xlabel(axCC_th,'V [m/s]'); ylabel(axCC_th,'\theta_C [rad]');
            legend(axCC_th, legHandles, legLabels, 'Location','Best');
            grid(axCC_th,'on');

            drawCC(axCC_CP, 'V [m/s]','C_P','', cc.V1221vect, cc.CP1221, cc.Vvect, cc.CPvect);
            drawCC(axCC_CQ, 'V [m/s]','C_Q','', cc.V1221vect, cc.CQ1221, cc.Vvect, cc.CQvect);
        end
    end

    % ================================================================
    %  DIAGNÓSTICOS
    % ================================================================

    % Optimización
    function lines = buildDiagOpt(out, airfoils)
        lines = {};
        betz  = 16/27;
        ok    = true;

        % 1. Cp vs Betz
        if out.CPstar > betz
            lines{end+1} = sprintf('❌ C_P* = %.4f > límite de Betz (%.4f)', out.CPstar, betz);
            ok = false;
        else
            lines{end+1} = sprintf('✅ C_P* = %.4f  (Betz: %.4f)', out.CPstar, betz);
        end


        % 2. Polares: rango de alpha disponible
        for ii = 1:numel(airfoils)
            fname = ['data-' airfoils{ii} '.csv'];
            if isfile(fname)
                try
                    T = readtable(fname);
                    alphaCol = T{:,1};
                    lines{end+1} = sprintf('✅ Polar %s: α ∈ [%.1f°, %.1f°]', ...
                        airfoils{ii}, min(alphaCol), max(alphaCol));
                catch
                    lines{end+1} = sprintf('⚠️  No se pudo leer polar: %s', airfoils{ii});
                    ok = false;
                end
            else
                lines{end+1} = sprintf('⚠️  Archivo no encontrado: %s', fname);
                ok = false;
            end
        end

        if ok
            lines{end+1} = '✅ Sin advertencias.';
        end
    end

    % Análisis
    function lines = buildDiagAnal(Rmat, FCmat, CPNmat, KVmat_phys, RminSP, RmaxSP)
        lines = {};
        ok = true;

        % NaN en malla
        nNaN = sum(isnan(Rmat(:)));
        if nNaN > 0
            lines{end+1} = sprintf('⚠️  %d puntos NaN en la malla R (interpolación incompleta)', nNaN);
            ok = false;
        else
            lines{end+1} = '✅ Malla interpolada sin NaN';
        end

        % Rango de R
        lines{end+1} = sprintf('ℹ️  R_SP ∈ [%.1f, %.1f] m  (banda de carga específica)', RminSP, RmaxSP);

        % FC: factor de capacidad
        if any(FCmat(:) > 1)
            lines{end+1} = '⚠️  FC > 1 en algún punto (revisar parámetros Weibull)';
            ok = false;
        else
            lines{end+1} = sprintf('✅ FC ∈ [%.2f, %.2f]', min(FCmat(:)), max(FCmat(:)));
        end

        % CPN/CPmax
        cpnMin = min(CPNmat(:)); cpnMax = max(CPNmat(:));
        if cpnMin < 0 || cpnMax > 1
            lines{end+1} = sprintf('⚠️  C_PN/C_P,max ∈ [%.2f, %.2f] (se esperaba [0,1])', cpnMin, cpnMax);
            ok = false;
        else
            lines{end+1} = sprintf('✅ C_PN/C_P,max ∈ [%.2f, %.2f]', cpnMin, cpnMax);
        end

        % KV
        kvMin = min(KVmat_phys(:)); kvMax = max(KVmat_phys(:));
        if kvMax > 1.2
            lines{end+1} = sprintf('ℹ️  K_V_max = %.2f > 1.2 (algunos puntos fuera del rango operativo normal)', kvMax);
        else
            lines{end+1} = sprintf('✅ K_V ∈ [%.2f, %.2f]', kvMin, kvMax);
        end

        if ok
            lines{end+1} = '✅ Sin advertencias relevantes.';
        end
    end

    % Potencia & Control
    function lines = buildDiagPC(pc, cc, PNpc)
        lines = {};
        ok = true;

        % VN encontrada
        if isnan(pc.VN)
            lines{end+1} = '❌ No se encontró V_N (fzero no convergió)';
            ok = false;
        else
            lines{end+1} = sprintf('✅ V_N = %.2f m/s  |  V_{ΩN} = %.2f m/s', pc.VN, pc.VORN);
        end

        % KV rango
        if pc.KV < 0.8 || pc.KV > 1.2
            lines{end+1} = sprintf('⚠️  K_V = %.3f fuera del rango operativo típico [0.8, 1.2]', pc.KV);
            ok = false;
        else
            lines{end+1} = sprintf('✅ K_V = %.3f  (rango [0.8, 1.2])', pc.KV);
        end

        % Potencia máxima vs nominal
        Pmax = max(pc.P);
        if Pmax > 1.02 * PNpc
            lines{end+1} = sprintf('⚠️  P_max = %.3f MW > P_N = %.3f MW (pico no recortado)', ...
                Pmax*1e-6, PNpc*1e-6);
            ok = false;
        else
            lines{end+1} = sprintf('✅ P_max = %.3f MW ≤ P_N', Pmax*1e-6);
        end

        % Ángulo de pitch máximo
        if ~isempty(cc.thetaCPitch)
            thMax = max(cc.thetaCPitch);
            if thMax > deg2rad(30)
                lines{end+1} = sprintf('⚠️  θ_C,pitch_max = %.1f° > 30°', rad2deg(thMax));
            else
                lines{end+1} = sprintf('✅ θ_C,pitch_max = %.1f°', rad2deg(thMax));
            end
        end

        % CP en curvas de control
        if ~isempty(cc.CPvect) && max(cc.CPvect) > 16/27
            lines{end+1} = sprintf('⚠️  C_P_max (c.control) = %.4f > Betz', max(cc.CPvect));
            ok = false;
        end

        if ok
            lines{end+1} = '✅ Sin advertencias relevantes.';
        end
    end

end

% =========================================================================
%  Dibujar una curva de control
% =========================================================================
function drawCC(ax, xLabel, yLabel, ~, Vsin, Ysin, Vcon, Ycon)
    cla(ax); hold(ax,'on');
    legH = gobjects(0); legL = {};
    if ~isempty(Vsin)
        h1 = plot(ax, Vsin, Ysin, 'r-','LineWidth',2);
        legH(end+1) = h1; legL{end+1} = 'Sin rest. ruido';
    end
    h2 = plot(ax, Vcon, Ycon, 'b-','LineWidth',2);
    legH(end+1) = h2; legL{end+1} = 'Con rest. ruido';
    xlabel(ax, xLabel); ylabel(ax, yLabel);
    legend(ax, legH, legL, 'Location','Best');
    xlim(ax, [min(Vcon), max(Vcon)]);
    grid(ax,'on');
end
