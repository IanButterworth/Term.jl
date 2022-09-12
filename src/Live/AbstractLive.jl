
abstract type AbstractLiveDisplay end


# ---------------------------------------------------------------------------- #
#                                LIVE INTERNALS                                #
# ---------------------------------------------------------------------------- #
mutable struct LiveInternals
    iob::IOBuffer
    ioc::IOContext
    term::AbstractTerminal
    prevcontent::Union{Nothing, AbstractRenderable}
    raw_mode_enabled::Bool
    last_update::Union{Nothing, Int}

    function LiveInternals()
        # get output buffers
        iob = IOBuffer()
        ioc = IOContext(iob, :displaysize=>displaysize(stdout))

        # prepare terminal 
        raw_mode_enabled = try
            raw!(terminal, true)
            true
        catch err
            @warn "Unable to enter raw mode: " exception=(err, catch_backtrace())
            false
        end
        # hide the cursor
        raw_mode_enabled && print(terminal.out_stream, "\x1b[?25l")

        return new(iob, ioc,  terminal, nothing, raw_mode_enabled, nothing)
    end
end


# ---------------------------------------------------------------------------- #
#                                METHODS ON LIVE                               #
# ---------------------------------------------------------------------------- #
"""
Get the current conttent of a live display
"""
frame(::AbstractLiveDisplay) = error("Not implemented")

key_press(live::AbstractLiveDisplay, inpt) = nothing


function shouldupdate(live::AbstractLiveDisplay)::Bool
    currtime = Dates.value(now())
    isnothing(live.internals.last_update) && begin
        live.internals.last_update = currtime
        return true
    end
    
    Δt = currtime - live.internals.last_update
    if Δt > 100
        live.internals.last_update = currtime
        return true
    end
    return false
end

function update!(live::AbstractLiveDisplay)::Bool
    # check for keyboard inputs
    shouldstop = keyboard_input(live)
    shouldstop && return false

    # check if its time to update
    shouldupdate(live) || return true

    # get new content
    content::AbstractRenderable = frame(live)

    # render
    internals = live.internals
    !isnothing(internals.prevcontent) && begin
        nlines = internals.prevcontent.measure.h + 1
        newlines = split(string(content), "\n")
        nnew = length(newlines)

        up(internals.ioc, nlines)
        if nlines > nnew
            for _ in 1:(nlines - nnew)
                erase_line(internals.ioc)
                down(internals.ioc)
            end
        end
        for i in 1:nnew
            erase_line(internals.ioc)
            println(internals.ioc, newlines[i])
        end
    end

    # output
    internals.prevcontent = content
    output = take!(internals.iob)
    write(stdout, output)
    return true
end


function stop!(live::AbstractLiveDisplay)
    print(live.internals.term.out_stream, "\x1b[?25h") # unhide cursor
    raw!(live.internals.term, false)
    nothing
end
