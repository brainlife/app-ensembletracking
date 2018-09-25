[![Abcdspec-compliant](https://img.shields.io/badge/ABCD_Spec-v1.1-green.svg)](https://github.com/brain-life/abcd-spec)
[![Run on Brainlife.io](https://img.shields.io/badge/Brainlife-bl.app.33-blue.svg)](https://doi.org/10.25663/bl.app.33)

# app-ensembletracking

This App combines multiple tractography methods by implementing Ensemble Tractography. It creates a large set of candidate streamlines using an ensemble of algorithms and parameter values. 

![img](ensemble.png)

### Authors
- Lindsey Kitchell (kitchell@indiana.edu)
- Soichi Hayashi (hayashis@iu.edu)
- Brent McPherson (bcmcpher@iu.edu)

### Project directors
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

All output files will be generated under the current working directory (pwd). The main output of this App is a file called `output.mat`. This file contains following object.

```
fe = 

    name: 'temp'
    type: 'faseval'
    life: [1x1 struct]
      fg: [1x1 struct]
     roi: [1x1 struct]
    path: [1x1 struct]
     rep: []
```

`output_fg.pdb` contains all fasicles with >0 weights withtin fg object (fibers)

#### Product.json

The secondary output of this app is `product.json`. This file allows web interfaces, DB and API calls on the results of the processing. 

### Dependencies

This App only requires [singularity](https://www.sylabs.io/singularity/) to run. If you don't have singularity, you will need to install following dependencies.  

  - Matlab: https://www.mathworks.com/products/matlab.html
  - jsonlab: https://www.mathworks.com/matlabcentral/fileexchange/33381-jsonlab-a-toolbox-to-encode-decode-json-files
  - VISTASOFT: https://github.com/vistalab/vistasoft/
  - ENCODE: https://github.com/brain-life/encode
  - MBA: https://github.com/francopestilli/mba



