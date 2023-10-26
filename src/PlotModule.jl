# Plot Module
module PlotModule

# Internal Packages 
using ..SupernovaModule
using ..FilterModule

# External Packages 
using Random
Random.seed!(0)
using CairoMakie
CairoMakie.activate!(type="svg")
using Unitful, UnitfulAstro
const UNITS = [Unitful, UnitfulAstro]

# Exports
export plot_lightcurve, plot_lightcurve!

const marker_labels = shuffle([:rect, :star5, :diamond, :hexagon, :cross, :xcross, :utriangle, :dtriangle, :ltriangle, :rtriangle, :pentagon, :star4, :star8, :vline, :hline, :x, :+, :circle])

const colour_labels = shuffle(["salmon", "coral", "tomato", "firebrick", "crimson", "red", "orange", "green", "forestgreen", "seagreen", "olive", "lime", "charteuse", "teal", "turquoise", "cyan", "navyblue", "midnightblue", "indigo", "royalblue", "slateblue", "steelblue", "blue", "purple", "orchid", "magenta", "maroon", "hotpink", "deeppink", "saddlebrown", "brown", "peru", "tan"])


# Plotting functions
"""
    plot_lightcurve!(fig::Figure, ax::Axis, supernova::Supernova, plot_config::Dict{String, Any})

Add lightcurve plot to axis. plot_config contains plotting options.

DATA_TYPE = ["flux", "magnitude", "abs_magnitude"]: The type of data to plot
UNITS::Dict: Units for time, and flux, magnitude, or abs_magnitude
NAMES::Vector: List of [`SupernovaModule.Observation`](@ref).name's to include in the plot. If `nothing`, all observations are included
RENAME::Dict: Convert [`FilterModule.Filter`](@ref).passband to new name
FILTERS::Vector: List of [`FilterModule.Filter`](@ref).passband's to include
MARKERSIZE::Int: Size of the markers
MARKER::Dict: Marker to use for each [`SupernovaModule.Observation`](@ref).name. If a passband is missing, a default marker is used
COLOUR::Dict: Marker to use for each [`FilterModule.Filter`](@ref).passband. If a passband is missing, a default marker is used
LEGEND::Bool: Whether to include a legend

# Arguments
- `fig::Figure`: Figure to plot to
- `ax::Axis`: Axis to plot to
- `supernova::Supernova`: Supernova to plot
- `plot_config::Dict{String, Any}`: Details of the plot
"""
function plot_lightcurve!(fig::Figure, ax::Axis, supernova::Supernova, plot_config::Dict{String, Any})
    time = Dict{Tuple{String, String}, Vector{Float64}}()
    data_type = get(plot_config, "DATATYPE", "flux")
    @debug "Plotting data type set to $data_type"
    data = Dict{Tuple{String, String}, Vector{Float64}}()
    data_err = Dict{Tuple{String, String}, Vector{Float64}}()
    marker_plots = Dict{String,MarkerElement}()
    markers = Dict{String,Symbol}()
    colour_plots = Dict{String,MarkerElement}()
    colours = Dict{String,String}()
    units = get(plot_config, "UNIT", Dict{String,Any}())
    time_unit = uparse(get(units, "TIME", "d"), unit_context=UNITS)
    if data_type == "flux"
        data_unit = uparse(get(units, "DATA", "µJy"), unit_context=UNITS)
    elseif data_type == "magnitude"
        data_unit = uparse(get(units, "DATA", "AB_mag"), unit_context=UNITS)
    elseif data_type == "abs_magnitude"
        data_unit = uparse(get(units, "DATA", "AB_mag"), unit_context=UNITS)
    else
        error("Unknown data type: $data_type. Possible options are [flux, magnitude, abs_magnitude]")
    end
    @debug "Plotting data unit set to $data_unit"
    names = get(plot_config, "NAME", nothing)
    rename = get(plot_config, "RENAME", Dict{String, Any}())
    filters = get(plot_config, "FILTERS", nothing)
    markersize = get(plot_config, "MARKERSIZE", 11)
    offsets = get(plot_config, "OFFSET", Dict{String, Any}())
    @debug "Generating all plot vectors"
    for obs in supernova.lightcurve.observations
        if !isnothing(names)
            if !(obs.name in names)
                continue
            end
        end
        if !isnothing(filters)
            if !(obs.filter.passband in filters)
                continue
            end
        end
        passband = get(rename, uppercase(obs.filter.passband), obs.filter.passband)
        obs_name = get(rename, uppercase(obs.name), obs.name)
        passband_offset = get(offsets, uppercase(obs.filter.passband), 0)
        obs_name_offset = get(offsets, uppercase(obs.name), 0)
        if !(obs.name in keys(markers))
            marker = Meta.parse(get(get(plot_config, "MARKER", Dict{String, Any}()), uppercase(obs.name), "nothing"))
            if marker == :nothing
                marker = marker_labels[length(marker_plots)+1]
            end
            elem = MarkerElement(color=:black, marker=marker, markersize=markersize)
            marker_plots[obs_name] = elem
            markers[obs.name] = marker
        end
        if !(obs.filter.passband in keys(colours))
            colour = get(get(plot_config, "COLOUR", Dict{String, Any}()), uppercase(obs.filter.passband), nothing)
            if isnothing(colour)
                colour = colour_labels[length(colour_plots)+1]
            end
            elem = MarkerElement(marker=:circle, color=colour, markersize=0.5 * markersize)
            colour_plots[passband] = elem
            colours[obs.filter.passband] = colour
        end
        push!(get!(time, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(time_unit, obs.time)))
        if data_type == "flux"
            push!(get!(data, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.flux)) + passband_offset + obs_name_offset)
            push!(get!(data_err, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.flux_err)))
        elseif data_type == "magnitude"
            push!(get!(data, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.magnitude)) + passband_offset + obs_name_offset)
            push!(get!(data_err, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.magnitude_err)))
        elseif data_type == "abs_magnitude"
            push!(get!(data, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.abs_magnitude)) + passband_offset + obs_name_offset)
            push!(get!(data_err, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.abs_magnitude_err)))
        else
            error("Unknown data type: $data_type. Possible options are [flux, magnitude, abs_magnitude]")
        end
    end
    legend_plots = MarkerElement[]
    legend_names = String[]
    for k in sort(collect(keys(marker_plots)))
        push!(legend_names, k)
        push!(legend_plots, marker_plots[k])
    end
    for k in sort(collect(keys(colour_plots)))
        push!(legend_names, k)
        push!(legend_plots, colour_plots[k])
    end
    @debug "Plotting"
    for (i, key) in enumerate(collect(keys(time)))
        marker = Meta.parse(get(get(plot_config, "MARKER", Dict{String, Any}()), key[1], "nothing"))
        if marker == :nothing
            marker = markers[key[1]]
        end
        colour = get(get(plot_config, "COLOUR", Dict{String, Any}()), key[2], nothing)
        if isnothing(colour)
            colour = colours[key[2]]
        end
        sc = scatter!(ax, time[key], data[key], color=colour, marker=marker)
        sc.markersize = markersize
        errorbars!(ax, time[key], data[key], data_err[key], color=colour)
    end
    if get(plot_config, "LEGEND", true)
        Legend(fig[1, 2], legend_plots, legend_names)
    end
    return colours, markers, legend_plots, legend_names
