#!/bin/bash

#make the script to fail if any of the command fails.
set -e

#DEBUG - echo commands executed (to stderr)
set -x
cat config.json

DOPROB=`jq -r '.do_probabilistic' config.json`
DOSTREAM=`jq -r '.do_deterministic' config.json`
DOTENSOR=`jq -r '.do_tensor' config.json`

PROB_CURVS=`jq -r '.prob_curvs' config.json`
DETR_CURVS=`jq -r '.detr_curvs' config.json`

STEPSIZE=`jq -r '.stepsize' config.json`
MINLENGTH=`jq -r '.minlength' config.json`
MAXLENGTH=`jq -r '.maxlength' config.json`

NUMFIBERS=`jq -r '.num_fibers' config.json`
NUMCCFIBERS=`jq -r '.num_cc_fibers' config.json`
NUMORFIBERS=`jq -r '.num_or_fibers' config.json`
NUMMTFIBERS=`jq -r '.num_mt_fibers' config.json`
NUMVZFIBERS=`jq -r '.num_vz_fibers' config.json`

MAXNUMFIBERSATTEMPTED=$(($NUMFIBERS*50))
MAXNUMCCFIBERS=$(($NUMCCFIBERS*50))
MAXNUMORFIBERS=$(($NUMORFIBERS*250000))
MAXNUMMTFIBERS=$(($NUMMTFIBERS*250000))
MAXNUMVZFIBERS=$(($NUMVZFIBERS*250000))

dwi=`jq -r '.dwi' config.json`
if [ $dwi != "null" ]; then
    export input_nii_gz=$dwi
    export BVECS=`jq -r '.bvecs' config.json`
    export BVALS=`jq -r '.bvals' config.json`
fi
dtiinit=`jq -r '.dtiinit' config.json`
if [ $dtiinit != "null" ]; then
    export input_nii_gz=$dtiinit/`jq -r '.files.alignedDwRaw' $dtiinit/dt6.json`
    export BVECS=$dtiinit/`jq -r '.files.alignedDwBvecs' $dtiinit/dt6.json`
    export BVALS=$dtiinit/`jq -r '.files.alignedDwBvals' $dtiinit/dt6.json`
fi

#if max_lmax is empty, auto calculate
MAXLMAX=`jq -r '.max_lmax' config.json`
if [[ $MAXLMAX == "null" || -z $MAXLMAX ]]; then
    echo "max_lmax is empty... determining which lmax to use from .bvals"
    MAXLMAX=`./calculatelmax.py $BVALS`
    echo "Using MAXLMAX: $MAXLMAX"
fi

###################################################################################################
#
# precompute the expected output count by stepping through the tracking logic
#
TOTAL=0
if [ $DOTENSOR == "true" ]; then
    TOTAL=$(($TOTAL+$NUMCCFIBERS+$NUMFIBERS))
fi

if [ $DOPROB == "true" ] ; then
    for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
        for i_curv in $PROB_CURVS; do
            if [ $i_lmax -le 2 ]; then
                TOTAL=$(($TOTAL+$NUMORFIBERS+$NUMORFIBERS))
            fi
            TOTAL=$(($TOTAL+$NUMCCFIBERS+$NUMMTFIBERS+$NUMMTFIBERS+$NUMVZFIBERS+$NUMFIBERS))
        done
    done
fi

if [ $DOSTREAM == "true" ] ; then
    for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
        for i_curv in $DETR_CURVS; do
            TOTAL=$(($TOTAL+$NUMCCFIBERS+$NUMMTFIBERS+$NUMMTFIBERS+$NUMVZFIBERS+$NUMFIBERS))
        done
    done
fi
echo "Expecting $TOTAL streamlines in final ensemble."
#
#
###################################################################################################

#generate grad.b from bvecs/bvals

#load bvals/bvecs
bvals=$(cat $BVALS | tr ',' ' ')
bvecs_x=$(cat $BVECS | tr ',' ' ' | head -1)
bvecs_y=$(cat $BVECS | tr ',' ' ' | head -2 | tail -1)
bvecs_z=$(cat $BVECS | tr ',' ' ' | tail -1)

#convert strings to array of numbers
bvecs_x=($bvecs_x)
bvecs_y=($bvecs_y)
bvecs_z=($bvecs_z)

#output grad.b
i=0
true > grad.b
for bval in $bvals; do
    echo ${bvecs_x[$i]} ${bvecs_y[$i]} ${bvecs_z[$i]} $bval >> grad.b
    i=$((i+1))
done

