#!/bin/bash

export PATH=$PATH:/usr/lib/mrtrix/bin

BGRAD="grad.b"

dtiinit=`jq -r '.dtiinit' config.json`
export input_nii_gz=$dtiinit/`jq -r '.files.alignedDwRaw' $dtiinit/dt6.json`
export BVALS=$dtiinit/`jq -r '.files.alignedDwBvecs' $dtiinit/dt6.json`
export BVECS=$dtiinit/`jq -r '.files.alignedDwBvals' $dtiinit/dt6.json`

DOPROB=`jq -r '.do_probabilistic' config.json`
DOSTREAM=`jq -r '.do_deterministic' config.json`
DOTENSOR=`jq -r '.do_tensor' config.json`

PROB_CURVS=`jq -r '.prob_curvs' config.json`
DETR_CURVS=`jq -r '.detr_curvs' config.json`

#if max_lmax is empty, auto calculate
MAXLMAX=`jq -r '.max_lmax' config.json`
if [[ $MAXLMAX == "null" || -z $MAXLMAX ]]; then
    echo "max_lmax is empty... determining which lmax to use from .bvals"
    MAXLMAX=`./calculatelmax.py`
fi

NUMFIBERS=`jq -r '.num_fibers' config.json`
MAXNUMFIBERSATTEMPTED=$(($NUMFIBERS*50))

NUMCCFIBERS=`jq -r '.num_cc_fibers' config.json`
MAXNUMCCFIBERS=$(($NUMCCFIBERS*50))

NUMORFIBERS=`jq -r '.num_or_fibers' config.json`
NUMMTFIBERS=`jq -r '.num_mt_fibers' config.json`
NUMVZFIBERS=`jq -r '.num_vz_fibers' config.json`

MAXNUMORFIBERS=$(($NUMORFIBERS*250000))
MAXNUMMTFIBERS=$(($NUMMTFIBERS*250000))
MAXNUMVZFIBERS=$(($NUMVZFIBERS*250000))

echo "Using MAXLMAX: $MAXLMAX"
echo "Using NUMFIBERS per each track: $NUMFIBERS"
echo "Using MAXNUMBERFIBERSATTEMPTED: $MAXNUMFIBERSATTEMPTED"

## precompute the expected output count by stepping through the tracking logic
TOTAL=0

if [ $DOTENSOR == "true" ]; then
    TOTAL=$(($TOTAL+$NUMCCFIBERS+$NUMFIBERS))
fi

if [ $DOPROB == "true" ] ; then
	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
		for i_curv in $PROB_CURVS; do
			if [ ${i_lmax} -le 2 ]; then
			    TOTAL=$(($TOTAL+$NUMORFIBERS+$NUMORFIBERS))
			fi
			TOTAL=$(($TOTAL+$NUMCCFIBERS+$NUMMTFIBERS+$NUMMTFIBERS+$NUMVZFIBERS+$NUMFIBERS))
		done
	done
fi

if [ $DOSTREAM == "true" ] ; then
	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
		for i_curv in $DETR_CURVS; do
			# if [ ${i_lmax} -le 2 ]; then
			#     TOTAL=$(($TOTAL+$NUMORFIBERS+$NUMORFIBERS))
			# fi
			TOTAL=$(($TOTAL+$NUMCCFIBERS+$NUMMTFIBERS+$NUMMTFIBERS+$NUMVZFIBERS+$NUMFIBERS))
		done
	done
fi

echo "Expecting $TOTAL streamlines in final ensemble."

if [ -f grad.b ]; then
    echo "grad.b and wm.nii.gz exist... skipping"
else
    echo "starting matlab to create grad.b & wm.nii.gz"
    ./matlabcompiled/main
fi

echo "converting nii.gz to mif"
mrconvert --quiet wm_anat.nii.gz wm.mif
mrconvert --quiet mask_anat.nii.gz brainmask.mif
mrconvert --quiet cc_anat.nii.gz cc.mif
mrconvert --quiet wm_full.nii.gz tm.mif
mrconvert --quiet wm_lh.nii.gz wm_lh.mif
mrconvert --quiet wm_rh.nii.gz wm_rh.mif

