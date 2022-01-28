module Plotting

# External Packages
using CairoMakie
CairoMakie.activate!(type = "svg")
using Unitful, UnitfulAstro
using Colors
using Random
Random.seed!(0)

# Internal Packages
using ..Data

# Exports
export plot_lightcurve, plot_lightcurve!

# Markers
markers_labels = shuffle([
    :rect,
    :star5,
    :diamond,
    :hexagon,
    :cross,
    :xcross,
    :utriangle,
    :dtriangle,
    :ltriangle,
    :rtriangle,
    :pentagon,
    :star4,
    :star8,
    :vline,
    :hline,
    :x,
    :+,
    :circle
])

colour_labels = shuffle(collect(keys(Colors.color_names)))

# Plotting functions
function plot_lightcurve!(fig, ax, supernova::Supernova, plot_config::Dict)
    instruments = String[]
    filters = String[]
    time = Dict()
    data_type = get(plot_config, "data_type", "flux")
    @debug "Plotting data type set to $data_type"
    data = Dict()
    data_err = Dict()
    marker_plots = MarkerElement[]
    marker_names = String[]
    colour_plots = MarkerElement[]
    colour_names = String[]
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    if data_type == "flux"
        data_unit = uparse(get(units, "data", "µJy"))
    elseif data_type == "magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"))
    elseif data_type == "abs_magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"))
    else
        error("Unknown data type: $data_type. Possible options are [flux, magnitude, abs_magnitude]")
    end
    @debug "Plotting data unit set to $data_unit"
    names = get(plot_config, "names", nothing)
    @debug "Generating all plot vectors"
    for obs in supernova.lightcurve.observations
        if !isnothing(names)
            if !(obs.name in names)
                continue
            end
        end
        if !(obs.name in instruments)
            marker = Meta.parse(get(get(plot_config, "marker", Dict()), obs.name, "nothing"))
            if marker == :nothing
                marker = markers_labels[length(marker_plots) + 1]
            end
            elem = MarkerElement(color = :black, marker = marker)
            push!(marker_plots, elem)
            push!(marker_names, obs.name)
        end
        if !(obs.filter.name in filters)
            color = get(get(plot_config, "colour", Dict()), obs.filter.name, nothing)
            if isnothing(color)
                color = colour_labels[length(colour_plots) + 1]
            end
            elem = MarkerElement(marker = :circle, color = color) 
            push!(colour_plots, elem)
            push!(colour_names, obs.filter.name)
        end
        if !(obs.name in instruments)
            push!(instruments, obs.name)
        end
        if !(obs.filter.name in filters)
            push!(filters, obs.filter.name)
        end
        push!(get!(time, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(time_unit, obs.time)))
        if data_type == "flux"
            push!(get!(data, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(data_unit, obs.flux)))
            push!(get!(data_err, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(data_unit, obs.flux_err)))
        elseif data_type == "magnitude"
            push!(get!(data, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(data_unit, obs.magnitude)))
            push!(get!(data_err, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(data_unit, obs.magnitude_err)))
        elseif data_type == "abs_magnitude"
            push!(get!(data, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(data_unit, obs.abs_magnitude)))
            push!(get!(data_err, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(data_unit, obs.abs_magnitude_err)))
        else
            error("Unknown data type: $data_type. Possible options are [flux, magnitude, abs_magnitude]")
        end
    end
    legend_plots = MarkerElement[marker_plots; colour_plots]
    legend_names = String[marker_names; colour_names]
    @debug "Plotting"
    for (i, time_key) in enumerate(collect(keys(time)))
        data_key = collect(keys(data))[i]
        data_err_key = collect(keys(data_err))[i]
        marker = Meta.parse(get(get(plot_config, "marker", Dict()), time_key[1], "nothing"))
        if marker == :nothing
            marker = markers_labels[i]
        end
        color = get(get(plot_config, "colour", Dict()), time_key[2], nothing)
        if isnothing(color)
            color = colour_labels[i]
        end
        scatter!(ax, time[time_key], data[data_key], color = color, marker = marker)
        errorbars!(ax, time[time_key], data[data_key], data_err[data_err_key], color = color, marker = marker) 
    end
    Legend(fig[1, 2], legend_plots, legend_names)
end

function plot_lightcurve(supernova::Supernova, plot_config::Dict)
    fig = Figure()
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    data_type = get(plot_config, "data_type", "flux")
    if data_type == "flux"
        data_unit = uparse(get(units, "data", "µJy"))
        ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Flux [$data_unit]", title = supernova.name)
    elseif data_type == "magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"))
        ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Magnitude [$data_unit]", title = supernova.name)
        ax.yreversed = true
    elseif data_type == "abs_magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"))
        ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Absolute Magnitude [$data_unit]", title = supernova.name)
        ax.yreversed = true
    else
        error("Unknown data type: $data_type. Possible options are [flux, magnitude, abs_magnitude]")
    end
    plot_lightcurve!(fig, ax, supernova, plot_config)
    path = get(plot_config, "path", nothing)
    if !isnothing(path)
        save(path, fig)
    end
    return fig, ax
end

end