if [ ! -f convertmif.success ]; then
    echo "converting various nii.gz to mif"

    rm -f *.mif #if this safe?

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

    mrconvert --quiet $input_nii_gz dwi.mif

    echo "done converting"
    touch convertmif.success
fi

if [ ! -f dt.mif ] && [ $DOTENSOR == "true" ]; then
    echo "fit tensor model (takes about 16 minutes)"
    time dwi2tensor -quiet dwi.mif -grad grad.b dt.mif 
fi

if [ ! -f response.txt ]; then
    echo "creating response.txt"
    time estimate_response -quiet dwi.mif cc.mif -grad grad.b response.txt
fi

for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
    lmaxout=lmax${i_lmax}.mif
    if [ ! -f $lmaxout ]; then
        echo "csdeconv $lmaxout"
        time csdeconv -quiet dwi.mif -grad grad.b response.txt -lmax $i_lmax -mask brainmask.mif $lmaxout
    fi
done 

###################################################################################################
#
# DT_STREAM
#

if [ $DOTENSOR == "true" ]; then
    if [ ! -f cc_tensor.tck ] && [ $NUMCCFIBERS -gt 0 ]; then
        echo "streamtrack DT_STREAM cc_tensor.tck - number:$NUMCCFIBERS"
        timeout 3600 time streamtrack -quiet DT_STREAM dwi.mif tmp.tck \
            -seed cc.mif \
            -mask tm.mif \
            -grad grad.b \
            -number $NUMCCFIBERS \
            -maxnum $MAXNUMCCFIBERS \
            -step $STEPSIZE \
            -minlength $MINLENGTH \
            -length $MAXLENGTH
        mv tmp.tck cc_tensor.tck
    fi

    if [ ! -f wm_tensor.tck ] && [ $NUMFIBERS -gt 0 ]; then
        echo "streamtrack DT_STREAM wm_tensor.tck - number:$NUMFIBERS"
        timeout 3600 time streamtrack -quiet DT_STREAM dwi.mif tmp.tck \
            -seed wm.mif \
            -mask tm.mif \
            -grad grad.b \
            -number $NUMFIBERS \
            -maxnum $MAXNUMFIBERSATTEMPTED \
            -step $STEPSIZE \
            -minlength $MINLENGTH \
            -length $MAXLENGTH
        mv tmp.tck wm_tensor.tck
    fi
fi

###################################################################################################
#
# SD_PROB
#

