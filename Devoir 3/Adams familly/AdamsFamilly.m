addpath(genpath('..\..'));

%Parametres
close all;
clear all; %#ok<CLSCR>
clc;

wSampleTime=0.05;
wSimulationTime=10;
wMaxStep=wSampleTime/1000;

wInputSignal=ones(1,wSimulationTime/wSampleTime);

wContinuousSystemNum = [100,0];
wContinuousSystemDen = [1,11,30,200];

wAdamsBashforthNum = [3,-1];
wAdamsBashforthDen = [2,-2,0];

%Objects initialization
wSystem = Discretizer(wSampleTime,...
    wContinuousSystemNum,...
    wContinuousSystemDen);

wPloter = Ploter([0 0 8 5],[8 5]);

%Stability study
% wABStabilityHandle = wPloter.mDrawStabilityRegion('Adam-Brashforth second order',wAdamsBashforthNum,wAdamsBashforthDen);
% wLambda = pole(wSystem.mGetTf);
% wSampleTimeList=0.01:0.01:0.1;
% 
% set(0,'currentfigure',wABStabilityHandle);
% for k=1:length(wSampleTimeList)
%     
%     wReal = [];
%     wImag = [];
%     
%     for h=1:length(wLambda)
%         
%         wReal = [wReal,wSampleTimeList(k)*real(wLambda(h))];
%         wImag = [wImag,wSampleTimeList(k)*imag(wLambda(h))];
%     end
%     
%     hold all;
%     scatter(wReal,wImag);
%     legend(get(legend(gca),'String'),num2str(wSampleTimeList(k)));
%     
% end


[Ao,Bo,Co,Do] = wSystem.mGetStateSpaceMatrix('observable');
[Ac,Bc,Cc,Dc] = wSystem.mGetStateSpaceMatrix('commandable');

%Parametrage simulation
model='adamsFamillyModel';
load_system(model)
tic

wSaveFileName     = 'Y';

set_param(model,'StopFcn','save(wSaveFileName,wSaveFileName)');
set_param(strcat(model,'/Output'),'VariableName',wSaveFileName);

%Parametrage simulation continue
set_param(strcat(model,'/Continuous'),'Numerator','wContinuousSystemNum');
set_param(strcat(model,'/Continuous'),'Denominator','wContinuousSystemDen');

set_param(strcat(model,'/Observable continuous model'),'a0','Ao(size(Ao,1),1)');
set_param(strcat(model,'/Observable continuous model'),'a1','Ao(size(Ao,1),2)');
set_param(strcat(model,'/Observable continuous model'),'a2','Ao(size(Ao,1),3)');

set_param(strcat(model,'/Observable continuous model'),'b0','Bo(3,1)');
set_param(strcat(model,'/Observable continuous model'),'b1','Bo(2,1)');
set_param(strcat(model,'/Observable continuous model'),'b2','Bo(1,1)');

set_param(strcat(model,'/Observable continuous model'),'b3','Do(1,1)');

set_param(strcat(model,'/Commandable continuous model'),'a0','Ac(size(Ac,1),1)');
set_param(strcat(model,'/Commandable continuous model'),'a1','Ac(size(Ac,1),2)');
set_param(strcat(model,'/Commandable continuous model'),'a2','Ac(size(Ac,1),3)');

set_param(strcat(model,'/Commandable continuous model'),'b0','Cc(1,1)');
set_param(strcat(model,'/Commandable continuous model'),'b1','Cc(1,2)');
set_param(strcat(model,'/Commandable continuous model'),'b2','Cc(1,3)');

%Parametrage AB_2
set_param(strcat(model,'/AB_2'),'a0','Ao(size(Ao,1),1)');
set_param(strcat(model,'/AB_2'),'a1','Ao(size(Ao,1),2)');
set_param(strcat(model,'/AB_2'),'a2','Ao(size(Ao,1),3)');

set_param(strcat(model,'/AB_2'),'b0','Bo(3,1)');
set_param(strcat(model,'/AB_2'),'b1','Bo(2,1)');
set_param(strcat(model,'/AB_2'),'b2','Bo(1,1)');

set_param(strcat(model,'/AB_2'),'b3','Do(1,1)');

set_param(strcat(model,'/AB_2'),'T','wSampleTime');

set_param(strcat(model,'/AB_2'),'HzNum','wAdamsBashforthNum');
set_param(strcat(model,'/AB_2'),'HzDen','wAdamsBashforthDen');

set_param(model, 'StopTime', 'wSimulationTime');

set_param(model, 'MaxStep', 'wMaxStep');

myopts=simset('SrcWorkspace','current','DstWorkspace','current');

sim(model,wSimulationTime,myopts);
while (strcmp(get_param(model,'SimulationStatus'),'stopped')==0);
end

t_sim = toc;
fprintf('\nTemps de simulation => %3.3g s\n',t_sim)

%Post traitement
load(wSaveFileName);
wStruct = eval('wSaveFileName');

%Plots

wPloter.mDrawTimeseriesPlot([Y.Continuous_signal,Y.Commandable_continuous,Y.Observable_continuous],...
    'Open Loop Response, continuous simulation','Time (s)','Step Response');

wPloter.mDrawTimeseriesPlot([Y.Observable_continuous,Y.Observable_Adams_Branshforth],...
    'Open Loop Response, Adams Branshforth','Time (s)','Step Response','stairs');


%Computing system using Predictor-Corrector

%Abscices
wSampleTime = 0.005;
t=linspace(0,wSimulationTime,wSimulationTime*(1/wSampleTime));

%Conditins initiaux
f1c(1) = 0;   f2c(1) = 0; f3c(1) = 1;
x1c(1) = 0;   x2c(1) = 0; x3c(1) = 0;

for n = 0:wSimulationTime/wSampleTime-2
    
    if (n == 0)        
        x1p(n+2) = x1c(n+1) + (wSampleTime/2)*(f1c(n+1));
        x2p(n+2) = x2c(n+1) + (wSampleTime/2)*(f2c(n+1));
        x3p(n+2) = x3c(n+1) + (wSampleTime/2)*(f3c(n+1));
    else        
        x1p(n+2) = x1c(n+1) + (wSampleTime/2)*(f1c(n+1)-f1c(n));
        x2p(n+2) = x2c(n+1) + (wSampleTime/2)*(f2c(n+1)-f2c(n));
        x3p(n+2) = x3c(n+1) + (wSampleTime/2)*(f3c(n+1)-f3c(n));
    end
    
    f1p(n+2) = x2p(n+2);
    f2p(n+2) = x3p(n+2);
    f3p(n+2) = -200*x1p(n+2) - 30*x2p(n+2) -11*x3p(n+2) + 1;
    
    x1c(n+2) = x1c(n+1) + (wSampleTime/2)*(f1p(n+2)+ f1c(n+1));
    x2c(n+2) = x2c(n+1) + (wSampleTime/2)*(f2p(n+2)+ f2c(n+1));
    x3c(n+2) = x3c(n+1) + (wSampleTime/2)*(f3p(n+2)+ f3c(n+1));
    
    f1c(n+2) = x2c(n+2);
    f2c(n+2) = x3c(n+2);
    f3c(n+2) = -200*x1c(n+2) - 30*x2c(n+2) -11*x3c(n+2) + 1;
    
end

wPloter.mDrawStandardPlot({Y.Observable_continuous.Time,Y.Observable_continuous.Data,t,100*x2c},...
    'stairs','Open Loop Response, Prediction-Correction vs Continuous simulation','Time (s)','Step Response',{'Commandable continuous';'Prediction-Correction'});

