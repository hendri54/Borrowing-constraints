function [vWork, vColl, zWork, zColl] = college_entry(v1S, vWorkS, j, paramS, cS)
% College entry decision
%{
IN
   v1S
      value function in college at period 1
   vWorkS
      value of working

OUT
   vWork, vColl
      value of work, college
      without pref shocks!
   zWork, zColl
      parental transfers for both cases
      NOT annualized

Inefficient +++
   corners are hard to solve for
%}

% We think of the parent have collLength times earnings and consumption
nPeriods = cS.collLength;

% Annual income
yParent = paramS.yParent_jV(j);

% Range for z (annual)
zMin = 0;
zMax = min((yParent - cS.cFloor), paramS.kMax ./ nPeriods);
if zMax <= 0
   error_bc1('Not feasible', cS);
end


%% College option

% Continuous approximation of value in college
v1Fct = griddedInterpolant(v1S.kGridV, v1S.value_kjM(:,j), 'pchip', 'linear');

% Find optimal z conditional on college entry
[zColl, ~, exitFlag] = fminbnd(@coll_value, zMin, zMax, cS.fminbndOptS);
if exitFlag <= 0
   error_bc1('No solution found', cS);
end

% Value of college
vColl = -coll_value(zColl);


%% Work option

% Continuous approximation of value of working
vWorkFct = griddedInterpolant(vWorkS.kGridV, vWorkS.value_ksjM(:,cS.iHSG,j), 'pchip', 'linear');

[zWork, ~, exitFlag] = fminbnd(@work_value, zMin, zMax, cS.fminbndOptS);
if exitFlag <= 0
   error_bc1('No solution found', cS);
end

vWork = -work_value(zWork);



%% Nested: College objective function
%{
The parent gives k1 = nPeriods * z
%}
   function value = coll_value(z)
      % Parent utility per period
      cParent = yParent - z;
      [~, uParent] = hh_bc1.util_parent(cParent, paramS, cS);
      value = -(nPeriods * uParent + v1Fct(nPeriods * z));
   end


%% Nested: Work objective function
   function value = work_value(z)
      % Parent utility
      cParent = yParent - z;
      [~, uParent] = hh_bc1.util_parent(cParent, paramS, cS);
%      [~, vWork] = hh_bc1.hh_work_bc1(nPeriods * z, cS.iHSG, iAbil, paramS, cS);
%      value = -(nPeriods * uParent + vWork);
      value = -(nPeriods * uParent + vWorkFct(nPeriods * z));
   end
   
end