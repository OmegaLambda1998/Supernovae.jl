# Plotting functions
function plot!(fig, ax, supernova::Supernova, plot_config::Dict)
    instruments = String[]
    filters = String[]
    time = Dict()
    flux = Dict()
    flux_err = Dict()
    legend_plots = MarkerElement[]
    legend_names = String[]
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    flux_unit = uparse(get(units, "flux", "μJy"))
    names = get(plot_config, "names", nothing)
    for obs in supernova.lightcurve
        if !isnothing(names)
            if !(obs.name in names)
                continue
            end
        end
        if !(obs.name in instruments)
            elem = MarkerElement(color = :black, marker = Meta.parse(plot_config["marker"][obs.name]))
            push!(legend_plots, elem)
            push!(legend_names, obs.name)
        end
        if !(obs.filter.name in filters)
            elem = MarkerElement(color = plot_config["color"][obs.filter.name], marker = :circle)
            push!(legend_plots, elem)
            push!(legend_names, obs.filter.name)
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
    for (i, time_key) in enumerate(collect(keys(time)))
        flux_key = collect(keys(flux))[i]
        flux_err_key = collect(keys(flux_err))[i]
        scatter!(ax, time[time_key], flux[flux_key], color = plot_config["color"][time_key[2]], marker = Meta.parse(plot_config["marker"][time_key[1]]))
        errorbars!(ax, time[time_key], flux[flux_key], flux_err[flux_err_key], color = plot_config["color"][time_key[2]], marker = Meta.parse(plot_config["marker"][time_key[1]]))
    end
    Legend(fig[1, 2], legend_plots, legend_names)
    return fig, ax
end

function plot(supernova::Supernova, plot_config::Dict)
    fig = Figure()
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    flux_unit = uparse(get(units, "flux", "μJy"))
    ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Flux [$flux_unit]", title = supernova.name)
    fig, ax = plot!(fig, ax, supernova, plot_config)
    return fig, ax
end

function plot(supernova::Supernova, plot_config::Dict, path::AbstractString)
    fig, ax = plot(supernova, plot_config)
    save(path, fig)
end


