function [] = main()

disp('running')
config = loadjson('config.json');
dt6config = loadjson(fullfile(config.dtiinit, '/dt6.json'));

%% Create an MRTRIX .b file from the bvals/bvecs of the shell chosen to run
mrtrix_bfileFromBvecs(fullfile(config.dtiinit,dt6config.files.alignedDwBvecs), fullfile(config.dtiinit,dt6config.files.alignedDwBvals), 'grad.b');

end