if [ $DOPROB == "true" ]; then
    for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
        for i_curv in $PROB_CURVS; do

            prefix=csd_lmax${i_lmax}_wm_SD_PROB_curv${i_curv}

            out=${prefix}_lo.tck
            if [ $i_lmax -le 2 ] && [ ! -f $out ] && [ $NUMORFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out"
                timeout 3600 time streamtrack -quiet SD_PROB lmax${i_lmax}.mif tmp.tck \
                    -seed lh_or_seed.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMORFIBERS \
                    -maxnum $MAXNUMORFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH \
                    -include lh_thalamus.mif \
                    -include lh_occipital.mif \
                    -exclude wm_fh.mif \
                    -exclude wm_rh.mif \
                    -exclude br_stem.mif
                mv tmp.tck $out
            fi

            out=${prefix}_ro.tck
            if [ ${i_lmax} -le 2 ] && [ ! -f $out ] && [ $NUMORFIBERS -gt 0 ] ; then
                echo "streamtrack SD_PROB $out - number:$NUMORFIBERS"
                timeout 3600 time streamtrack -quiet SD_PROB lmax${i_lmax}.mif tmp.tck \
                    -seed rh_or_seed.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMORFIBERS \
                    -maxnum $MAXNUMORFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH \
                    -include rh_thalamus.mif \
                    -include rh_occipital.mif \
                    -exclude wm_fh.mif \
                    -exclude wm_lh.mif \
                    -exclude br_stem.mif
                mv tmp.tck $out
            fi
                        
            out=${prefix}_cc.tck
            if [ ! -f $out ] && [ $NUMCCFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMCCFIBERS"
                timeout 3600 time streamtrack -quiet SD_PROB lmax${i_lmax}.mif tmp.tck \
                    -seed cc.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMCCFIBERS \
                    -maxnum $MAXNUMCCFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
                mv tmp.tck $out
            fi

            #TODO this times out too often (NUMMTFIBERS now default to 0)
            out=${prefix}_lm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMMTFIBERS"
                timeout 3600 time streamtrack -quiet SD_PROB lmax${i_lmax}.mif tmp.tck \
                    -seed lh_motor_seed.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMMTFIBERS \
                    -maxnum $MAXNUMMTFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH \
                    -include lh_motor.mif \
                    -include br_stem.mif
                mv tmp.tck $out
            fi

            #TODO this times out too often (NUMMTFIBERS now default to 0)
            out=${prefix}_rm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMMTFIBERS"
                timeout 3600 time streamtrack -quiet SD_PROB lmax${i_lmax}.mif tmp.tck \
                    -seed rh_motor_seed.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMMTFIBERS \
                    -maxnum $MAXNUMMTFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH \
                    -include rh_motor.mif \
                    -include br_stem.mif
                mv tmp.tck $out
            fi

            out=${prefix}_vz.tck
            if [ ! -f $out ] && [ $NUMVZFIBERS -gt 0 ] ; then
                echo "streamtrack SD_PROB $out - number:$NUMVZFIBERS"
                timeout 3600 time streamtrack -quiet SD_PROB lmax${i_lmax}.mif tmp.tck \
                    -seed wm_vis.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMVZFIBERS \
                    -maxnum $MAXNUMVZFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
                mv tmp.tck $out
            fi

            out=${prefix}_wb.tck
            if [ ! -f $out ] && [ $NUMFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMFIBERS"
                timeout 3600 time streamtrack -quiet SD_PROB lmax${i_lmax}.mif tmp.tck \
                    -seed wm.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMFIBERS \
                    -maxnum $MAXNUMFIBERSATTEMPTED \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
                mv tmp.tck $out
            fi

        done
    done
fi

###################################################################################################
#
# SD_STREAM
#

if [ $DOSTREAM == "true" ] ; then
    for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
        for i_curv in $DETR_CURVS; do

            prefix=csd_lmax${i_lmax}_wm_SD_STREAM_curv${i_curv}

            out=${prefix}_cc.tck
            if [ ! -f $out ] && [ $NUMCCFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMCCFIBERS"
                timeout 3600 time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif tmp.tck \
                    -seed cc.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMCCFIBERS \
                    -maxnum $MAXNUMCCFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
                mv tmp.tck $out
            fi

            #TODO this times out too often (NUMMTFIBERS now default to 0)
            out=${prefix}_lm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMMTFIBERS"
                timeout 3600 time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif tmp.tck \
                    -seed lh_motor_seed.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMMTFIBERS \
                    -maxnum $MAXNUMMTFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH \
                    -include lh_motor.mif \
                    -include br_stem.mif
                mv tmp.tck $out
            fi

            #TODO this times out too often (NUMMTFIBERS now default to 0)
            out=${prefix}_rm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMMTFIBERS"
                timeout 3600 time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif tmp.tck \
                    -seed rh_motor_seed.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMMTFIBERS \
                    -maxnum $MAXNUMMTFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH \
                    -include rh_motor.mif \
                    -include br_stem.mif
                mv tmp.tck $out
            fi

            out=${prefix}_vz.tck
            if [ ! -f $out ] && [ $NUMVZFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMVZFIBERS"
                timeout 3600 time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif tmp.tck \
                    -seed wm_vis.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMVZFIBERS \
                    -maxnum $MAXNUMVZFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
                mv tmp.tck $out
            fi

            out=${prefix}_wb.tck
            if [ ! -f $out ] && [ $NUMFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMFIBERS"
                timeout 3600 time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif tmp.tck \
                    -seed wm.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMFIBERS \
                    -maxnum $MAXNUMFIBERSATTEMPTED \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
                mv tmp.tck $out
            fi

        done
    done
fi

###################################################################################################

echo "done tracking. creating the final track.tck"
holder=(*.tck*)
cat_tracks track.tck ${holder[*]}
track_info track.tck > track_info.txt

## hard check of count
COUNT=`track_info track.tck | grep -w 'count' | awk '{print $2}'`
echo "Ensemble tractography generated $COUNT of a requested $TOTAL"

## adding product.json /w streamline count
echo "{\"count\": $COUNT}" > product.json

#if [ $COUNT -ne $TOTAL ]; then
#    echo "Incorrect count. Tractography failed."
#    rm track.tck
#    exit 1
#fi

# reduce storage load
rm csd*.tck
rm *tensor.tck
rm *.mif

#remove all .nii.gz except wm_full (as mask.nii.gz)
#cp wm_full.nii.gz wm_full.nii.gz.backup
#rm *.nii.gz
#cp wm_full.nii.gz.backup mask.nii.gz

