function [] = main()

% if isempty(getenv('SERVICE_DIR'))
%     disp('setting SERVICE_DIR to pwd')
%     setenv('SERVICE_DIR', pwd)
% end
% 
% switch getenv('ENV')
% case 'IUHPC'
%         disp('loading paths (HPC)')
%         addpath(genpath('/N/u/brlife/git/vistasoft'))
%         addpath(genpath('/N/u/brlife/git/jsonlab'))
% case 'VM'
%         disp('loading paths (VM)')
%   	addpath(genpath('/usr/local/jsonlab'))
% 	addpath(genpath('/usr/local/vistasoft'))
% end

disp('running')
config = loadjson('config.json');
dt6config = loadjson(fullfile(config.dtiinit, '/dt6.json'));

%% Create an MRTRIX .b file from the bvals/bvecs of the shell chosen to run
mrtrix_bfileFromBvecs(fullfile(config.dtiinit,dt6config.files.alignedDwBvecs), fullfile(config.dtiinit,dt6config.files.alignedDwBvals), 'grad.b');

% load my own config.json
make_wm_mask(config);
end
