function [ xhat ] = bayesianomp(...
    phi, y, stddev, stddevx, b, steps, minsupport)
%bayesianomp Bayesian Orthogonal Matching Pursuit, according to
%  "Structured Bayesian Orthogonal Matching Pursuit", Dremeau et al.
%   Not as general as the implementation in the paper; it uses Bernoulli
%   priors over coefficient support (a special case of Bolzmann machines).
%
% Important: the assumption is that phi is unit l2-normalized accross columns
%
% Arguments:
% phi       ... dictionary, sensing matrix (IxM). Make sure the atoms have unit l2-norm.
% y         ... compressed representation (IxN), where N is the number of input signals
% stddev    ... standard deviation of noise
% stddevx   ... standard deviation of activations (given the coefficient is active)
% b         ... parameterization of Bernouli pdf, b = 1./(1+exp(-p)), where p is probability of `1`
% steps     ... number of iterations. Number of active atoms returned cannot exceed this value
%
% Returns:
% MxN sparse matrix of activation coefficients
%
% Note: convergence criterion is not implemented; based on stddev, stddevx
% and b, the algorithm may decide not to use additional atoms.
% Still, why not have it, based on the posterior probability - a TODO.
% TODO: avoid transposing phi all the time

siglen = size(phi,2);
numsignals = size(y,2);

r = y;  % initial residual
shat = sparse(siglen, numsignals);
xhat = sparse(siglen, numsignals);
for step = 1:steps
    %
    % Step 1. s macron
    %
    % A modification of the original algorithm - insist on minimal cardinality
    % of support    
    cardinalitytoosmall = sum(shat,1) < minsupport;
    %
    thresh = -2.*stddev.*(stddev./stddevx+1).*b;
    expression = (phi.'*r + xhat).^2;
    smacron = expression > thresh;
    %
    smacron(:,cardinalitytoosmall) = true;

    %
    % Step 2. Choose the atom to be modified
    %    
    xmacron = smacron.*(phi.'*r+ xhat)./(stddev./stddevx+1);
    
    argminof = ...
        sqrt(sum(r.^2) + 2.*phi.'*r.*(xhat-xmacron) + bsxfun(@times, (xhat-xmacron).^2, sum(phi.^2).')) ...
        - stddev./stddevx.*xmacron.^2 ...
        + stddev.*(shat-smacron).*b.*smacron;
        
    % In case smacron(istar) == shat(istart), the iteration will make no change
    % to the signal approximation. Therefore, we intervene and find argmin
    % which will introduce an actual change.
    no_change_here = smacron == shat;
    argminof(no_change_here) = Inf;
    [~, istar] = min(argminof);            
    
    %
    % Step 3. Update the SR support
    %
    % Update shat to become smacron at indices where istar.
    idx = istar + (0:size(shat,1):(numel(shat)-1)); % a shortcut to get linear indices
    shat(idx) = smacron(idx);
    % TODO: use array indexing instead of linear indexing
    
    %
    % Step 4. Update the SR coefficients
    %
    % Here we have calculation of inverse, which will be done sequentially,
    % in a loop. Luckily, complexity of this step is a function of sparsity
    % and not a function of dimensionality of the problem, so it's not
    % prohibitively expensive.
    xhat = sparse(siglen, numsignals);
    for idx=1:numsignals
        supp = find(shat(:,idx));
        phisub = phi(:,supp);
        xhat(supp,idx) = (phisub.'*phisub + eye(size(phisub,2)).*stddev./stddevx)\phisub.'*y(:,idx);
        % xhat(support,idx) = inv(phisub.'*phisub + eye(size(phisub,2)).*stddev./stddevx)*phisub.'*y(:,idx);
    end
    
    %
    % Step 5: Update the residual
    %
    r = y - phi*xhat;        
end

