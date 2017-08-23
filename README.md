[![Abcdspec-compliant](https://img.shields.io/badge/ABCD_Spec-v1.0-green.svg)](https://github.com/soichih/abcd-spec)

# app-ensembletracking

Application to run ensemble tractography

# Run

To run this application outside of Brain-Life, git clone this repo, then create a config file that loos like..

```
{
	"bvals": "input/105115_dwi_aligned_trilin_noMEC.bvals",
	"bvecs": "input/105115_dwi_aligned_trilin_noMEC.bvecs",
	"dwi": "input/105115_dwi_aligned_trilin_noMEC.nii.gz",
	"freesurfer": "input/105115_output",
	"fibers": 60000,
	"do_probabilistic": false,
	"do_deterministic": false,
	"do_tensor": true
}
```
