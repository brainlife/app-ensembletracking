function ensemble_tck_generator()

% 
% switch getenv('ENV')
% case 'IUHPC'
%         disp('loading paths (HPC)')
%         addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'))
% case 'VM'
%         disp('loading paths (VM)')
%   	addpath(genpath('/usr/local/vistasoft'))
% end

disp('combining tck files')
% find all the .tck files
ens = dir('*.tck');
% pull all the file names
ens_names = {ens.name};


tracks = read_mrtrix_tracks(char(ens_names(1)));
all_tracks = tracks;
all_tracks.count = str2double(all_tracks.count);
for ii = 2:length(ens_names)
    temptracks = read_mrtrix_tracks(char(ens_names(ii)));
    all_tracks.count = all_tracks.count + str2double(temptracks.count);
    all_tracks.data = [all_tracks.data temptracks.data];
end

all_tracks.count = num2str(all_tracks.count);
all_tracks.roi = '';
write_mrtrix_tracks(all_tracks, 'track.tck')


% 
% % loop over and import all the ensemble connectomes
% %ens_fg = fgCreate('name', 'ens_fg');
% ens_fg = dtiImportFibersMrtrix(char(ens_names(1)), .5)
% %ens_fg = fgRead(char(ens_names(1)));
% 
% for ii = 2:length(ens_names)
%     
%     tfg = dtiImportFibersMrtrix(char(ens_names(ii)), .5);
%        
%     % append the new streamlines to the fiber group
%     ens_fg.fibers = [ ens_fg.fibers; tfg.fibers ];
%     
% end
% % save out
% 
% dtiExportFibersMrtrix(ens_fg, 'track.tck')

end
