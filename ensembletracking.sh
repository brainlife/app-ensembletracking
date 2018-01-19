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

NUMFIBERS=`./calculatetracks.py $MAXLMAX`
MAXNUMFIBERSATTEMPTED=$(($NUMFIBERS*2))

echo "Using MAXLMAX: $MAXLMAX"
echo "Using NUMFIBERS per each track: $NUMFIBERS"
echo "Using MAXNUMBERFIBERSATTEMPTED $MAXNUMFIBERSATTEMPTED"


#look for matlab script in service installation directory
#export MATLABPATH=$MATLABPATH:$SERVICE_DIR

if [ -f grad.b ] && [ -f wm.nii.gz ]; then
	echo "grad.b and wm.nii.gz exist... skipping"
else
	echo "starting matlab to create grad.b & wm.nii.gz"
	./matlabcompiled/main
fi

echo "converting wm.nii.gz to wm.mif"
if [ -f wm.mif ]; then
    echo "wm.mif already exist... skipping"
else
    time mrconvert --quiet wm.nii.gz wm.mif

    ret=$?
    if [ ! $ret -eq 0 ]; then
	echo "failed to mrconver wm.nii.gz to wm.mif"
        echo $ret > finished
        exit $ret
    fi
fi

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

echo "make brainmask from dwi data (about 18 minutes)"
if [ -f brainmask.mif ]; then
    echo "brainmask.mif already exist... skipping"
else
    time average -quiet dwi.mif -axis 3 - | threshold -quiet - - | median3D -quiet - - | median3D -quiet - brainmask.mif
    ret=$?
    if [ ! $ret -eq 0 ]; then

        echo $ret > finished
        exit $ret
    fi
fi

###################################################################################################

echo "fit tensor model (takes about 16 minutes)"
if [ -f dt.mif ]; then
    echo "dt.mif already exist... skipping"
else
    time dwi2tensor dwi.mif -grad $BGRAD dt.mif 
fi

if [ -f fa.mif ]; then
    echo "fa.mif already exist... skipping"
else
    time tensor2FA dt.mif - | mrmult - brainmask.mif fa.mif
fi

###################################################################################################

echo "estimate response function"
if [ -f sf.mif ]; then
    echo "sf.mif already exist... skipping"
else 
    time erode -quiet brainmask.mif -npass 3 - | mrmult -quiet fa.mif - - | threshold -quiet - -abs 0.7 sf.mif
fi

if [ -f response.txt ]; then
    echo "response.txt already exist... skipping"
else
#    time estimate_response -quiet dwi.mif sf.mif -lmax 6 -grad $BGRAD response.txt
    time estimate_response -quiet dwi.mif sf.mif -grad $BGRAD response.txt
    ret=$?
    if [ ! $ret -eq 0 ]; then
        echo $ret > finished
        exit $ret
    fi
fi

###################################################################################################

for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
# Perform CSD in each white matter voxel
#for i_lmax in 2 4 6 8 10 12; do
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
	if [ -s wm_tensor.tck ]; then
		echo "wm_tensor.tck already exists....skipping"
	else
		time streamtrack -quiet DT_STREAM dwi.mif wm_tensor.tck -seed wm.mif -mask wm.mif -grad $BGRAD -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
		ret=$?
		if [ ! $ret -eq 0 ]; then
			echo $ret > finished
			exit $ret
		fi
	fi
fi

if [ $DOPROB == "true" ] ; then
	i_tracktype=SD_PROB
	echo Tracking $i_tracktype #Deterministic=1 Probabilistic=2 CSD-based
	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
	#for i_lmax in 2 4 6 8 10 12; do
		echo Tracking CSD-based Lmax=$i_lmax
		outfile=csd_lmax${i_lmax}_wm_${i_tracktype}.tck
		if [ -s $outfile ]; then
			echo "$outfile already exist - skipping streamtracking"
		else
			time streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $outfile -seed wm.mif  -mask wm.mif  -grad $BGRAD -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
			ret=$?
			if [ ! $ret -eq 0 ]; then
				echo $ret > finished
				exit $ret
			fi
		fi
	done
fi

if [ $DOSTREAM == "true" ] ; then
	i_tracktype=SD_STREAM
	echo Tracking $i_tracktype #Deterministic=1 Probabilistic=2 CSD-based
	for (( i_lmax=2; i_lmax<=$MAXLMAX; i_lmax+=2 )); do
	#for i_lmax in 2 4 6 8 10 12; do
		echo Tracking CSD-based Lmax=$i_lmax
		outfile=csd_lmax${i_lmax}_wm_${i_tracktype}.tck
		if [ -s $outfile ]; then
			echo "$outfile already exist - skipping streamtracking"
		else
			time streamtrack -quiet $i_tracktype lmax${i_lmax}.mif $outfile -seed wm.mif  -mask wm.mif  -grad $BGRAD -number $NUMFIBERS -maxnum $MAXNUMFIBERSATTEMPTED
			ret=$?
			if [ ! $ret -eq 0 ]; then
				echo $ret > finished
				exit $ret
			fi
		fi
	done
fi

###################################################################################################

echo "DONE tracking."

#rm *.mif
rm *.nii.gz

echo "creating ensemble tractography"
./matlabcompiled/ensemble_tck_generator

