echo "Creating labeled freesurfer volumes..."




## aparc+aseg
mri_label2vol --seg $fsurfer/mri/aparc+aseg.mgz --temp $fsurfer/mri/aparc+aseg.mgz --regheader $fsurfer/mri/aparc+aseg.mgz --o aparc+aseg_full.nii.gz
mri_label2vol --seg $fsurfer/mri/aparc+aseg.mgz --temp $input_nii_gz --regheader $fsurfer/mri/aparc+aseg.mgz --o aparc+aseg_anat.nii.gz

## aparc+a2009s+aseg
mri_label2vol --seg $fsurfer/mri/aparc.a2009s+aseg.mgz --temp $fsurfer/mri/aparc.a2009s+aseg.mgz --regheader $fsurfer/mri/aparc.a2009s+aseg.mgz --o aparc.a2009s+aseg_full.nii.gz
mri_label2vol --seg $fsurfer/mri/aparc.a2009s+aseg.mgz --temp $input_nii_gz --regheader $fsurfer/mri/aparc.a2009s+aseg.mgz --o aparc.a2009s+aseg_anat.nii.gz

echo "Creating brain, white matter, and corpus callosum masks..."

## create brain masks
#mri_binarize --i aparc+aseg_full.nii.gz --min 1 --o mask_full.nii.gz 
mri_binarize --i aparc+aseg_anat.nii.gz --min 1 --o mask_anat.nii.gz 

## create white matter masks
mri_binarize --i aparc+aseg_full.nii.gz --o wm_full.nii.gz --match 2 41 16 17 28 60 51 53 12 52 13 18 54 50 11 251 252 253 254 255 10 49 46 7
mri_binarize --i aparc+aseg_anat.nii.gz --o wm_anat.nii.gz --match 2 41 16 17 28 60 51 53 12 52 13 18 54 50 11 251 252 253 254 255 10 49 46 7

## create cc mask
#mri_binarize --i aparc+aseg_full.nii.gz --o cc_full.nii.gz --match 251 252 253 254 255
mri_binarize --i aparc+aseg_anat.nii.gz --o cc_anat.nii.gz --match 251 252 253 254 255


