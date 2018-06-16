#!/bin/bash

#make the script to fail if any of the command fails.
set -e

#echo commands executed
set -x

export PATH=$PATH:/usr/lib/mrtrix/bin

dtiinit=`jq -r '.dtiinit' config.json`
export input_nii_gz=$dtiinit/`jq -r '.files.alignedDwRaw' $dtiinit/dt6.json`
export BVALS=$dtiinit/`jq -r '.files.alignedDwBvecs' $dtiinit/dt6.json`
export BVECS=$dtiinit/`jq -r '.files.alignedDwBvals' $dtiinit/dt6.json`

DOPROB=`jq -r '.do_probabilistic' config.json`
DOSTREAM=`jq -r '.do_deterministic' config.json`
DOTENSOR=`jq -r '.do_tensor' config.json`

PROB_CURVS=`jq -r '.prob_curvs' config.json`
DETR_CURVS=`jq -r '.detr_curvs' config.json`

NUMFIBERS=`jq -r '.num_fibers' config.json`
MAXNUMFIBERSATTEMPTED=$(($NUMFIBERS*50))

STEPSIZE=`jq -r '.stepsize' config.json`
MINLENGTH=`jq -r '.minlength' config.json`
MAXLENGTH=`jq -r '.maxlength' config.json`

NUMCCFIBERS=`jq -r '.num_cc_fibers' config.json`
NUMORFIBERS=`jq -r '.num_or_fibers' config.json`
NUMMTFIBERS=`jq -r '.num_mt_fibers' config.json`
NUMVZFIBERS=`jq -r '.num_vz_fibers' config.json`

MAXNUMORFIBERS=$(($NUMORFIBERS*250000))
MAXNUMMTFIBERS=$(($NUMMTFIBERS*250000))
MAXNUMVZFIBERS=$(($NUMVZFIBERS*250000))
MAXNUMCCFIBERS=$(($NUMCCFIBERS*50))

#if max_lmax is empty, auto calculate
MAXLMAX=`jq -r '.max_lmax' config.json`
if [[ $MAXLMAX == "null" || -z $MAXLMAX ]]; then
    echo "max_lmax is empty... determining which lmax to use from .bvals"
    MAXLMAX=`./calculatelmax.py`
    echo "Using MAXLMAX: $MAXLMAX"
fi

echo "Using NUMFIBERS per each track: $NUMFIBERS"
echo "Using MAXNUMBERFIBERSATTEMPTED: $MAXNUMFIBERSATTEMPTED"

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
            TOTAL=$(($TOTAL+$NUMCCFIBERS+$NUMMTFIBERS+$NUMMTFIBERS+$NUMVZFIBERS+$NUMFIBERS))
        done
    done
fi
echo "Expecting $TOTAL streamlines in final ensemble."
#
#
###################################################################################################

if [ ! -f grad.b ]; then
    echo "creating grad.b & wm.nii.gz"
    ./compiled/main
fi

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
        time streamtrack -quiet DT_STREAM dwi.mif cc_tensor.tck \
            -seed cc.mif \
            -mask tm.mif \
            -grad grad.b \
            -number $NUMCCFIBERS \
            -maxnum $MAXNUMCCFIBERS \
            -step $STEPSIZE \
            -minlength $MINLENGTH \
            -length $MAXLENGTH
    fi

    if [ ! -f wm_tensor.tck ] && [ $NUMFIBERS -gt 0 ]; then
        echo "streamtrack DT_STREAM wm_tensor.tck - number:$NUMFIBERS"
        time streamtrack -quiet DT_STREAM dwi.mif wm_tensor.tck \
            -seed wm.mif \
            -mask tm.mif \
            -grad grad.b \
            -number $NUMFIBERS \
            -maxnum $MAXNUMFIBERSATTEMPTED \
            -step $STEPSIZE \
            -minlength $MINLENGTH \
            -length $MAXLENGTH
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
                echo "streamtrack SD_PROB $out - number:$NUMORFIBERS"
                time streamtrack SD_PROB lmax${i_lmax}.mif $out \
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
            fi

            out=${prefix}_ro.tck
            if [ ${i_lmax} -le 2 ] && [ ! -f $out ] && [ $NUMORFIBERS -gt 0 ] ; then
                echo "streamtrack SD_PROB $out - number:$NUMORFIBERS"
                time streamtrack SD_PROB lmax${i_lmax}.mif $out \
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
            fi
                        
            out=${prefix}_cc.tck
            if [ ! -f $out ] && [ $NUMCCFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMCCFIBERS"
                time streamtrack -quiet SD_PROB lmax${i_lmax}.mif $out \
                    -seed cc.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMCCFIBERS \
                    -maxnum $MAXNUMCCFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
            fi

            out=${prefix}_lm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMMTFIBERS"
                time streamtrack -quiet SD_PROB lmax${i_lmax}.mif $out \
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
            fi

            out=${prefix}_rm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMMTFIBERS"
                time streamtrack -quiet SD_PROB lmax${i_lmax}.mif $out \
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
            fi

            out=${prefix}_vz.tck
            if [ ! -f $out ] && [ $NUMVZFIBERS -gt 0 ] ; then
                echo "streamtrack SD_PROB $out - number:$NUMVZFIBERS"
                time streamtrack -quiet SD_PROB lmax${i_lmax}.mif $out \
                    -seed wm_vis.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMVZFIBERS \
                    -maxnum $MAXNUMVZFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
            fi

            out=${prefix}_wb.tck
            if [ ! -f $out ] && [ $NUMFIBERS -gt 0 ]; then
                echo "streamtrack SD_PROB $out - number:$NUMFIBERS"
                time streamtrack -quiet SD_PROB lmax${i_lmax}.mif $out \
                    -seed wm.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMFIBERS \
                    -maxnum $MAXNUMFIBERSATTEMPTED \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
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
                time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif $out \
                    -seed cc.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMCCFIBERS \
                    -maxnum $MAXNUMCCFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
            fi

            out=${prefix}_lm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMMTFIBERS"
                time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif $out \
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
            fi

            out=${prefix}_rm.tck
            if [ ! -f $out ] && [ $NUMMTFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMMTFIBERS"
                time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif $out \
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
            fi

            out=${prefix}_vz.tck
            if [ ! -f $out ] && [ $NUMVZFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMVZFIBERS"
                time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif $out \
                    -seed wm_vis.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMVZFIBERS \
                    -maxnum $MAXNUMVZFIBERS \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
            fi

            out=${prefix}_wb.tck
            if [ ! -f $out ] && [ $NUMFIBERS -gt 0 ]; then
                echo "streamtrack SD_STREAM $out - number:$NUMFIBERS"
                time streamtrack -quiet SD_STREAM lmax${i_lmax}.mif $out \
                    -seed wm.mif \
                    -mask tm.mif \
                    -grad grad.b \
                    -curvature $i_curv \
                    -number $NUMFIBERS \
                    -maxnum $MAXNUMFIBERSATTEMPTED \
                    -step $STEPSIZE \
                    -minlength $MINLENGTH \
                    -length $MAXLENGTH
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

if [ $COUNT -ne $TOTAL ]; then
    echo "Incorrect count. Tractography failed."
    rm track.tck
    exit 1
fi

# reduce storage load
rm csd*.tck
rm *tensor.tck
rm *.nii.gz

