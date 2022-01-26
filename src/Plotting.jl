module Plotting

# External Packages
using CairoMakie
CairoMakie.activate!(type = "svg")
using Unitful, UnitfulAstro

# Internal Packages
using ..Data

# Exports
export plot_lightcurve, plot_lightcurve!

# Plotting functions
function plot_lightcurve!(fig, ax, supernova::Supernova, plot_config::Dict)
    instruments = String[]
    filters = String[]
    time = Dict()
    flux = Dict()
    flux_err = Dict()
    marker_plots = MarkerElement[]
    marker_names = String[]
    colour_plots = MarkerElement[]
    colour_names = String[]
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    flux_unit = uparse(get(units, "flux", "μJy"))
    names = get(plot_config, "names", nothing)
    @debug "Generating all plot vectors"
    for obs in supernova.lightcurve.observations
        if !isnothing(names)
            if !(obs.name in names)
                continue
            end
        end
        if !(obs.name in instruments)
            elem = MarkerElement(color = :black, marker = Meta.parse(plot_config["marker"][obs.name]))
            push!(marker_plots, elem)
            push!(marker_names, obs.name)
        end
        if !(obs.filter.name in filters)
            elem = MarkerElement(color = plot_config["colour"][obs.filter.name], marker = :circle)
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
        push!(get!(flux, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(flux_unit, obs.flux)))
        push!(get!(flux_err, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(flux_unit, obs.flux_err)))
    end
    legend_plots = MarkerElement[marker_plots; colour_plots]
    legend_names = String[marker_names; colour_names]
    @debug "Plotting"
    for (i, time_key) in enumerate(collect(keys(time)))
        flux_key = collect(keys(flux))[i]
        flux_err_key = collect(keys(flux_err))[i]
        scatter!(ax, time[time_key], flux[flux_key], color = plot_config["colour"][time_key[2]], marker = Meta.parse(plot_config["marker"][time_key[1]]))
        errorbars!(ax, time[time_key], flux[flux_key], flux_err[flux_err_key], color = plot_config["colour"][time_key[2]], marker = Meta.parse(plot_config["marker"][time_key[1]]))
    end
    Legend(fig[1, 2], legend_plots, legend_names)
end

function plot_lightcurve(supernova::Supernova, plot_config::Dict)
    fig = Figure()
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    flux_unit = uparse(get(units, "flux", "μJy"))
    ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Flux [$flux_unit]", title = supernova.name)
    plot_lightcurve!(fig, ax, supernova, plot_config)
    path = get(plot_config, "path", nothing)
    if !isnothing(path)
        save(path, fig)
    end
    return fig, ax
end

end
