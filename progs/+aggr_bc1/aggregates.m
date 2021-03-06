function aggrS = aggregates(hhS, paramS, cS)
% Compute aggregates
%{

Checked: 2015-Apr-3
%}


dbg = cS.dbg;
nIq = length(cS.iqUbV);
% Scale factor
aggrS.totalMass = 100;

% Holds debt stats
debtS.setNo = cS.setNo;
% Debt stats, assuming transfers paid out each period
%  Currently does not contain all debt stats
debtAltS.setNo = cS.setNo;
% Debt stats: all college students
debtAllS.setNo = cS.setNo;
% Debt stats: end of college
debtEndOfCollegeS.setNo = cS.setNo;


%%  By j,  [s,j],  [s,a]

% By j
[aggrS.prGrad_jV, aggrS.mass_jV, aggrS.massColl_jV, aggrS.massGrad_jV] = aggr_j(aggrS, hhS, paramS, cS);


% By [s,j]
[aggrS.mass_sjM, aggrS.probS_jM] = aggr_sj(aggrS, cS);


% By [s,a]
aggrS.mass_asM = aggr_as(aggrS, paramS, cS);


% By j - simulate histories in college
[aggrS.k_tjM, aggrS.hours_tjM, aggrS.cons_tjM, aggrS.earn_tjM, aggrS.kTrue_tjM] = ...
   sim_histories(hhS, paramS, cS);
% Debt levels (0 for those with positive k)
%  at end of years 2 and 4 in college
debt_tjM = max(0, -aggrS.k_tjM(2:3, :));


% By [school, IQ, j]
[sqS, aggrS.mass_sqjM, aggrS.fracEnter_qV, aggrS.fracGrad_qV] = ...
   aggr_bc1.aggr_sqj(aggrS, hhS, paramS, cS);


% By IQ quartile
[iqS, debtEndOfCollegeS.frac_qV, debtEndOfCollegeS.mean_qV] = ...
   aggr_bc1.aggr_iq(aggrS, hhS, paramS, cS);


%% Aggregates (college entrants)

% Mass of entrants by q
frac_qV = diff([0; cS.iqUbV]);
mass_qV = aggrS.fracEnter_qV .* frac_qV;
mass_qV = mass_qV ./ sum(mass_qV);

% Mean debt at end of college
debtS.debtMeanEndOfCollege = sum(debtEndOfCollegeS.mean_qV .* mass_qV(:));


% *********  Stats over first 2 years in college

aggrS.earnCollMeanYear2 = sum(iqS.earnCollMean_qV .* mass_qV(:));
aggrS.transferMeanYear2 = sum(iqS.transfer_qV .* mass_qV(:));
aggrS.hoursCollMeanYear2 = sum(iqS.hoursCollMean_qV .* mass_qV(:));
aggrS.pMeanYear2 = sum(iqS.pMean_qV .* mass_qV(:));
debtS.meanYear2 = sum(iqS.debtMeanYear2_qV .* mass_qV);
debtS.fracYear2 = sum(iqS.debtFracYear2_qV .* mass_qV);
clear mass_qV;

