function [expS, tgS, pvec, doCalV, iCohort] = exp_settings(pvec, cS)
% Experiment settings
%{
By default, non-calibrated params are copied from base expNo
Can override this by setting switches such as expS.earnExpNo
Then pvEarn_asM is taken from that experiment (which would usually be the experiment
that calibrates everything for a particular cohort)

IN
   pvec
      pvector object with calibrated params

OUT
   expS
      struct with experiment settings
   tgS
      [] unless cal targets are modified
      must be copied back into cS if not []
   Items for cS:
      doCalV
         parameters with any value in doCalV are calibrated
      iCohort
         base cohort +++++
%}

expNo = cS.expNo;

% These experiments decompose time series changes into drivers
% Each column is a cohort
expS.decomposeExpNoM = [104 : 106; 114 : 116]';

% Do we modify calibration targets?
tgS = [];


%%  Which data based parameters are from another experiment?
% For counterfactuals
% Meaning: another cohort

% Earnings profiles (sets targets if calibrated, otherwise takes paramS.pvEarn_asM from base cohort)
expS.earnExpNo = [];
% College costs (values, NOT targets)
expS.collCostExpNo = [];
% expS.ypBaseCohort = 0;
% Cohort from which borrowing limits are taken
%  Never calibrated
expS.bLimitCohort = [];

% Does this experiment require recalibration?
expS.doCalibrate = 1;


% The reason for nested functions is an editor bug in Matlab
if expNo < 100
   base_exper;
elseif expNo < 200
   counterfactuals;
elseif expNo < 300
   time_series;
else
   error('Invalid');
end

return;


%% Nested:  Base experiments: calibrate everything to match all targets
function base_exper
   if expNo == cS.expBase
      expS.expStr = 'Baseline';
      % Parameters with these values of doCal are calibrated
      doCalV = cS.calBase;
      iCohort = cS.iRefCohort;  
      
   else
      error('Invalid');
   end
end
   
   
   
%% Nested:   Counterfactuals
% Nothing is calibrated  EXCEPT prefHS to match college entry.
% Params are copied from base
function counterfactuals
   expS.doCalibrate = 1;
   doCalV = cS.calExp;
   % Taking parameters from this cohort
   iCohort = cS.iRefCohort;

   % Match overall college entry. Calibrate only 1 param
   pvec = pvec.calibrate('prefHS', cS.calExp);
   % Only target school fractions
   tgS = calibr_bc1.caltg_defaults('onlySchoolFrac');
   
   % Pick out cohort from which counterfactuals are taken
   if expNo < 110
      cfBYear = 1940;   % Project talent
   elseif expNo < 120
      cfBYear = 1915;   % Updegraff
   else
      error('Invalid');
   end
   
   % Taking counterfactuals from this cohort (expNo)
   [~,cfCohort] = min(abs(cS.bYearV - cfBYear)); 
   cfExpNo = cS.bYearExpNoV(cfCohort); 

   if any(expNo == [103, 113])
      expS.expStr = 'Replicate base exper';    % for testing
      expS.earnExpNo = cS.expBase;
      expS.bLimitCohort = iCohort;
      expS.collCostExpNo = cS.expBase;

   elseif any(expNo == [104, 114])
      % Take pvEarn_asM from cfExpNo
      expS.expStr = 'Only change earn profiles'; 
      expS.earnExpNo = cfExpNo;

   elseif any(expNo == [105, 115])
      expS.expStr = 'Only change bLimit';    % when not recalibrated
      expS.bLimitCohort = cfCohort;

   elseif any(expNo == [106, 116])
      % Change college costs
      expS.expStr = 'College costs';
      % Need to calibrate everything for that cohort. Then impose pMean from there
      expS.collCostExpNo = cfExpNo;
      
   else
      error('Invalid');
   end
end
   
   
%% Nested:  Calibrated experiments
% A subset of params is recalibrated. The rest is copied from baseline
function time_series
   % Now fewer parameters are calibrated
   doCalV = cS.calExp;
   % Calibrate pMean, which is really a truncated data moment
   %  Should also do something about pStd +++
   pvec = pvec.calibrate('pMean', cS.calExp);

   % Calibrate all time varying parameters to match data for another cohort
   if any(expNo == cS.bYearExpNoV)
      % ******  Calibrate all time varying params
      iCohort = find(expNo == cS.bYearExpNoV);
      expS.expStr = sprintf('Cohort %i', cS.bYearV(iCohort));
      
      % Signal noise
      pvec = pvec.calibrate('alphaAM', cS.calExp);
      % Match transfers
      pvec = pvec.calibrate('puWeightMean', cS.calExp);
      % Match overall college entry
      pvec = pvec.calibrate('prefHS', cS.calExp);
      
      % Scale factors of lifetime earnings (log)
      pvec = pvec.calibrate('eHatCD', cS.calExp);
      pvec = pvec.calibrate('dEHatHSG', cS.calExp);
      pvec = pvec.calibrate('dEHatCG',  cS.calExp);
      
      % Keeping college wage fixed for now
      %pvec = pvec.calibrate('wCollMean', cS.calExp);
      

   elseif expNo == 211
      % This changes earnings, borrowing limits, pMean
      error('Not updated'); % +++++
      expS.expStr = 'Only change observables';   
      iCohort = cS.iRefCohort - 1;  % make one for each cohort +++
%       % Take all calibrated params from base
%       for i1 = 1 : pvec.np
%          ps = pvec.valueV{i1};
%          if ps.doCal == cS.calExp
%             % Do not calibrate, but take from base exper
%             pvec = pvec.calibrate(ps.name, cS.calBase);
%          end
%       end
      %pvec = pvec.calibrate('logYpMean', cS.calExp);
   
   else
      error('Invalid');
   end
end
   

end