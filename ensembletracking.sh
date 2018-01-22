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

#if max_lmax is empty, auto calculate
MAXLMAX=`jq -r '.max_lmax' config.json`
if [[ $MAXLMAX == "null" || -z $MAXLMAX ]]; then
	echo "max_lmax is empty.. determining which lmax to use from .bvals"
	MAXLMAX=`./calculatelmax.py`
fi

#NUMFIBERS=`./calculatetracks.py $MAXLMAX`
NUMFIBERS=`jq -r '.num_fibers' config.json`
MAXNUMFIBERSATTEMPTED=$(($NUMFIBERS*2))

#NUMCCFIBERS=$(($NUMWMFIBERS/5))
NUMCCFIBERS=`jq -r '.num_cc_fibers' config.json`
MAXNUMCCFIBERS=$(($NUMCCFIBERS*2))

echo "Using MAXLMAX: $MAXLMAX"
echo "Using NUMFIBERS per each track: $NUMFIBERS"
echo "Using MAXNUMBERFIBERSATTEMPTED $MAXNUMFIBERSATTEMPTED"


#look for matlab script in service installation directory
#export MATLABPATH=$MATLABPATH:$SERVICE_DIR

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



echo "converting $input_nii_gz to dwi.mif"
alias
if [ -f dwi.mif ]; then
    echo "dwi.mif already exist... skipping"
else
    time mrconvert --quiet $input_nii_gz dwi.mif
    ret=$?
    if [ ! $ret -eq 0 ]; then
        echo $ret > finished
        exit $ret
    fi
fi

echo "done convverting"

###################################################################################################

#echo "make brainmask from dwi data (about 18 minutes)"
#if [ -f brainmask.mif ]; then
#    echo "brainmask.mif already exist... skipping"
#else
#    time /usr/lib/mrtrix/bin/average -quiet dwi.mif -axis 3 - | /usr/lib/mrtrix/bin/threshold -quiet - - | /usr/lib/mrtrix/bin/median3D -quiet - - | /usr/lib/mrtrix/bin/median3D -quiet - brainmask.mif
#    ret=$?
#    if [ ! $ret -eq 0 ]; then

#       echo $ret > finished
#        exit $ret
#    fi
#fi

###################################################################################################

if [ $DOTENSOR == "true" ]; then
	echo "fit tensor model (takes about 16 minutes)"
	if [ -f dt.mif ]; then
    		echo "dt.mif already exist... skipping"
	else
	    time dwi2tensor dwi.mif -grad $BGRAD dt.mif 
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
        echo $ret > finished
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
			echo $ret > finished
			exit $ret
		fi
		
	fi
done 

echo "DONE performing preprocessing of data before starting tracking..."

###################################################################################################

#echo tracking Deterministic Tensorbased

if [ $DOTENSOR == "true" ] ; then
	echo "tensor tracking"
	streamtrack -quiet DT_STREAM dwi.mif wm_tensor.tck -seed wm.mif -mask tm.mif -grad $BGRAD -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
	streamtrack -quiet DT_STREAM dwi.mif cc_tensor.tck -seed cc.mif -mask tm.mif -grad $BGRAD -number $NUMCCFIBERS -maxnum $MAXNUMCCFIBERS

fi

if [ $DOPROB == "true" ] ; then
	i_tracktype=SD_PROB
	echo Tracking $i_tracktype #Deterministic=1 Probabilistic=2 CSD-based
	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
		for i_curv in $STREAM_CURVS; do
			echo Tracking CSD-based Lmax=$i_lmax
			outfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}.tck
			ccoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_cc.tck
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $outfile -seed wm.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
			streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $ccoutfile -seed cc.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMCCFIBERS -maxnum $MAXNUMCCFIBERS
		done
	done
fi

if [ $DOSTREAM == "true" ] ; then
	i_tracktype=SD_STREAM
	echo Tracking $i_tracktype #Deterministic=1 Probabilistic=2 CSD-based
	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
		for i_curv in $STREAM_CURVS; do
                        echo Tracking CSD-based Lmax=$i_lmax
                        outfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}.tck
                        ccoutfile=csd_lmax${i_lmax}_wm_${i_tracktype}_curv${i_curv}_cc.tck
                        streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $outfile -seed wm.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
                        streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $ccoutfile -seed cc.mif -mask tm.mif -grad $BGRAD -curvature ${i_curv} -number $NUMCCFIBERS -maxnum $MAXNUMCCFIBERS
                done
        done
fi

###################################################################################################

echo "DONE tracking."

#rm *.mif
rm *.nii.gz

echo "creating ensemble tractography"
./matlabcompiled/ensemble_tck_generator

rm grad.b
rm response.txt
rm csd*
rm *tensor.tck