% Check
debtMeanYear2 = sum(aggrS.massColl_jV .* debt_tjM(1,:)') ./ sum(aggrS.massColl_jV);
if abs(debtMeanYear2 - debtS.meanYear2) > 1e-2
   error_bc1('Invalid debt year 2', cS);
end


% Mean debt of all college students
%  not conditional on having debt
%  we observe all entrants at t=1-2 and graduates in 3-4
debtAllS.mean = mean_coll_all(debt_tjM, aggrS.mass_sjM, cS);
% debtAllS.mean = sum(aggrS.massColl_jV' .* debt_tjM(1,:) + aggrS.mass_sjM(cS.iCG, :) .* debt_tjM(2,:)) ...
%    ./ sum(aggrS.massColl_jV + aggrS.mass_sjM(cS.iCG, :)');

% Consumption, average over college entrants, all years
aggrS.consCollMean = mean_coll_all(aggrS.cons_tjM, aggrS.mass_sjM, cS);
aggrS.earnCollMean = mean_coll_all(aggrS.earn_tjM, aggrS.mass_sjM, cS);
aggrS.pMean = mean_coll_all(ones([2,1]) * paramS.pColl_jV',  aggrS.mass_sjM, cS);
aggrS.zMean = mean_coll_all(ones([2,1]) * hhS.v0S.zColl_jV',  aggrS.mass_sjM, cS);


% ****** Financing shares

% Spending per year (average)
spending = aggrS.consCollMean + aggrS.pMean;
% Fraction paid with earnings
finS.fracEarnings = aggrS.earnCollMean / spending;
% Fraction paid with debt
finS.fracDebt = debtAllS.mean / spending;
% Fraction paid with transfers
finS.fracTransfers = aggrS.zMean / spending;



%% By [parental income class] (for those in college)

[ypS,  debtEndOfCollegeS.frac_yV, debtEndOfCollegeS.mean_yV, debtAltS.debtFrac_yV, debtAltS.debtMean_yV, ...
   aggrS.logYpMean_yV] = aggr_bc1.aggr_yp(aggrS, hhS, paramS, cS);


% By [IQ, yp]
qyS = aggr_bc1.aggr_qy(aggrS, hhS, paramS, cS);


%% By school

aggrS.mass_sV = sum(aggrS.mass_sjM, 2);
aggrS.mass_sV = aggrS.mass_sV(:);

aggrS.frac_sV = aggrS.mass_sV ./ sum(aggrS.mass_sV);


% Mean lifetime earnings, discounted to work start
aggrS.pvEarnMeanLog_sV = nan([cS.nSchool, 1]);
for iSchool = 1 : cS.nSchool
   mass_aV = aggrS.mass_asM(:, iSchool);
   aggrS.pvEarnMeanLog_sV(iSchool) = sum(mass_aV .* log(paramS.pvEarn_asM(:,iSchool))) ./ sum(mass_aV);
end


%% By graduation status

% *****  Debt at end of college
% indexed by [dropout, graduate]

% Fraction in debt
debtEndOfCollegeS.frac_sV = zeros([2,1]);
% Mean debt (not conditional on being in debt)
debtEndOfCollegeS.mean_sV = zeros([2,1]);

for i1 = 1 : 2
   if i1 == 1
      % Dropouts
      massColl_jV = aggrS.mass_sjM(cS.iCD, :);
      t = 2;
   elseif i1 == 2
      % Graduates
      massColl_jV = aggrS.mass_sjM(cS.iCG, :);
      t = 3;
   end
   
   % Mass of this school type by j
   massColl_jV = massColl_jV ./ sum(massColl_jV);
   % Assets at end of college by j
   k_jV = aggrS.k_tjM(t, :);

   % Find those types that are in debt
   dIdxV = find(k_jV < 0);
   if ~isempty(dIdxV)
      debtEndOfCollegeS.frac_sV(i1) = sum(massColl_jV(dIdxV));
      % Mean debt, not conditional on being in debt (b/c mass does not sum to 1)
      debtEndOfCollegeS.mean_sV(i1) = -sum(massColl_jV(dIdxV) .* k_jV(dIdxV));
   end
end
clear massColl_jV;

% Avoid rounding errors
debtEndOfCollegeS.frac_sV = min(1, debtEndOfCollegeS.frac_sV);

if dbg > 10
   validateattributes(debtEndOfCollegeS.frac_sV, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
      '>=', 0, '<=', 1})
   validateattributes(debtEndOfCollegeS.mean_sV, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
      '>=', 0})
end



%% For all college students
% Mostly computed earlier from stats by iq or yp

massColl = sum(aggrS.massColl_jV);
if massColl <= 0
   error_bc1('Invalid', cS);
end

% Mean and std of college costs (for those in college)
if any(aggrS.massColl_jV > 1e-6)
   aggrS.pStd = stats_lh.std_w(paramS.pColl_jV, aggrS.massColl_jV, dbg);
else
   aggrS.pStd = 0;
   %aggrS.pMean = 0;
end

% % Average hours and earnings
% %  first 2 years in college
% aggrS.hoursCollMean = sum(aggrS.massColl_jV .* aggrS.hours_tjM(1,:)') ./ massColl;
% aggrS.earnCollMean  = sum(aggrS.massColl_jV .* aggrS.earn_tjM(1,:)')  ./ massColl;




%% Clean up

aggrS.debtS = debtS;
aggrS.debtAltS = debtAltS;
aggrS.debtAllS = debtAllS;
aggrS.debtEndOfCollegeS = debtEndOfCollegeS;
aggrS.finS = finS;
aggrS.ypS = ypS;
aggrS.iqS = iqS;
aggrS.sqS = sqS;
aggrS.qyS = qyS;

if cS.dbg > 10
   % Consistency checks
   aggr_bc1.aggr_check(aggrS, cS);
end


end

%% ***********  Local functions start here


%% By j
function [prGrad_jV, mass_jV, massColl_jV, massGrad_jV] = aggr_j(aggrS, hhS, paramS, cS)

   % Prob grad conditional on entry = sum of Pr(a|j) * Pr(grad|a)
   prGrad_jV = nan([cS.nTypes, 1]);
   for j = 1 : cS.nTypes
      prGrad_jV(j) = sum(paramS.prob_a_jM(:,j) .* paramS.prGrad_aV);
   end
   if cS.dbg > 10
      validateattributes(prGrad_jV, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
         'positive', '<', 1, 'size', [cS.nTypes, 1]})
   end

   % Defines total mass
   mass_jV = paramS.prob_jV * aggrS.totalMass;
   
   % Mass in college by j
   massColl_jV = mass_jV .* hhS.v0S.probEnter_jV;
   if cS.dbg > 10
      validateattributes(massColl_jV, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
         '>=', 0, 'size', [cS.nTypes, 1]})
   end   
   
   massGrad_jV = massColl_jV .* prGrad_jV;
end



%% By [s, j]
function [mass_sjM, probS_jM] = aggr_sj(aggrS, cS)

   sizeV = [cS.nSchool, cS.nTypes];
   mass_sjM = zeros(sizeV);
   mass_sjM(cS.iHSG,:) = aggrS.mass_jV - aggrS.massColl_jV;
   mass_sjM(cS.iCD,:) = aggrS.massColl_jV .* (1 - aggrS.prGrad_jV);
   mass_sjM(cS.iCG,:) = aggrS.massColl_jV .* aggrS.prGrad_jV;

   if cS.dbg > 10
      validateattributes(mass_sjM, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
         '>=', 0, 'size', sizeV})
      sumV = sum(mass_sjM);
      if any(abs(sumV(:) - aggrS.mass_jV) > 1e-6)
         error('Invalid');
      end
   end


   % Prob s | j = Prob(s and j) / (prob j)
   probS_jM = mass_sjM ./ (ones([cS.nSchool,1]) * aggrS.mass_jV(:)');
end



%% By j - simulate histories in college
%{
kTrue_tjM
   asset path when transfers are paid out each period
%}
function [k_tjM, hours_tjM, cons_tjM, earn_tjM, kTrue_tjM] = sim_histories(hhS, paramS, cS)
% Path of assets in college; at start, after periods 2, 4 in college
%  at START of each period
%  restrict kPrime to be inside k grid for t+1

   dbg = cS.dbg;

   k_tjM = nan([3, cS.nTypes]);

   % Hours in college (first 2 years, 2nd 2 years)
   hours_tjM = nan([2, cS.nTypes]);
   % Consumption phases 1 and 2 in college
   cons_tjM = nan([2, cS.nTypes]);
   
   % This is the capital series we would observe if transfers were paid out in each period
   kTrue_tjM = nan([3, cS.nTypes]);

   % Everyone starts with the parental transfer
   %  limited to inside of grid
   k_tjM(1,:) = max(hhS.v1S.kGridV(1), min(hhS.v1S.kGridV(end), hhS.v0S.k1Coll_jV));
   % True endowments are 0
   kTrue_tjM(1,:) = 0;
   
   % Transfer while in college
   zColl_jV = hhS.v0S.zColl_jV;


   % ******  Periods 1-2 (ability not known)

   kMax = hhS.vColl3S.kGridV(end);
   kPrimeV = nan([cS.nTypes, 1]);
   for j = 1 : cS.nTypes
      % Current k
      k = k_tjM(1,j);
      kPrimeV(j) = interp1(hhS.v1S.kGridV, hhS.v1S.kPrime_kjM(:,j), k, 'linear', 'extrap');
      hours_tjM(1,j) = interp1(hhS.v1S.kGridV, hhS.v1S.hours_kjM(:,j), k, 'linear', 'extrap');
      cons_tjM(1,j) = interp1(hhS.v1S.kGridV, hhS.v1S.c_kjM(:,j), k, 'linear', 'extrap');
      
      % Find true kPrime from budget constraint
      %  Add the transfer
      kTrue_tjM(2,j) = hh_bc1.coll_bc_kprime(cons_tjM(1,j), hours_tjM(1,j), kTrue_tjM(1,j), ...
         paramS.wColl_jV(j), paramS.pColl_jV(j), paramS.R, cS) + 2 * zColl_jV(j);

      if dbg > 10
         % Check that b.c. holds
         kp2 = hh_bc1.coll_bc_kprime(cons_tjM(1,j), hours_tjM(1,j), k, ...
            paramS.wColl_jV(j), paramS.pColl_jV(j), paramS.R, cS);
         if abs(min(kp2, kMax) - kPrimeV(j)) > 1e-3
            error_bc1('bc violated', cS);
         end
      end
   end
   % Restrict inside period 3 k grid
   k_tjM(2,:) = max(hhS.vColl3S.kGridV(1), min(kMax, kPrimeV));


   % *******  Periods 3-4 in college (ability known)

   for j = 1 : cS.nTypes
      % Current k
      k = k_tjM(2,j);
      kTrue = kTrue_tjM(2,j);

      % Prob(a | j, college)
      %  Prob(college | a) = prob(grad | a). Only those who graduate stay
      prob_aV = paramS.prob_a_jM(:,j) .* paramS.prGrad_aV;
      prob_aV = prob_aV ./ sum(prob_aV);

      kPrime_aV = nan([cS.nAbil, 1]);
      hours_aV = nan([cS.nAbil, 1]);
      cons_aV = nan([cS.nAbil, 1]);
      % Keeping track of case where transfers are paid out each period
      kPrimeTrue_aV = nan([cS.nAbil, 1]);
      for iAbil = 1 : cS.nAbil
         kPrime_aV(iAbil) = interp1(hhS.vColl3S.kGridV, hhS.vColl3S.kPrime_kajM(:,iAbil,j), k, 'linear', 'extrap');
         hours_aV(iAbil)  = interp1(hhS.vColl3S.kGridV, hhS.vColl3S.hours_kajM(:,iAbil,j), k, 'linear', 'extrap');
         cons_aV(iAbil)   = interp1(hhS.vColl3S.kGridV, hhS.vColl3S.c_kajM(:,iAbil,j), k, 'linear', 'extrap');

         % Find true kPrime from budget constraint
         %  Add the transfer
         kPrimeTrue_aV(iAbil) = hh_bc1.coll_bc_kprime(cons_aV(iAbil), hours_aV(iAbil), kTrue, ...
            paramS.wColl_jV(j), paramS.pColl_jV(j), paramS.R, cS) + 2 * zColl_jV(j);

         if dbg > 10
            % Check that b.c. holds
            kp2 = hh_bc1.coll_bc_kprime(cons_aV(iAbil), hours_aV(iAbil), k, ...
               paramS.wColl_jV(j), paramS.pColl_jV(j), paramS.R, cS);
            if abs(min(kp2, kMax) - kPrime_aV(iAbil)) > 1e-3
               error_bc1('bc violated', cS);
            end
         end
      end

      % Average choices for each j type (conditional on staying in college)
      %  No need to restrict k' to be inside a grid
      k_tjM(3,j) = sum(prob_aV .* kPrime_aV);
      hours_tjM(2,j) = sum(prob_aV .* hours_aV);
      cons_tjM(2,j) = sum(prob_aV .* cons_aV);
      kTrue_tjM(3,j) = sum(prob_aV .* kPrimeTrue_aV);
   end

   earn_tjM = hours_tjM .* (ones([2,1]) * paramS.wColl_jV(:)');

   if cS.dbg > 10
      validateattributes(k_tjM, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
         'size', [3, cS.nTypes]})
      validateattributes(hours_tjM, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', '>=', 0, ...
         '<=', 1, 'size', [2, cS.nTypes]})
      validateattributes(earn_tjM,  {'double'}, {'finite', 'nonnan', 'nonempty', 'real', '>=', 0, ...
         'size', [2, cS.nTypes]})
   end
end



%% By [school, abil]
function mass_asM = aggr_as(aggrS, paramS, cS)

mass_asM = nan([cS.nAbil, cS.nSchool]);

% HSG: Mass(HSG,j) * Pr(a | j)
for iAbil = 1 : cS.nAbil
   mass_asM(iAbil, cS.iHSG) = aggrS.mass_sjM(cS.iHSG, :) * paramS.prob_a_jM(iAbil, :)';
end

% College: 
for iAbil = 1 : cS.nAbil
   % Mass college with this a
   massColl = paramS.prob_a_jM(iAbil,:) * aggrS.massColl_jV;
   %  CG: mass(college,a) * pr(grad|a)
   mass_asM(iAbil, cS.iCG) = paramS.prGrad_aV(iAbil) * massColl;
   mass_asM(iAbil, cS.iCD) = (1 - paramS.prGrad_aV(iAbil)) * massColl;
end

if cS.dbg > 10
   validateattributes(mass_asM, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
      '>=', 0, 'size', [cS.nAbil, cS.nSchool]})
   mass_aV = sum(mass_asM, 2);
   if any(abs(mass_aV(:) ./ (aggrS.totalMass .* paramS.prob_aV) - 1) > 1e-4)
      error_bc1('Invalid sum', cS);
   end
end


% 
% aggrS.mass_sajM = zeros([cS.nSchool, cS.nAbil, cS.nTypes]);
% 
% for j = 1 : cS.nTypes
%    % No college: Pr(HSG,j) * Pr(a | j)
%    aggrS.mass_sajM(cS.iHSG, :, j) = aggrS.mass_sjM(cS.iHSG,j) .* paramS.prob_a_jcM(:,j,iCohort);
%    
%    % College
%    mass = aggrS.massColl_jV(j);
%    if mass > 0
%       % Pr(enter,a,j) = mass(enter,j) * Pr(a|j)
%       mass_aV = mass .* paramS.prob_a_jcM(:,j,iCohort);
%       
%       for iSchool = [cS.iCD, cS.iCG]
%          if iSchool == cS.iCD
%             prob_s_aV = 1 - paramS.prGrad_acM(:,iCohort);
%          else
%             prob_s_aV = paramS.prGrad_acM(:,iCohort);
%          end
%          
%          % Pr(CD,a,j) = Pr(enter,a,j) * Pr(drop | enter,a)
%          aggrS.mass_sajM(iSchool,:,j) = mass_aV(:) .* prob_s_aV;
%       end
%    end   
% end
% 
% if dbg > 10
%    validateattributes(aggrS.mass_sajM, {'double'}, {'finite', 'nonnan', 'nonempty', 'real', ...
%       '>=', 0, 'size', [cS.nSchool, cS.nAbil, cS.nTypes]})
% end
% 

end




%% Compute average across all college students
%{
IN
   x_tjM
      any variable by year in college (1-2, 3-4) and j
   mass_sjM
OUT
   Mean of x over all college students
%}
function meanOut = mean_coll_all(x_tjM, mass_sjM, cS)
   massColl_jV = sum(mass_sjM(cS.iCD : cS.nSchool, :), 1);
   massCG_jV = mass_sjM(cS.iCG,:);
   meanOut = sum(massColl_jV(:) .* x_tjM(1,:)' + massCG_jV(:) .* x_tjM(2,:)') ...
      ./ sum(massColl_jV(:) + massCG_jV(:));   
end