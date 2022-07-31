module Plotting

# External Packages
using CairoMakie
CairoMakie.activate!(type = "svg")
using Unitful, UnitfulAstro
# Internal Packages
using ..Data
using Random
Random.seed!(0)

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

# Colours
colour_labels = shuffle(["salmon", "coral", "tomato", "firebrick", "crimson", "red", "orange", "green", "forestgreen", "seagreen", "olive", "lime", "charteuse", "teal", "turquoise", "cyan", "navyblue", "midnightblue", "indigo", "royalblue", "slateblue", "steelblue", "blue", "purple", "orchid", "magenta", "maroon", "hotpink", "deeppink", "saddlebrown", "brown", "peru", "tan"])

# Plotting functions
function plot_lightcurve!(fig, ax, supernova::Supernova, plot_config::Dict)
    time = Dict()
    data_type = get(plot_config, "data_type", "flux")
    @debug "Plotting data type set to $data_type"
    data = Dict()
    data_err = Dict()
    marker_plots = Dict()
    markers = Dict()
    colour_plots = Dict() 
    colours = Dict()
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"), unit_context = [Unitful, UnitfulAstro])
    if data_type == "flux"
        data_unit = uparse(get(units, "data", "µJy"), unit_context = [Unitful, UnitfulAstro])
    elseif data_type == "magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"), unit_context = [Unitful, UnitfulAstro])
    elseif data_type == "abs_magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"), unit_context = [Unitful, UnitfulAstro])
    else
        error("Unknown data type: $data_type. Possible options are [flux, magnitude, abs_magnitude]")
    end
    @debug "Plotting data unit set to $data_unit"
    names = get(plot_config, "names", nothing)
    rename = get(plot_config, "rename", Dict())
    @debug "Generating all plot vectors"
    for obs in supernova.lightcurve.observations
        if !isnothing(names)
            if !(obs.name in names)
                continue
            end
        end
        filter_name = get(rename, obs.filter.name, obs.filter.name)
        if !(obs.name in keys(markers))
            marker = Meta.parse(get(get(plot_config, "marker", Dict()), obs.name, "nothing"))
            if marker == :nothing
                marker = markers_labels[length(marker_plots) + 1]
            end
            elem = MarkerElement(color = :black, marker = marker, markersize = 21)
            marker_plots[obs.name] = elem
            markers[obs.name] = marker
        end
        if !(obs.filter.name in keys(colours))
            colour = get(get(plot_config, "colour", Dict()), obs.filter.name, nothing)
            if isnothing(colour)
                colour = colour_labels[length(colour_plots) + 1]
            end
            elem = MarkerElement(marker = :circle, color = colour, markersize = 21) 
            colour_plots[filter_name] = elem
            colours[obs.filter.name] = colour
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
        marker = Meta.parse(get(get(plot_config, "marker", Dict()), key[1], "nothing"))
        if marker == :nothing
            marker = markers[key[1]]
        end
        colour = get(get(plot_config, "colour", Dict()), key[2], nothing)
        if isnothing(colour)
            colour = colours[key[2]]
        end
        scatter!(ax, time[key], data[key], color = colour, marker = marker, marker_size = 21)
        errorbars!(ax, time[key], data[key], data_err[key], color = colour, marker = marker, marker_size=21) 
    end
    if get(plot_config, "legend", true)
        Legend(fig[1, 2], legend_plots, legend_names)
    end
    return colours, markers
end

function plot_lightcurve(supernova::Supernova, plot_config::Dict)
    fig = Figure()
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"), unit_context = [Unitful, UnitfulAstro])
    data_type = get(plot_config, "data_type", "flux")
    if data_type == "flux"
        data_unit = uparse(get(units, "data", "µJy"), unit_context = [Unitful, UnitfulAstro])
        ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Flux [$data_unit]", title = supernova.name)
    elseif data_type == "magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"), unit_context = [Unitful, UnitfulAstro])
        ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Magnitude [$data_unit]", title = supernova.name)
        ax.yreversed = true
    elseif data_type == "abs_magnitude"
        data_unit = uparse(get(units, "data", "AB_mag"), unit_context = [Unitful, UnitfulAstro])
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
