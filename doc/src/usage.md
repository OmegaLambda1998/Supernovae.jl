# Usage Details

To load a supernova with `Supernovae.jl` you must create an input file containing details on how to read the lightcurve files of the supernova. This file is read in using [BetterInputFiles.jl](https://www.omegalambda.au/BetterInputFiles.jl/dev/), which provides a number of advantages, including:
- Choice of `.yaml`, `.toml`, or `.json` files. All examples will be `.toml` but you can choose whichever is preferable for your workflow.
- Case-insensitive keys
- Ability to include other files via `<include path/to/file.toml>`. This will essentially copy paste the contents of `file.toml` into your input file.
- Ability to interpolate environmental variables via `<$ENV_VAR>`.
- Ability to interpolate other keys in your input via `<%key>`. As long as `<%key>` exists in the same subtree, the value of key will be interpolated, allowing for easy duplication.
- Default values vai `[DEFAULT]`. And sub-keys are available everywhere. This is particularly useful when combined with interpolation.

See the `BetterInputFiles` docs for more details and examples about how this all works.

## Supernovae.jl Input Files

There are three keys which can be included in a supernova's input file, `[ global ]`, `[ data ]`, and `[ plot ]`.

### `[ global ]`
`[ global ]` controls file-paths and is optional. File paths can be absolute, or relative to `base_path` which, by default, is the parent directory of the input file. The file paths that can be defined are:
```toml
[ global ]
    base_path = "./" # All other paths will be relative to this path
    output_path = "base_path/Output" # Where all output will be placed
    filter_path = "base_path/Filters" # Where filter transmission curves will be saved and loaded
    data_path = "base_path/Data" # any relative paths to data files will be relative to data_path
```

### `[ data ]`
`[ data ]` includes all the options for loading in your supernova and is required. `data` keys include:
```toml
[ data ]
name::String # The name of the supernova
zeropoint::Float64 # The zeropoint of the supernova
zeropoint_unit::String="AB_mag" # The unit of the zeropoint.
redshift::Float64 # The redshift of the supernova
max_flux_err::Float64=Inf # The maximum allowed flux error. Any datapoint with flux error greater than this will be removed.
max_flux_err_unit::String="μJy" # The unit of the maximum flux error.
peak_time::Union{Bool, Float64}=false # If true, set time relatative to the time of maximum flux. Alternatively, provide a value for time to be set relative to.
peak_time_unit::String="d" # The unit of the peak_time, only used if peak_time is a value.
```
In addition to these options, you must specify `[[ data.observations ]]`, which contain details on the data files you with to associate with this supernova. The main assumption is that columns are different parameters and rows are different datapoints. Since `[[ data.observations ]]` is a list object, you can include as many files as you want, and they will all get collated into the one supernova object. `observations` keys include:
```toml
[[ data.observations ]]
name::String # Human readable name of the observations. Typically this is the survey responsible for the observations
path::String # Path to data file containing photometry information. Can be absolute or relative (to data_path).
delimiter::String=", " # Delimiter of the data file.
comment::String="#" # Comment character of the data file.
facility::Union{String,Nothing}=nothing # Override the facility responsible for the data. Use this if this information is not available in the data file.
instrument::Union{String,Nothing}=nothing # Override the instrument responsible for the data. Use this if this information is not available in the data file.
passband::Union{String,Nothing}=nothing # Override the passband of the data. Use this if this information is not available in the data file.
upperlimit::Union{Bool,String,Nothing}=nothing # Override whether the data is an upperlimit. The String options include ["time", "flux", "flux_err"]. If a String, upperlimit is true if that parameter is negative. Use this if this information is not available in the data file.
flux_offset::Float64=0 # Apply an offset to the flux. Assumes flux_offset is the same unit as flux.
upperlimit_true::Vector{String}=["T", "TRUE"] # Provides the (case-insensitive) string which corresponds to an upperlimit being true. Used when reading the upperlimit from a column of the data file. 
upperlimit_false::Vector{String}=["F", "FALSE"] # Provides the (case-insensitive) string which corresponds to an upperlimit being false. Used when reading the upperlimit from a column of the data file. 
```

The rest of the `observations` keys are related to loading in data from the data file. Your data file must include per-observation time, flux, and flux error information. Additionally, per-observation facility, instrument, passband, and upperlimit information can be included. In general there are three different ways to load a parameter from the data file.

#### Default Method
The default assumption is that the data file has a header line with syntax:
```
time [d], flux [μJy], flux_err [μJy]
```
If this is the case, then you need not provide any more details and `Supernovae.jl` will be able to extract these.

#### Column Name
If your header doesn't exactly match the default header, then you can specify which column corresponds to which parameter via the header name of that parameter:
```toml
[[ data.observations ]]
header.time.col = "MJD" # The name of the time column
header.time.unit = "d" # The unit of the time column
header.flux.col = "brightness" # The name of the time column
header.flux.unit = "μJy" # The unit of the time column
header.flux_err.col = "d_brightness" # The name of the time column
header.flux_err.unit = "μJy" # The unit of the time column
header.facility.col = "survey" # The name of the facility column
header.instrument.col = "telescope" # The name of the instrument column
header.passband.col = "filter" # The name of the passband column
header.upperlimit.col = "is_real" # The name of the upperlimit column
```
In addition to specifying the unit of a parameter, you can also specify `header.parameter.unit_col` to give the column name containing the unit of that parameter.

#### Column Index
Instead of `header.parameter.col` being the name of the column, you can provide the index of the column. This can be mixed and matched with the column name method to allow you to load in a large number of different syntaxes.

#### Filter details
Your choice of `facility`, `instrument`, and `passband` is very important. `Supernovae.jl` will search `filter_path` for a transmission curve file with name `facility__instrument__passband`. If you have the passband for all your observations, make sure to put them in `filter_path`! If you don't, check if they're available on the [SVO Filter Profile Service](http://svo2.cab.inta-csic.es/theory/fps/). If so, make sure `facility`, `instrument`, and `passband` match the SVO FPS syntax as `Supernovae.jl` will attempt to download the transmission curve and save it to `filter_path`.

Transission curve files should be comma seperated files containing the wavelength (in angstroms), and the transmission at that wavelength. Check the Examples directory to see what to expect.

### `[ plot ]`
The `plot` key is optional, with `Supernovae.jl` only producing plots if this key exists. At the moment only lightcurve plots are implemented, but in the future there will be filter, and spectra plots.

#### `[[ plot.lightcurve ]]`
The lightcurve plot has a number of keys used to customise your plot. You can make any number of lightcurve plots by defining multiple `[[ plot.lightcurve ]]` keys.
```toml
[ plot.lightcurve ]]
path::String="$(supernova.name)_lightcurve.svg" # Where to save the plot, relative to output_path
datatype::String="flux" # What type of data to plot. Options include "flux", "magnitude", and "abs_magnitude".
unit.time::String="d" # Time unit
unit.data::String=["μJy", "AB_mag"] # Depending on the type of data, this will default to either μJy or AB_mag.
name::Union{Vector{String},Nothing}=nothing # What observations to include, based on their human readable name. If nothing, all observations are included.
filters::Union{Vector{String},Nothing}=nothing # What passbands to include. If nothing, all passbands are included.
rename.[passband, obs_name]::String=new_name # Optionally rename passband or obs_name to new_name. Useful if you don't want to use the SVO name, or want to add additional detail.
offset.[passband, obs_name]::Float64=0 # Optionally include an offset to the given passband or obs_name. If an observation has both passband and obs_name, it will be offset twice!
markersize::Int64=11 # Set the marker size.
marker.obs_name::String="nothing" # Set the marker type for observations with name obs_name. If "nothing", default marker is used.
colour.passband::Union{String,Nothing}=nothing # Set the colour for passband. If nothing, default colours are used.
legend::Bool=true # Whether to include a legend in the plot.
```
