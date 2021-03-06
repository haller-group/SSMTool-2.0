function varargout = SSM_BP2ep(obj,oid,run,lab,parName,parRange,outdof,varargin)
% SSM_BP2EP This function performs continuation of equilibrium points of
% slow dynamics. Each equilibrium point corresponds to a periodic orbit in
% the regular time dynamics. The continuation here starts from a saved
% solution, which is a BRANCH point. The continuation follows the secondary
% branch passing through this point
%
% FRC = ODE_BP2EP(OBJ, OID, RUN, LAB, PARNAME, PARRANGE, OUTDOF, VARARGIN)
%
% oid:      runid of current continuation
% run:      runid of continuation for saved solution
% lab:      label of continuation for saved solution, which must be the label of
%           a branch point
% parName:  amp/freq continuation parameter
% parRange: continuation domain of parameter, which should be near the
%           value of natural frequency with index 1 in the mFreq if continuation
%           parameter is freq
% outdof:   dofs for output in physical domain
% varargin: ['saveICs'] flag for saving the initial point in trajectory
%
% See also: SSM_ISOL2EP SSM_EP2EP

%% continuation of equilibrium points in reduced dynamics
prob = coco_prob();
prob = cocoSet(obj.contOptions,prob);
prob = ode_BP2ep(prob, '', coco_get_id(run, 'ep'), lab);

% read data 
fdata = coco_get_func_data(prob, 'ep', 'data');
% extract data to fdata.fhan, namely, @(z,p)ode_2mDSSM(z,p,fdata)
odedata = functions(fdata.fhan);
odedata = odedata.workspace{1};
fdata   = odedata.fdata;
m   = numel(fdata.mFreqs);
order    = fdata.order;
ispolar  = fdata.ispolar;
iNonauto = fdata.iNonauto;
rNonauto = fdata.rNonauto;
kNonauto = fdata.kNonauto;
modes    = fdata.modes;
mFreqs   = fdata.mFreqs;
wdir     = fullfile(pwd,'data','SSM.mat');
SSMcoeffs = load(wdir);
SSMcoeffs = SSMcoeffs.SSMcoeffs;
W_0 = SSMcoeffs.W_0;
W_1 = SSMcoeffs.W_1;
clear('SSMcoeffs');

