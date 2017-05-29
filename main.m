function [] = main()

if isempty(getenv('SCA_SERVICE_DIR'))
    disp('setting SCA_SERVICE_DIR to pwd')
    setenv('SCA_SERVICE_DIR', pwd)
end

disp('loading paths')
addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
addpath(genpath('/N/u/hayashis/BigRed2/git/jsonlab'))

config = loadjson('config.json');

%% Create an MRTRIX .b file from the bvals/bvecs of the shell chosen to run
out   = 'grad.b';
mrtrix_bfileFromBvecs(config.bvecs, config.bvals, out);


% load my own config.json

[ out ] = make_wm_mask(config);
end