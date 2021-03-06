% This function will determine the optimal number of forward contracts to 
% buy / sell over a given period to optimise profits given constraints on 
% gas storage
%
% Inputs:
%   
%   n:  the number of months over which to optimise the contracts
%
%   F:  a vector of length n representing the current forward curve for
%       each month k such that f(k) = forward contract price for month k
%       1 <= k <= n
%
%   I:  a cell array of length n containing pairs of vectors representing
%       ordered pairs that define boundary points in the daily maximum 
%       injection rate function in mmbtu for month k (1 <= k <= n)
%
%   W: a cell array of length n containing pairs of vectors representing
%       ordered pairs that define boundary points in the daily maximum 
%       withdrawal rate function in mmbtu for month k (1 <= k <= n)
%
%   q:  a function representing the price-dependent cost of withdrawal
%
%   p:  a function representing the price-dependent cost of injection
%
%   c:  a vector of length n representing the month-dependent cost of
%       injection/withdrawal
%       
%   V0: the initial inventory level of the storage
%
%   Vn: the final inventory level of the storage at the end of month n
%
%   L:  a vector of length n indicating the minimal inventory level of gas
%       required to be kept during month k (1 <= k <= n)
%
function [d, e, fval] = optimizeContractsBB(n, F, I, W, q, p, c, V0, Vn, L)

% Develop the original problem (without injection or withdrawal
% constraints)
initProb = formProblem(n, F, q, p, c, V0, Vn, L);

% Save the piecewise constraints
piecewiseConstraints = {I, W};
c = initProb.f;

% Form the convex hull of the constraints
relaxedProb = reformPiecewise(initProb, piecewiseConstraints);

% Begin the stack
LIST = [relaxedProb];

% Initialise upper bound based on x=zeros
x = 0;
curOptimal = c'*x;

% Pop off the stack until it's empty
while (~isempty(LIST))
    
    % Pull off the first problem 
    curProblem = LIST(:,1);
    LIST(:,1) = [];
    
    % Calculate the optimisation to this problem
    [x_s,~,flag] = linprog(curProblem);
    
    % if it cannot be pruned by infeasibility or bound (i.e. is lower than
    % the current best legitimate candidate)
    if (~isempty(x_s) && c'*x_s < curOptimal && flag == 1)
        
        % Check against piecewise constraints
        [valid, invalidConstraint] = checkConstraints(x_s, piecewiseConstraints);
        
        % If it satisfied the constraints (and is greater from before)
        if(valid)
            curOptimal = c'*x_s;
            x = x_s;
            
        % It didn't satisfy constraints and is still greater, branch
        else
            
            % Subdivide the problem into two on either side of the point based
            % on the constraint that was violated (I or W, then which
            % segment)
            subProblems = formSubproblems(invalidConstraint, curProb, piecewiseConstraints);
            
            % Depth first
            LIST = [subProblems LIST];
            
        end
    end
end
return