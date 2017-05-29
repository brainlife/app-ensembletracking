function ensemble_connectome_generator()

disp('loading paths')
addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
% addpath(genpath('/N/u/hayashis/BigRed2/git/jsonlab'))
% 
% config = loadjson('config.json');



% Curvature paramater (lmax)
lmaxparam = {'2','4','6','8','10','12'};
% probability or deterministic tracking from mrtrix
streamprob = {'PROB','STREAM'};


% Tensor-based tracking. only on fascicles group
fg = fgRead('wm_tensor.tck');
%dt6File = fullfile(fe_path,'diffusion_data/dt6/dti90trilin/dt6.mat');
%fasciclesClassificationSaveName = fullfile(fe_path,'major_tracts', sprintf('data_b%_aligned_trilin_noMEC_wm_tensor-500000.mat',bvals));

% Subsample the fascicles 500,000 are too many (eliminate this step in the future by reducing the number of fascicles you 
% track, track 60,000 fascicles max for 13 tractography methods and 100,000x70 data points).
fgIdx = randsample(1:length(fg.fibers), 60000);
fg = fgExtract(fg,fgIdx,'keep');

% CSD-based tracking. Load one at the time.
for ilm = 1:length(lmaxparam)
    for isp = 1:length(streamprob)
        
        fg_tmp = fgRead(fullfile(sprintf('csd_lmax%s_wm_SD_%s.tck',lmaxparam{ilm},streamprob{isp})));
        fgIdx = randsample(1:length(fg_tmp.fibers),60000);
        fg_tmp = fgExtract(fg_tmp,fgIdx,'keep');

        % Merge the new fiber group with the original fiber group.
        fg = fgMerge(fg,fg_tmp);
        %clear fg_tmp
    end
end 
% Write fascicle group to disk.
fgFileName = 'ensemble.mat';
fgWrite(fg,fgFileName);

end