% define monitor functions
if ispolar
    rhoargs = cell(m,1);
    thargs  = cell(m,1);
    for k=1:m
        rhoargs{k} = strcat('rho',num2str(k));
        thargs{k}  = strcat('th',num2str(k));
    end
    prob = coco_add_pars(prob, 'radius', 1:2:2*m-1, rhoargs(:)');
    prob = coco_add_pars(prob, 'angle', 2:2:2*m, thargs(:)');
else
    Reargs = cell(m,1);
    Imargs = cell(m,1);
    for k=1:m
        Reargs{k} = strcat('Rez',num2str(k));
        Imargs{k} = strcat('Imz',num2str(k));
    end
    prob = coco_add_pars(prob, 'realParts', 1:2:2*m-1, Reargs(:)');
    prob = coco_add_pars(prob, 'imagParts', 2:2:2*m, Imargs(:)');
end    

% setup continuation arguments
switch parName
    case 'freq'
        isomega = true;
    case 'amp'
        isomega = false;
    otherwise
        error('Continuation parameter should be freq or amp');
end
if strcmp(obj.FRCOptions.sampStyle, 'uniform')
    if isomega
        nOmega = obj.FRCOptions.nPar;
        omSamp = linspace(parRange(1),parRange(2), nOmega);
        prob   = coco_add_event(prob, 'UZ', 'om', omSamp);
    else
        nEpsilon = obj.FRCOptions.nPar;
        epSamp = linspace(parRange(1),parRange(2), nEpsilon);
        prob   = coco_add_event(prob, 'UZ', 'eps', epSamp);
    end        
end

runid = coco_get_id(oid, 'ep');

fprintf('\n Run=''%s'': Continue equilibria along secondary branch.\n', ...
  runid);

if isomega
    if ispolar
        cont_args = [{'om'},rhoargs(:)' ,thargs(:)',{'eps'}];
    else
        cont_args = [{'om'},Reargs(:)' ,Imargs(:)',{'eps'}];
    end
else
    if ispolar
        cont_args = [{'eps'},rhoargs(:)' ,thargs(:)',{'om'}];
    else
        cont_args = [{'eps'},Reargs(:)' ,Imargs(:)',{'om'}];
    end
end

% coco run
coco(prob, runid, [], 1, cont_args, parRange);


%% extract results of reduced dynamics at sampled frequencies
if ispolar
    FRC = ep_reduced_results(runid,obj.FRCOptions.sampStyle,ispolar,isomega,rhoargs,thargs);
else
    FRC = ep_reduced_results(runid,obj.FRCOptions.sampStyle,ispolar,isomega,Reargs,Imargs);    
end

%% FRC in physical domain
Zout_frc = [];
Znorm_frc = [];
Aout_frc = [];

% flag for saving ICs (used for numerical integration)
if numel(varargin)==2
    saveICflag = strcmp(varargin{2},'saveICs');
elseif numel(varargin)==1
    saveICflag = strcmp(varargin{1},'saveICs');
else
    saveICflag = false;
end
if saveICflag
    Z0_frc = []; % initial state
end
timeFRCPhysicsDomain = tic;

% Loop around a resonant mode
om   = FRC.om;
epsf = FRC.ep;
nt   = obj.FRCOptions.nt;
for j = 1:numel(om)
    % compute non-autonomous SSM coefficients
    obj.System.Omega = om(j);
    if isomega 
        if obj.Options.contribNonAuto
            if isempty(obj.E)
                obj.choose_E(modes);
            end

            [W_1, R_1] = obj.compute_perturbed_whisker(order);

            R_10 = R_1{1}.coeffs;
            assert(~isempty(R_10), 'Near resonance does not occur, you may tune tol');
            f = R_10((kNonauto-1)*2*m+2*iNonauto-1);

            assert(norm(f-rNonauto)<1e-3*norm(f), 'inner resonance assumption does not hold');

            fprintf('the forcing frequency %.4d is nearly resonant with the eigenvalue %.4d + i%.4d\n',...
                om(j), fdata.lamdRe(1),fdata.lamdIm(1))
        else
            W_1 = [];
        end
    end
    % Forced response in Physical Coordinates
    state = FRC.z(j,:);
    [Aout, Zout, z_norm, Zic] = compute_full_response_2mD_ReIm(W_0, W_1, state, epsf(j), nt, mFreqs, outdof);

    % collect output in array
    Aout_frc = [Aout_frc; Aout];
    Zout_frc = [Zout_frc; Zout];
    Znorm_frc = [Znorm_frc; z_norm];

    if saveICflag
        Z0_frc = [Z0_frc; Zic]; % initial state
    end 
end
%% 
% Record output
FRC.Aout_frc  = Aout_frc;
FRC.Zout_frc  = Zout_frc;
FRC.Znorm_frc = Znorm_frc;
if saveICflag
    FRC.Z0_frc = Z0_frc; % initial state
end 
FRC.timeFRCPhysicsDomain = toc(timeFRCPhysicsDomain);
FRC.SSMorder   = order;
FRC.SSMnonAuto = obj.Options.contribNonAuto;
FRC.SSMispolar = ispolar;

% Plot Plot FRC in system coordinates
if isomega
    plot_frc_full(om,Znorm_frc,outdof,Aout_frc,FRC.st,order,'freq','lines',{FRC.SNidx,FRC.HBidx});
else
    plot_frc_full(epsf,Znorm_frc,outdof,Aout_frc,FRC.st,order,'amp','lines',{FRC.SNidx,FRC.HBidx});
end
    
varargout{1} = FRC;
fdir = fullfile(pwd,'data',runid,'SSMep.mat');
save(fdir, 'FRC');
end