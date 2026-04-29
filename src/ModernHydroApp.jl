module ModernHydroApp

using ModernHydroModels
using YAML

function julia_main()::Cint
    cfg_path = length(ARGS) > 0 ? ARGS[1] : "config.yaml"
    if !isfile(cfg_path)
        println(stderr, "ERROR: Config file not found: $cfg_path")
        println(stderr, "Usage: forecast <config.yaml>")
        return 1
    end
    cfg = YAML.load_file(cfg_path)
    run_forecast(cfg)
    return 0
end

end # module
