function history_show(jV, setNo, expNo)
% Show a type's possible histories
%{
update for ability heterogeneity +++++
   need to compute expected marginal utilities
%}

cS = const_bc1(setNo, expNo);
paramS = param_load_bc1(setNo, expNo);
aggrS = var_load_bc1(cS.vAggregates, cS);
hhS = var_load_bc1(cS.vHhSolution, cS);

outFn = fullfile(cS.outDir, 'hh_histories.txt');
fp = fopen(outFn, 'w');

for j = jV(:)'
   fprintf(fp, '\n    ---------    \n');
   fprintf(fp, '\nLife history of type %i\n\n', j);

   % Pr(a|j)
   prob_aV = paramS.prob_a_jM(:,j);

   % *****  Parents

   fprintf(fp, 'Parents:  \n');
   yParent = paramS.yParent_jV(j);
   fprintf(fp, 'income (per year): %.1f \n',  yParent);


   % ******  Child work as HSG

   fprintf(fp, '\nWork as HSG:\n');

   % Transfer (per year)
   transfer = hhS.v0S.zWork_jV(j);
   % Consumption (per year)
   cParent = yParent - transfer;
   uPrime = hh_bc1.util_parent(cParent, paramS, cS);
   fprintf(fp, 'Parent:  transfer: %.1f   c: %.1f  uPrime: %.2f \n', transfer,  cParent,  100 * uPrime);

   k1 = hhS.v0S.k1Work_jV(j);
   % Expected marginal utility when working as HSG
   % Use ability level with highest probability
   uPrime_aV = nan([cS.nAbil, 1]);
   for iAbil = 1 : cS.nAbil
      cV = hh_bc1.hh_work_bc1(k1, cS.iHSG, iAbil, paramS, cS);
      cChild = cV(1);
      [~, uPrime_aV(iAbil)] = hh_bc1.util_work_bc1(cChild, paramS, cS);
   end
   eUprime = sum(prob_aV .* uPrime_aV);
   fprintf(fp, 'Child:   c: %.1f  uPrime: %.2f \n', cChild, 100 * eUprime);


   % ******  Child enters college

   fprintf(fp, '\nTry college:\n');

   transfer = hhS.v0S.zColl_jV(j);
   cParent = yParent - transfer;
   uPrime = hh_bc1.util_parent(cParent, paramS, cS);
   fprintf(fp, 'Parent:  transfer: %.1f   c: %.1f  uPrime: %.2f \n', transfer,  cParent,  100 * uPrime);

   fprintf(fp, 'Child:   coll cost: %.1f \n',  paramS.pColl_jV(j));
   % k1 = hhS.v0S.zColl_jV(j);

   for t = 1 : 2
      % This is not correct for ability heterogeneity +++ (for periods 3-4)
      cChild = aggrS.cons_tjM(t,j);
      hours = aggrS.hours_tjM(t,j);
      dissave = aggrS.k_tjM(t+1,j) - aggrS.k_tjM(t,j);
      [~,uPrime] = hh_bc1.hh_util_coll_bc1(cChild, 1 - hours, paramS, cS);
      fprintf(fp, 'Child phase %i:  c: %.1f  uPrime: %.2f  earn: %.1f  save: %.1f \n', t, ...
         cChild, 100 * uPrime, aggrS.earn_tjM(t,j), dissave);
   end

   fprintf(fp, '\n');
end

fclose(fp);
type(outFn);

end