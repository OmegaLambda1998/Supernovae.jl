[![Tests](https://github.com/OmegaLambda1998/Supernovae.jl/actions/workflows/test_and_codecov.yml/badge.svg)](https://github.com/OmegaLambda1998/Supernovae.jl/actions/workflows/test_and_codecov.yml)
[![Documentation](https://github.com/OmegaLambda1998/Supernovae.jl/actions/workflows/documentation.yml/badge.svg)](https://omegalambda.au/Supernovae.jl/)
[![Coverage Status](https://coveralls.io/repos/github/OmegaLambda1998/Supernovae.jl/badge.svg?branch=main)](https://coveralls.io/github/OmegaLambda1998/Supernovae.jl?branch=main)

# [Supernovae.jl](https://github.com/OmegaLambda1998/Supernovae.jl) Documentation

Provides methods for reading in and plotting supernova lightcurves from text files. Extremely flexible reading methods allow for almost any reasonable lightcurve data file syntax to be read.

## Prerequisites
To automatically download passbands from the [SVO Filter Profile Service](http://svo2.cab.inta-csic.es/theory/fps/), you must install the python package [astroquery](https://astroquery.readthedocs.io/en/latest/index.html). This is installed as part of the build process, installing into a `Conda.jl` conda environment.

## Install
```bash
$ git clone git@github.com:OmegaLambda1998/Supernovae.jl.git 
$ cd Supernovae.jl
$ make
```
This will instantiate and build `Supernovae.jl`, installing all required Julia packages, and setting up a Conda environment for the required Python packages. Finally it will run the tests to make sure everything is working. If you want to skip testing run `make install` instead. You can also run `./scripts/Supernovae -v ./Examples/Inputs/2021zby/2021zby_data.toml` to load and plot the lightcurve of 2021zby. This will create a `.svg` plot in `./Examples/Outputs/2021zby/`.

## Usage
```bash
$ ./scripts/Supernovae -v path/to/input.toml
```

Details on how to build the input files which control `Supernovae.jl` can be found in [Usage](./usage.md).

## Example data file
The following example input file can be found in the Examples directory. `base_path` is the directory containing your input file.

```toml
[ global ]
filter_path = "../Filters" # Defaults to base_path / Filters
output_path = "../../Outputs/2021zby" # Defaults to base_path / Output

# Data
[ data ]
# First include information about the supernova
name = "2021zby" # Required
zeropoint = 8.9 # Required
redshift = 0.02559 # Required
max_flux_err = 2.5e2 # Optional, set's the maximum allowed value for the uncertainty in the flux, assumes same units as flux
peak_time = true # Default false. Can either be true, in which case all times will become relative to the peak data point. Alternatively, give a value, and all times will be relative to that value
peak_time_unit = "d" # Optional, default to d

[[ data.observations ]] # Now load in different observations of the supernova. This can either be one file with all observations, or you can load in multiple files
name = "atlas" # Required, Human readable name to distinguish observations
path = "atlas_1007.dat" # Required, Accepts either relative (to Supernova) or absolute path
delimiter = " " # Optional, defaults to comma
facility = "Misc"
instrument = "Atlas" # Optional, will overwrite anything in the file 
upperlimit = "flux_err"

# Since this file contains a header that isn't in the expected format, you can optionally specify what each header corresponds to.
# If you do this you MUST specify the time, flux, and flux error.
# You can also specify the filter, instrument, or upperlimit columns if they're in the file. If not, specify them above
header.time.col = "MJD"
header.time.unit = "d"

header.flux.col = "uJy"
header.flux.unit = "µJy"

header.flux_err.col = "duJy"
header.flux_err.unit = "µJy"

header.passband.col = "F"

[[ data.observations ]]
name = "tess 6hr"
path = "tess_2_6hrlc.txt"
delimiter = " "
comment = "#" # Optional, defines what is a comment (will be removed). Defaults to #
facility = "tess"
instrument = "tess"
passband = "Red"
filter_name = "Tess"
upperlimit = false
flux_offset = 0.296 # Defaults to 0, assumes same units as flux

[[ plot.lightcurve ]]
filters = ["Red", "orange"]
markersize = 21
marker."tess 6hr" = "utriangle"
rename."tess 6hr" = "Tess (6hr)"
marker.atlas = "circle"
rename.atlas = "Atlas"
colour.Red = "red"
rename.Red = "Tess: Red"
rename.orange = "Atlas: Orange (+150 μJy)"
colour.orange = "orange"
offset.orange = 150
legend = true
```
