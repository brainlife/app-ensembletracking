echo "Creating labeled freesurfer volumes..."

fsurfer=`jq -r '.freesurfer' config.json`
dtiinit=`jq -r '.dtiinit' config.json`
export input_nii_gz=$dtiinit/`jq -r '.files.alignedDwRaw' $dtiinit/dt6.json`


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

##
## make extra visual wm areas for additional seeding / optic radiation
##

## thalami
mri_binarize --i aparc+aseg_anat.nii.gz --o lh_thalamus.nii.gz --match 10 11
mri_binarize --i aparc+aseg_anat.nii.gz --o rh_thalamus.nii.gz --match 49 50

## occipital
mri_binarize --i aparc+aseg_anat.nii.gz --o lh_occipital.nii.gz --match 1005 1011 1013 1021
mri_binarize --i aparc+aseg_anat.nii.gz --o rh_occipital.nii.gz --match 2005 2011 2013 2021

## occipital ++
mri_binarize --i aparc+aseg_anat.nii.gz --o vis_wm.nii.gz --match 1005 1011 1013 1021 1008 1029 1031 1030 1015 1009 1007 1025 2005 2011 2013 2021 2008 2029 2031 2030 2015 2009 2007 2025

## motor tract
mri_binarize --i aparc+aseg_anat.nii.gz --o lh_motor.nii.gz --match 1022 1024
mri_binarize --i aparc+aseg_anat.nii.gz --o rh_motor.nii.gz --match 2022 2024

## brainstem
mri_binarize --i aparc+aseg_anat.nii.gz --o br_stem.nii.gz --match 16