## create extra wm rois
mrconvert --quiet lh_thalamus.nii.gz lh_thalamus.mif
mrconvert --quiet rh_thalamus.nii.gz rh_thalamus.mif
mrconvert --quiet lh_occipital.nii.gz lh_occipital.mif
mrconvert --quiet rh_occipital.nii.gz rh_occipital.mif
mrconvert --quiet lh_motor.nii.gz lh_motor.mif
mrconvert --quiet rh_motor.nii.gz rh_motor.mif
mrconvert --quiet br_stem.nii.gz br_stem.mif
mrconvert --quiet wm_vis.nii.gz wm_vis.mif
mrconvert --quiet wm_fh.nii.gz wm_fh.mif

## create extra seed masks
mradd -quiet lh_thalamus.mif lh_occipital.mif lh_or_seed.mif
mradd -quiet rh_thalamus.mif rh_occipital.mif rh_or_seed.mif
mradd -quiet lh_motor.mif br_stem.mif lh_motor_seed.mif
mradd -quiet rh_motor.mif br_stem.mif rh_motor_seed.mif

echo "converting $input_nii_gz to dwi.mif"
alias
if [ -f dwi.mif ]; then
    echo "dwi.mif already exist... skipping"
else
    time mrconvert --quiet $input_nii_gz dwi.mif
    ret=$?
    if [ ! $ret -eq 0 ]; then
        exit $ret
    fi
fi

echo "done converting"

###################################################################################################

#echo "make brainmask from dwi data (about 18 minutes)"
#if [ -f brainmask.mif ]; then
#    echo "brainmask.mif already exist... skipping"
#else
#    time /usr/lib/mrtrix/bin/average -quiet dwi.mif -axis 3 - | /usr/lib/mrtrix/bin/threshold -quiet - - | /usr/lib/mrtrix/bin/median3D -quiet - - | /usr/lib/mrtrix/bin/median3D -quiet - brainmask.mif
#    ret=$?
#    if [ ! $ret -eq 0 ]; then

#        exit $ret
#    fi
#fi

###################################################################################################

if [ $DOTENSOR == "true" ]; then
	echo "fit tensor model (takes about 16 minutes)"
	if [ -f dt.mif ]; then
    		echo "dt.mif already exist... skipping"
	else
	    time dwi2tensor -quiet dwi.mif -grad $BGRAD dt.mif 
	fi
fi

#if [ -f fa.mif ]; then
#    echo "fa.mif already exist... skipping"
#else
#    time tensor2FA dt.mif - | mrmult - brainmask.mif fa.mif
#fi

###################################################################################################

echo "estimate response function"
#if [ -f sf.mif ]; then
#    echo "sf.mif already exist... skipping"
#else 
#    time erode -quiet brainmask.mif -npass 3 - | mrmult -quiet fa.mif - - | threshold -quiet - -abs 0.7 sf.mif
#fi

if [ -f response.txt ]; then
    echo "response.txt already exist... skipping"
else
#    time estimate_response -quiet dwi.mif sf.mif -lmax 6 -grad $BGRAD response.txt
    time estimate_response -quiet dwi.mif cc.mif -grad $BGRAD response.txt
    ret=$?
    if [ ! $ret -eq 0 ]; then
        exit $ret
    fi
fi

###################################################################################################

for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
# Perform CSD in each white matter voxel
	lmaxout=lmax${i_lmax}.mif
	if [ -s $lmaxout ]; then
		echo "$lmaxout already exist - skipping csdeconv"
	else
		time csdeconv -quiet dwi.mif -grad $BGRAD response.txt -lmax $i_lmax -mask brainmask.mif $lmaxout
		ret=$?
		if [ ! $ret -eq 0 ]; then
			exit $ret
		fi
		
	fi
done 

echo "DONE performing preprocessing of data before starting tracking..."

###################################################################################################

#echo tracking Deterministic Tensorbased

if [ $DOTENSOR == "true" ] ; then
	echo "tensor tracking"

	#streamtrack -quiet DT_STREAM dwi.mif lo_tensor.tck -seed lh_or_seed.mif -mask tm.mif -grad $BGRAD -number $NUMORFIBERS -maxnum $MAXNUMORFIBERS -include lh_thalamus.mif -include lh_occipital.mif -exclude wm_fh.mif -exclude wm_rh.mif -exclude br_stem.mif
	#streamtrack -quiet DT_STREAM dwi.mif ro_tensor.tck -seed rh_or_seed.mif -mask tm.mif -grad $BGRAD -number $NUMORFIBERS -maxnum $MAXNUMORFIBERS -include rh_thalamus.mif -include rh_occipital.mif -exclude wm_fh.mif -exclude wm_lh.mif -exclude br_stem.mif

	streamtrack -quiet DT_STREAM dwi.mif cc_tensor.tck -seed cc.mif -mask tm.mif -grad $BGRAD -number $NUMCCFIBERS -maxnum $MAXNUMCCFIBERS
	streamtrack -quiet DT_STREAM dwi.mif wm_tensor.tck -seed wm.mif -mask tm.mif -grad $BGRAD -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED

