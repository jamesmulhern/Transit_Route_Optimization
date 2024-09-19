module OptLogging

using Logging
using JSON
import MHLib: Log.IterLevel as IterLevel

export CustomLogger

#
# Setup Custom Logger
#
struct CustomLogger <: AbstractLogger
    io::IO
end

CustomLogger(file::String) = CustomLogger(open(file,"w"))

#
# Required Logging Methods
#

function Logging.min_enabled_level(logger::CustomLogger)
    return Logging.BelowMinLevel
end

function Logging.shouldlog(logger::CustomLogger, level, _module, group, id) 
    return level == IterLevel ? true : false
 end

Logging.catch_exceptions(logger::CustomLogger) = false

const log_params = [:iter, :prev_ovj, :best_obj, :cur_obj, :time, :method, :info]
function Logging.handle_message(logger::CustomLogger,
    lvl, msg, _mod, group, id, file, line;
    kwargs...)

    if position(logger.io) == 0
        print(logger.io,"[\n")
    else
        skip(logger.io,-2)
        print(logger.io, ",\n")
    end

    save_d = Dict()
    for (k,v) in kwargs
        if k in log_params
            save_d[k] = v
        elseif k == :cur_sol
            save_d[k] = v.x
        end
    end

    #print(logger.io, json(kwargs), "\n]")
    print(logger.io, json(save_d), "\n]")
    flush(logger.io)
end

end