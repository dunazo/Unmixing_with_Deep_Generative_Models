%%
%-------------------------------------------------------------------------%
%     HYPERSPECTRAL UNMIXING USING A PERTURBED LINEAR MIXING MODEL        %
%-------------------------------------------------------------------------%
%% File
% File : main_PLMM.m
% Author : P.A. Thouvenin (05/11/2014)
% Last update : 30/10/2015
%=========================================================================%
% Related article :
% P.-A. Thouvenin, N. Dobigeon and J.-Y. Tourneret, "Hyperspectral unmixing
% with spectral variability using a perturbed linear mixing model", 
% IEEE Trans. Signal Processing, to appear.
%=========================================================================%
clc, clear all, close all, format compact;
addpath ./../utils;
addpath ./../src;
%=========================================================================%
%% Remarks
% The codes associated with the following papers have been directly 
% downloaded from their authors' website: 
%
% [1] J. M. Nascimento and J. M. Bioucas-Dias, �Vertex component analysis: 
% a fast algorithm to unmix hyperspectral data,� IEEE Trans. Geosci. Remote
% Sens., vol. 43, no. 4, pp. 898�910, April 2005.
% [2] J. M. Bioucas-Dias and M. A. T. Figueiredo, "Alternating direction 
% algorithms for constrained sparse regression: Application to hyperspectral
% unmixing," in Proc. IEEE GRSS Workshop Hyperspectral Image Signal
% Process.: Evolution in Remote Sens. (WHISPERS), Reykjavik, Iceland,
% June 2010.
% [3] J. Duchi, S. Shalev-Schwartz, Y. Singer, and T. Chandra, "Efficient
% projection onto the l1-ball for learning in high dimensions," in Proc.
% Int. Conf. Machine Learning (ICML), Helsinki, Finland, 2008.
%=========================================================================%
%%
%--------------------------------------------------------------
% Data section
%--------------------------------------------------------------
load Moffett_vca        % the data contained in this file have already been lexicographically ordered
% [H,W,L] = size(data); % size of the hyperspectral datacube
L = 189;
K = 3;                % desired endmember number
N = H*W;              % number of pixels
% Y = (reshape(permute(data,[2 1 3]),H*W,L))'; % pixel lexicographical ordering

%--------------------------------------------------------------
% Unmixing parameters
%--------------------------------------------------------------
% Stopping criteria
epsilon = 1e-3; % BCD iteration
eps_abs = 1e-2; % primal residual
eps_rel = 1e-4; % dual residual

% ADMM parameters
Niter_ADMM = 1;30;          % maximum number of ADMM subiterations
muA = (1e-4)*L/(K+1);     % hyperparameters (AL constants)
muM = (1e-8)*N/(2*(N+1)*K); % Volume (1e-8)*N/(2*(N+1)*K) % Distance/None (1e-4)*N/((N+1)*K)
mudM = (1e-4)/(2*K);      % LN/(2LKN)
tau_incr = 1.1;
tau_decr = 1.1;
mu = 10;

% Regularization 
type = 'NONE';'VOLUME';           % regularization type ('NONE','MUTUAL DISTANCE','VOLUME','DISTANCE')
alpha = 0;1e-4;0;                 % abundance regularization parameter
beta = 5.4e-4;             % endmember regularization parameter
gamma = 1;                 % variability regularization parameter


%--------------------------------------------------------------
% define random states
rand('state',10);
randn('state',10);


%--------------------------------------------------------------
% Initialization
%--------------------------------------------------------------
% Endmember initialization (VCA [1])
[M0, V, U, Y_bar, endm_proj, Y_proj] = find_endm(Y,K,'vca');
% Abundance initialization (SUNSAL [2])
A0 = sunsal(M0,Y,'POSITIVITY','yes','ADDONE','yes');
% Abundance projection onto the unit simplex to strictly satisfy the constraints [3]
for n = 1:N
    A0(:,n) = ProjectOntoSimplex(A0(:,n),1);
end
% Perturbation matrices initialization
dM0 = eps*ones(L,K*N);
dM0 = mat2cell(dM0,L,K*ones(N,1));    % [dM_1 | dM_2 | ... | dM_N]
input = {type,beta,Y_proj,Y_bar,U,V}; % input = {type,beta} for 'MUTUAL DISTANCE' | input = {type,beta,M0} for 'DISTANCE'
                                      % input = {type,beta,Y_proj,Y_bar,U,V} for 'VOLUME'    

%--------------------------------------------------------------
% BCD/ADMM unmixing (based on the PLMM)
%--------------------------------------------------------------
disp(['ADMM processing (M : ', type,', alpha = ',num2str(alpha),', beta = ',num2str(beta),', gamma = ',num2str(gamma),')...'])
tic
[f,A,M,dM] = bcd_admm(Y,A0,M0,dM0,W,H,gamma,eps_abs,eps_rel,epsilon,'HYPERPARAMETERS',{muA,muM,mudM},'PENALTY A',alpha,'PENALTY M',{type,beta,Y_proj,Y_bar,U,V},'AL INCREMENT',{tau_incr,tau_decr,mu},'MAX ADMM STEPS',Niter_ADMM);
% [f,A,M,dM,RE,GMSE_A,GMSE_M,GMSE_dM,SA,mu_A,mu_M,mu_dM] = bcd_admm_th(Y,Ath,Mth,dMth,A0,M0,dM0,W,H,gamma,eps_abs,eps_rel,epsilon,'HYPERPARAMETERS',{muA,muM,mudM},'PENALTY A',alpha,'PENALTY M',{type,beta,Y_proj,Y_bar,U,V},'AL INCREMENT',{tau_incr,tau_decr,mu},'MAX ADMM STEPS',Niter_ADMM);
time =  toc;         

%--------------------------------------------------------------
% Error computation
%--------------------------------------------------------------
[RE,A,var_map] = real_error(Y,A,M,dM,W,H);
% [RE_ADMM,GMSE_A_ADMM,GMSE_M_ADMM,MSE_dM_ADMM,GMSE_dM_ADMM,Error_A_ADMM,SA_ADMM,A,M,dM,var_map] = th_error(Y,Ath,Mth,dMth,A,M,dM,W,H);
disp('---------------------------------------------------------------------------');