end

"""
    plot_lightcurve(supernova::Supernova, plot_config::Dict{String,Any}, config::Dict{String,Any})

Set up Figure and Axis, then plot lightcurve using [`plot_lightcurve!`](@ref)

# Arguments
- `supernova::Supernova`: The supernova to plot
- `plot_config::Dict{String, Any}`: Plot options passed to plot_lightcurve!
- `config::Dict{String, Any}`: Global options including where to save the plot
"""
function plot_lightcurve(supernova::Supernova, plot_config::Dict{String,Any}, config::Dict{String,Any})
    fig = Figure()
    units = get(plot_config, "UNIT", Dict{String,Any}())
    time_unit = uparse(get(units, "TIME", "d"), unit_context=UNITS)
    data_type = get(plot_config, "DATATYPE", "flux")
    if data_type == "flux"
        data_unit = uparse(get(units, "DATA", "µJy"), unit_context=UNITS)
        ax = Axis(fig[1, 1], xlabel="Time [$time_unit]", ylabel="Flux [$data_unit]", title=supernova.name)
    elseif data_type == "magnitude"
        data_unit = uparse(get(units, "DATA", "AB_mag"), unit_context=UNITS)
        ax = Axis(fig[1, 1], xlabel="Time [$time_unit]", ylabel="Magnitude [$data_unit]", title=supernova.name)
        ax.yreversed = true
    elseif data_type == "abs_magnitude"
        data_unit = uparse(get(units, "DATA", "AB_mag"), unit_context=UNITS)
        ax = Axis(fig[1, 1], xlabel="Time [$time_unit]", ylabel="Absolute Magnitude [$data_unit]", title=supernova.name)
        ax.yreversed = true
    else
        error("Unknown data type: $data_type. Possible options are [flux, magnitude, abs_magnitude]")
    end
    plot_lightcurve!(fig, ax, supernova, plot_config)
    path = get(plot_config, "PATH", "$(supernova.name)_lightcurve.svg")
    if !isabspath(path)
        path = joinpath(config["OUTPUT_PATH"], path)
    end
    path = abspath(path)
    save(path, fig)
    return fig, ax
end

end
