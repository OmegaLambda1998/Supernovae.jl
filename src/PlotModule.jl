# Plot Module
module PlotModule

# Internal Packages 
using ..SupernovaModule

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
function plot_lightcurve!(fig::Figure, ax::Axis, supernova::Supernova, plot_config::Dict)
    time = Dict()
    data_type = get(plot_config, "DATA_TYPE", "flux")
    @debug "Plotting data type set to $data_type"
    data = Dict()
    data_err = Dict()
    marker_plots = Dict()
    markers = Dict()
    colour_plots = Dict()
    colours = Dict()
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
    rename = get(plot_config, "RENAME", Dict())
    filters = get(plot_config, "FILTERS", nothing)
    markersize = get(plot_config, "MARKERSIZE", 11)
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
        if !(obs.name in keys(markers))
            marker = Meta.parse(get(get(plot_config, "MARKER", Dict()), uppercase(obs.name), "nothing"))
            if marker == :nothing
                marker = marker_labels[length(marker_plots)+1]
            end
            elem = MarkerElement(color=:black, marker=marker, markersize=markersize)
            marker_plots[obs.name] = elem
            markers[obs.name] = marker
        end
        if !(obs.filter.passband in keys(colours))
            colour = get(get(plot_config, "COLOUR", Dict()), uppercase(obs.filter.passband), nothing)
            if isnothing(colour)
                colour = colour_labels[length(colour_plots)+1]
            end
            elem = MarkerElement(marker=:circle, color=colour, markersize=markersize)
            colour_plots[passband] = elem
            colours[obs.filter.passband] = colour
        end
        push!(get!(time, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(time_unit, obs.time)))
        if data_type == "flux"
            push!(get!(data, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.flux)))
            push!(get!(data_err, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.flux_err)))
        elseif data_type == "magnitude"
            push!(get!(data, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.magnitude)))
            push!(get!(data_err, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.magnitude_err)))
        elseif data_type == "abs_magnitude"
            push!(get!(data, (obs.name, obs.filter.passband), Float64[]), ustrip(uconvert(data_unit, obs.abs_magnitude)))
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
        marker = Meta.parse(get(get(plot_config, "MARKER", Dict()), key[1], "nothing"))
        if marker == :nothing
            marker = markers[key[1]]
        end
        colour = get(get(plot_config, "COLOUR", Dict()), key[2], nothing)
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