fi

if [ $DOPROB == "true" ] ; then

	i_tracktype=SD_PROB
	echo Tracking $i_tracktype

	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do

		for i_curv in $PROB_CURVS; do

			echo Tracking CSD-based Lmax=$i_lmax

			wboutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_wb.tck
			ccoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_cc.tck
			looutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_lo.tck
			rooutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_ro.tck
			lmoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_lm.tck
			rmoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_rm.tck
			vzoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_vz.tck

			if [ ${i_lmax} -le 2 ]; then
			    streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $looutfile -seed lh_or_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMORFIBERS -include lh_thalamus.mif -include lh_occipital.mif -exclude wm_fh.mif -exclude wm_rh.mif -exclude br_stem.mif -maxnum $MAXNUMORFIBERS
			    streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $rooutfile -seed rh_or_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMORFIBERS -include rh_thalamus.mif -include rh_occipital.mif -exclude wm_fh.mif -exclude wm_lh.mif -exclude br_stem.mif -maxnum $MAXNUMORFIBERS

			fi
						
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $ccoutfile -seed cc.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMCCFIBERS -maxnum $MAXNUMCCFIBERS
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $lmoutfile -seed lh_motor_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMMTFIBERS -include lh_motor.mif -include br_stem.mif -maxnum $MAXNUMMTFIBERS
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $rmoutfile -seed rh_motor_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMMTFIBERS -include rh_motor.mif -include br_stem.mif -maxnum $MAXNUMMTFIBERS
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $vzoutfile -seed wm_vis.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMVZFIBERS -maxnum $MAXNUMVZFIBERS
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $wboutfile -seed wm.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED

		done
	done
fi

if [ $DOSTREAM == "true" ] ; then

	i_tracktype=SD_STREAM
	echo Tracking $i_tracktype

	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do

		for i_curv in $DETR_CURVS; do

                        echo Tracking CSD-based Lmax=$i_lmax

                        wboutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_wb.tck
                        ccoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_cc.tck
			looutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_lo.tck
			rooutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_ro.tck
			lmoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_lm.tck
			rmoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_rm.tck
			vzoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_vz.tck

			# if [ ${i_lmax} -le 2 ]; then
			#     streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $looutfile -seed lh_or_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMORFIBERS -include lh_thalamus.mif -include lh_occipital.mif -exclude wm_fh.mif -exclude wm_rh.mif -exclude br_stem.mif -maxnum $MAXNUMORFIBERS
			#     streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $rooutfile -seed rh_or_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMORFIBERS -include rh_thalamus.mif -include rh_occipital.mif -exclude wm_fh.mif -exclude wm_lh.mif -exclude br_stem.mif -maxnum $MAXNUMORFIBERS
			# fi
						
                        streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $ccoutfile -seed cc.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMCCFIBERS -maxnum $MAXNUMCCFIBERS
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $lmoutfile -seed lh_motor_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMMTFIBERS -include lh_motor.mif -include br_stem.mif -maxnum $MAXNUMMTFIBERS
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $rmoutfile -seed rh_motor_seed.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMMTFIBERS -include rh_motor.mif -include br_stem.mif -maxnum $MAXNUMMTFIBERS
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $vzoutfile -seed wm_vis.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMVZFIBERS -maxnum $MAXNUMVZFIBERS
                        streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $wboutfile -seed wm.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED

                done
        done
fi

###################################################################################################

echo "DONE tracking."

echo "creating ensemble tractography"
./matlabcompiled/ensemble_tck_generator

## print out summary of track.tck
track_info track.tck > track_info.txt

## hard check of count
COUNT=`track_info track.tck | grep -w 'count' | awk '{print $2}'`
echo "Ensemble tractography generated $COUNT of a requested $TOTAL"
if [ $COUNT -ne $TOTAL ]; then
    echo "Incorrect count. Tractography failed."
    rm track.tck
else
    echo "Correct count. Tractography complete."
    #rm *.mif
    #rm grad.b
    #rm response.txt
fi

## clean up working directors
rm csd*.tck
rm *tensor.tck
#rm *.nii.gz
