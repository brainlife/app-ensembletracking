[![Abcdspec-compliant](https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg)](https://github.com/brain-life/abcd-spec)
[![Run on Brainlife.io](https://img.shields.io/badge/Brainlife-bl.app.33-blue.svg)](https://doi.org/10.25663/bl.app.33)

# app-ensembletracking

<!-- brainlife-app:begin (generated from the App manifest; edit the manifest, not this block) -->

**Generates an ensemble whole-brain tractogram from DWI with MRtrix 0.2.12, combining tensor, CSD deterministic and CSD probabilistic tracking over several lmax and curvature values into one .tck.**

Implements Ensemble Tractography (Takemura et al. 2016): fits CSD at every even lmax up to max_lmax, tracks with DT_STREAM, SD_STREAM and SD_PROB over the chosen curvature values from white-matter and corpus-callosum seeds (plus optional optic radiation and visual tracts), and concatenates all candidates into track.tck. Use it to produce a rich candidate tractogram, for example for LiFE or COMMIT filtering. Requires a FreeSurfer run of the same subject for the masks. num_or_fibers above 25 makes the App exit.

Run it on brainlife.io: [https://doi.org/10.25663/bl.app.103](https://doi.org/10.25663/bl.app.103)

| Input | Datatype | Required | Description |
|---|---|---|---|
| `dwi` | `neuro/dwi` | yes | Diffusion-weighted image with bvals and bvecs. |
| `freesurfer` | `neuro/freesurfer` | yes | FreeSurfer recon-all output of the same subject, used to build white-matter, corpus callosum and other seed/ROI masks. |

| Output | Datatype | Description |
|---|---|---|
| `output` | `neuro/track/tck` | Ensemble tractogram (track.tck) concatenating all algorithm, lmax and curvature runs. |
| `mask_dwi` | `neuro/mask` | (despite the odd output directory name "mask_dwi") A brain mask created from freesurfer aparc+aseg converted to .nii.gz using input t1 as output template volume (--temp). It uses all white matter segments (--match 2 41 16 17 28 60 51 53 12 52 13 18 54 50 11 251 252 253 254 255 10 49 46 7) see FreeSurferColorLUT |

| Parameter | Type | Default | Description |
|---|---|---|---|
| `stepsize` | number | `0.2` | set the step size of the tracking |
| `minlength` | number | `10` | set the minimum length of the streamlines generated |
| `maxlength` | number | `200` | set the maximum length of the streamlines generated |
| `num_or_fibers` | number | `0` | Number of streamlines to track the optic radiation (probabilistic tracking only) |
| `num_mt_fibers` | number | `0` | (temporarily disabled as this tracking gets stuck) Number of streamlines to track the cortico-spinal tract |
| `num_vz_fibers` | number | `0` | Number of streamlines to track the visual-associative tracts |
| `detr_curvs` | string | `0.25 0.5 1 2 4` | Range of curvature parameters used for deterministic tracking |
| `prob_curvs` | string | `0.25 0.5 1 2 4` | Range of curvature parameters used for probabilistic tracking |
| `num_cc_fibers` | number | `2500` | Number of streamlines to track seeding the corpus callosum |
| `num_fibers` | integer | `12500` | Total number of streamlines requested per individual streamline output file (.tck) |
| `max_lmax` | integer |  | Maximum number of parameters for the constrained spherical deconvolution. Leave it empty to auto calculate from the number of available directions in bvecs/bvals. |
| `do_tensor` | boolean | `true` | Include tensor-based deterministic tracking (DT_STREAM). |
| `do_probabilistic` | boolean | `true` | Include CSD-based probabilistic tracking (SD_PROB) at each lmax and curvature. |
| `do_deterministic` | boolean | `true` | Include CSD-based deterministic tracking (SD_STREAM) at each lmax and curvature. |

Runtime: container `brainlife/freesurfer:6.0.0`; 8 CPUs; 15 GB memory; 15 h walltime; needs `FREESURFER_LICENSE`.

Please cite:
- Takemura H, Caiafa CF, Wandell BA, Pestilli F. Ensemble tractography. PLoS Comput Biol 12(2): e1004692 (2016). [doi:10.1371/journal.pcbi.1004692](https://doi.org/10.1371/journal.pcbi.1004692)

<!-- brainlife-app:end -->

This App uses MRtrix 0.2.12 to do ensemble tracking using tensor and constrained spherical deconvolution (csd) algorithms. It generates a large set of candidate streamlines using a tensor-based deterministic model, csd-based deterministic model, and csd-based probabilistic model. The csd-based models can be computed at lmax values of 2, 4, 6, 8, 10, and 12. All candidate streamlines are combined into a single track.mat file. 

max lmax can be left blank and it will be calculated for you. 

If you wish to use just deterministic tracking (MRtrix streamtrack parameter SD_STREAM) check do_deterministic. 

If you wish to use just probabilistic tracking (MRtrix streamtrack parameter SD_PROB) check do_probabilistic. 

If you wish to use the tensor tracking (MRtrix streamtrack parameter DT_STREAM) check do_tensor. By default it will use all three tracking methods.

For more information about Ensemble Tractography see Takemura, H., Caiafa, C. F., Wandell, B. A., & Pestilli, F. (2016). Ensemble tractography. PLoS computational biology, 12(2), e1004692.

![img](ensemble.png)

### Authors
- Lindsey Kitchell (kitchell@indiana.edu)
- Soichi Hayashi (hayashis@iu.edu)
- Brent McPherson (bcmcpher@iu.edu)

### Project director
- Franco Pestilli (franpest@indiana.edu)

### Funding 
[![NSF-BCS-1734853](https://img.shields.io/badge/NSF_BCS-1734853-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1734853)
[![NSF-BCS-1636893](https://img.shields.io/badge/NSF_BCS-1636893-blue.svg)](https://nsf.gov/awardsearch/showAward?AWD_ID=1636893)

## Running the App 

### On Brainlife.io

You can submit this App online 

* with dtiInit input [https://doi.org/10.25663/bl.app.33](https://doi.org/10.25663/bl.app.33) 
* with dwi input [https://doi.org/10.25663/bl.app.103](https://doi.org/10.25663/bl.app.103)

via the "Execute" tab.

### Running Locally (on your machine)

1. git clone this repo.
2. Inside the cloned directory, create `config.json` with something like the following content with paths to your input files.

```json
{
    "dwi": "/N/u/hayashis/Karst/testdata/108323/dwi/dwi.nii.gz",
    "bvecs": "/N/u/hayashis/Karst/testdata/108323/dwi/dwi.bvecs",
    "bvals": "/N/u/hayashis/Karst/testdata/108323/dwi/dwi.bvals",
    "freesurfer": "/N/u/hayashis/Karst/testdata/108323/freesurfer/output",
    "stepsize": 0.2,
    "minlength": 10,
    "maxlength": 200,
    "num_or_fibers": 0,
    "num_mt_fibers": 0,
    "num_vz_fibers": 0,
    "detr_curvs": "0.25 0.5 1 2 4",
    "prob_curvs": "0.25 0.5 1 2 4",
    "num_cc_fibers": 2500,
    "num_fibers": 12500,
    "do_tensor": true,
    "do_probabilistic": true,
    "do_deterministic": true
}
```

3. Launch the App by executing `main`

```bash
./main
```

### Sample Datasets

If you don't have your own input file, you can download sample datasets from Brainlife.io, or you can use [Brainlife CLI](https://github.com/brain-life/cli).

```
npm install -g brainlife
bl login
mkdir input
bl dataset download 5a050a00eec2b300611abff3 && mv 5a050a00eec2b300611abff3 input/dwi
bl dataset download 5a065cc75ab38300be518f51 && mv 5a065cc75ab38300be518f51 input/freesurfer
```

## Output

```
track.tck
```

### Dependencies

This App only requires [singularity](https://www.sylabs.io/singularity/) to run. If you don't have singularity, you will need to install following dependencies.  

  - Freesurfer 6
  - FSL 5.0.9
  - Mrtrix 0.2.12

