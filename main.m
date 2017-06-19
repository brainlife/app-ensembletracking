function [] = main()

if isempty(getenv('SERVICE_DIR'))
    disp('setting SERVICE_DIR to pwd')
    setenv('SERVICE_DIR', pwd)
end

switch getenv('ENV')
case 'IUHPC'
        disp('loading paths (HPC)')
        addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
        addpath(genpath('/N/u/hayashis/BigRed2/git/jsonlab'))
case 'VM'
        disp('loading paths (VM)')
  	addpath(genpath('/usr/local/jsonlab'))
	addpath(genpath('/usr/local/vistasoft'))
end

config = loadjson('config.json');

%% Create an MRTRIX .b file from the bvals/bvecs of the shell chosen to run
out   = 'grad.b';
mrtrix_bfileFromBvecs(config.bvecs, config.bvals, out);

% load my own config.json
[ out ] = make_wm_mask(config);
end
