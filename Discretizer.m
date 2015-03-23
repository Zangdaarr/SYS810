classdef Discretizer < handle
    
    properties (SetAccess = private, GetAccess = private)
        
        mT;
        mContinuousTf;
        
        %Matrices de transfer:
        mQHalijak;
        mQBoxer;
        
    end
    
    methods %Public
        
        %Constructors
        function oInstance = Discretizer(iT, varargin)
            if nargin == 2
                oInstance.mContinuousTf = varargin{1};
            elseif nargin == 3
                oInstance.mContinuousTf = tf(varargin{1},varargin{2});
            else
                oInstance.mContinuousTf = 0;
                h = errordlg('Invalid constructor');
                waitfor(h);
            end
            
            oInstance.mSetSampleTime(iT);
            
        end
        
        %Public methods
        
        %Accessors
        
        function mSetSampleTime(iThis,iSampleTime)
            iThis.mT = iSampleTime;
            mUpdateMatrix(iThis);
        end
        
        function oSampleTime = mGetSampleTime(iThis)
            oSampleTime = iThis.mT;
        end
        
        function oMatrix = mGetHalijakMatrix(iThis,iRank)
            oMatrix = iThis.mQHalijak{iRank};
        end
        
        function oMatrix = mGetBoxerThalerMatrix(iThis,iRank)
            oMatrix = iThis.mQBoxer{iRank};
        end
        
        function oTf = mGetTf(iThis)
            oTf = iThis.mContinuousTf;
        end
        
        %Compute discrete TF
        function varargout = mGetDiscreteTf(iThis,iType)
            
            wDiscreteTf = mProcessTf(iThis,iThis.mContinuousTf,iType);
            
            if (nargout == 0) || (nargout == 1)
                varargout{1} = wDiscreteTf;
            elseif nargout == 2
                [wHnum,wHden] = tfdata(wDiscreteTf,'v');
                varargout{1} = wHnum./wHden(1);
                varargout{2} = wHden./wHden(1);
            else
                h = errordlg('Invalid number of output arguments, valids outputs are (Tf) or (NumTf,DenTf)');
                waitfor(h)
            end
            
        end
        
        %Compute closed loop TF.
        function varargout = mGetClosedLoop(iThis,iFeedBackTf,iType)
            
            wDiscreteTf = mProcessTf(iThis,iThis.mContinuousTf,iType);
            wDiscreteFeedBackTf = mProcessTf(iThis,iFeedBackTf,iType);
            
            wCLTF = feedback(wDiscreteTf,wDiscreteFeedBackTf);
            
            if (nargout == 0) || (nargout == 1)
                varargout{1} = wCLTF;
            elseif nargout == 2
                [wHnum,wHden] = tfdata(wCLTF,'v');
                varargout{1} = wHnum;
                varargout{2} = wHden;
            else
                h = errordlg('Invalid number of output arguments, valids outputs are (Tf) or (NumTf,DenTf)');
                waitfor(h)
            end
            
        end
        
        %Compute discrete TF and apply retard
        function varargout = mGetRetardedDiscreteTf(iThis,iType,iRetard)
            
            wHnum    = 0; %#ok<NASGU>
            wHden    = 0; %#ok<NASGU>
            wRetard  = ones(1,iRetard);
            
            [wHnum,wHden] = mGetDiscreteTf(iThis,iType);
            wHden         = [wRetard,wHden];
            
            if (nargout == 0) || (nargout == 1)
                varargout{1} = tf(wHnum,wHden,iThis.mT);
            elseif nargout == 2
                varargout{1} = wHnum;
                varargout{2} = wHden;
            else
                h = errordlg('Invalid number of output arguments, valids outputs are (Tf) or (NumTf,DenTf)');
                waitfor(h)
            end
        end
        
        %Compute discrete TF and apply retard
        function [A,B,C,D] = mGetStateSpaceMatrix(iThis,iType)
            
            switch (iType)
                case 'observable'
                    
                    [A,B,C,D] = iThis.mProcessObservableState();
                    
                otherwise
                    h = errordlg('Invalid Type, returning null matrixes');
                    waitfor(h)
                    A = 0;
                    B = 0;
                    C = 0;
                    D = 0;
            end
        end
        %Execute recursion equation with the specified input, on the
        %specified typed discrete function.
        function Y = mComputeRecursion(iThis,U,iType)
            
            [wNum,wDen] = iThis.mGetDiscreteTf(iType);
            Y = iThis.mProcessRecursion(wNum,wDen,U);
            
        end
        
    end %Public methods
    
    %Private methods
    methods (Access = private)
        
        %Updates all matrixes when requested
        function mUpdateMatrix(iThis)
            mUpdateBoxerThalerMatrix(iThis);
            mUpdateHalijakMatrix(iThis);
        end
        
        %Halijak substitution matrix
        function mUpdateHalijakMatrix(iThis)
            
            mQ1=...
                [iThis.mT,  0;...
                1, -1];
            
            mQ2=...
                [0, iThis.mT^2, 0;...
                iThis.mT, -iThis.mT,  0;...
                1,  -2,  1];
            
            mQ3=...
                [0,  iThis.mT^3/2, iThis.mT^3/2, 0;...
                0,   iThis.mT^2,  -iThis.mT^2,   0;...
                iThis.mT, -2*iThis.mT,   iThis.mT,     0;...
                1,  -3,      3,     -1];
            
            mQ4 =...
                [0,  iThis.mT^4/4,  2*iThis.mT^4/4,  iThis.mT^4/4 , 0;...
                0,   iThis.mT^3/2,  0       , -iThis.mT^3/2 , 0;...
                0,   iThis.mT^2  , -2*iThis.mT^2  ,  iThis.mT^2   , 0;...
                iThis.mT, -3*iThis.mT  ,  3*iThis.mT    , -iThis.mT     , 0;...
                1,  -4    ,   6       , -4      , 1];
            
            iThis.mQHalijak = {mQ1, mQ2, mQ3, mQ4};
            
        end
        
        %Boxer Thalor substitution matrix
        function mUpdateBoxerThalerMatrix(iThis)
            
            mQ1=...
                [iThis.mT/2,  iThis.mT/2;...
                1         , -1];
            
            mQ2=...
                [iThis.mT^2/12, 10*iThis.mT^2/12, iThis.mT^2/12;...
                iThis.mT/2   , 0              , -iThis.mT/2;...
                1,            -2              ,  1];
            
            mQ3=...
                [0           ,    iThis.mT^3/2 ,    iThis.mT^3/2 ,  0;...
                iThis.mT^2/12,  9*iThis.mT^2/12, -9*iThis.mT^2/12, -iThis.mT^2/12;...
                iThis.mT/2   , -1*iThis.mT/2   , -1*iThis.mT/2   ,  iThis.mT/2;...
                1            , -3             ,   3              , -1];
            
            mQ4 =...
                [-iThis.mT^4/720,  124*iThis.mT^4/720,  474*iThis.mT^4/720,  124*iThis.mT^4/720, -iThis.mT^4/720;...
                0               ,   iThis.mT^3/2     ,  0                 , -iThis.mT^3/2      , 0;...
                iThis.mT^2/12   ,   8*iThis.mT^2/12  , -18*iThis.mT^2/12  ,  8*iThis.mT^2/12   , iThis.mT^2/12;...
                iThis.mT/2      , -iThis.mT          , 0                  ,  iThis.mT          , -iThis.mT/2;...
                1               ,  -4                ,   6                , -4                 , 1];
            
            iThis.mQBoxer = {mQ1, mQ2, mQ3, mQ4};
            
        end
        
        %Execute recursion equation with the specified input.
        function Y = mProcessRecursion(iThis,num,den,U)
            
            iThis; %#ok<VUNUS>
            
            wTrimedDen = den(find(den,1):size(den,2));
            wTrimedNum = num(find(num,1):size(num,2));
            
            %How many iterations of Y are not computable.
            %If the system is implicit, then wUdelta = 0
            wUdelta = size(wTrimedDen,2)-size(wTrimedNum,2);
            if (wUdelta < 0)
                h = errordlg('Error, non-causal system');
                waitfor(h);
                return;
            end
            
            Y = zeros(1,wUdelta);
            
            for i = size(Y,2)+1:size(U,2)
                
                wY = 0;
                wU = 0;
                
                %Building input sum according to matlab 1-based indexing
                for k = 1:size(wTrimedNum,2)
                    if(i-k+1-wUdelta > 0)
                        wU = wU + wTrimedNum(k)*U(i-k+1-wUdelta);
                    else
                        wU = wU + 0;
                    end
                end
                
                %Building output sum according to matlab 1-based indexing
                for k = 1:size(wTrimedDen,2)-1
                    if((i-k > 0) && (i-k <= size(Y,2)))
                        wY = wY + wTrimedDen(k+1)*Y(i-k);
                    else
                        wY = wY + 0;
                    end
                end
                
                %Sum must be pondered by the highest numerator coefficient
                Y(i) = 1/wTrimedDen(1) * (-wY + wU);
                
            end
        end
        
        %Process TF conversions.
        function oTf = mProcessTf(iThis,iTf,iType)
            
            wTf      = iTf;
            wHnum    = 0; %#ok<NASGU>
            wHden    = 0; %#ok<NASGU>
            
            if (strcmp(get(iTf,'Variable'),'s'))
                switch (iType)
                    case 'zoh'
                        
                        wTf = c2d(iTf,iThis.mT,'zoh');
                        
                    case 'tutsin'
                        
                        wTf = c2d(iTf,iThis.mT,'tutsin');
                        
                    case {'halijak','boxerThaler'}
                        
                        [wHnum,wHden] = tfdata(iTf,'v');
                        
                        if(strcmp(iType,'halijak'))
                            wH = [fliplr(wHnum);fliplr(wHden)]*iThis.mGetHalijakMatrix(size(wHden,2)-1);
                        else
                            wH = [fliplr(wHnum);fliplr(wHden)]*iThis.mGetBoxerThalerMatrix(size(wHden,2)-1);
                        end
                        
                        wTf = tf(wH(1,:),wH(2,:),iThis.mT);
                        
                    case 'continuous'
                        %Return input
                        
                    otherwise
                        warning('mProcessTf returning input (continuous) TF')
                end
                
            else
                switch (iType)
                    case 'zoh'
                        
                        wTf = d2d(iTf,iThis.mT,'zoh');
                        
                    case 'tutsin'
                        
                        wTf = d2d(iTf,iThis.mT,'tutsin');
                        
                    otherwise
                        
                        warning('mProcessTf returning input (discrete) TF')
                end
                
            end
            
            oTf = wTf;
            
        end
        
        %Process state space
        function [A,B,C,D] = mProcessObservableState(iThis)
            
            wOneBaseBias = 1;
            
            %Get transfert function polynomials and set them in a proper
            %matlab order, opposed to polynomial order (aka [a(0),a(1),...,a(n-1),a(n)])
            [wNum,wDen] = tfdata(iThis.mGetTf());
            wDen = fliplr(wDen{1});
            wNum = fliplr(wNum{1});
            wOrder = length(wDen)-1;
            
            %Compute A matrix
            A = diag(ones(1,wOrder-1),1);
            for i=0:wOrder-1
                A(wOrder,i+wOneBaseBias) = -wDen(i+wOneBaseBias)/wDen(length(wDen));
            end
            
            %Compute beta values
            wBetaMatrix = zeros(wOrder+1,1);
            for k=wOrder:-1:0
                s= 0;
                for i=1:wOrder-k
                    s = s + wDen(wOrder-i+wOneBaseBias)*wBetaMatrix(k+i+wOneBaseBias);
                end
                
                wBetaMatrix(k+wOneBaseBias) = wNum(k+wOneBaseBias) - s;
            end
            
            %Extract B & D matrixes from beta values. Note that beta matrix
            %is ordered in matlab order (aka: [b(0);b(1);...b(n-1);b(n)])
            %B needs to be inverted to be in the following order:
            %[b(n-1),b(n-2),...b(0)]
            B = wBetaMatrix(length(wBetaMatrix)-1:-1:1);
            D = wBetaMatrix(length(wBetaMatrix));
            
            %Compute C matrix.
            C = [1,zeros(1,wOrder-1)];
        end
        
    end %Private methods
    
end %Class

