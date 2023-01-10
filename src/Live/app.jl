# ---------------------------------------------------------------------------- #
#                                      APP                                     #
# ---------------------------------------------------------------------------- #

# ------------------------------- CONSTRUCTORS ------------------------------- #
"""
An `App` is a collection of widgets.

!!! tip
    Transition rules bind keys to "movement" in the app to change
    focus to a different widget
"""
@with_repr mutable struct App <: AbstractWidgetContainer
    internals::LiveInternals
    measure::Measure
    controls::AbstractDict
    parent::Union{Nothing, AbstractWidget}
    compositor::Compositor
    widgets::AbstractDict{Symbol,AbstractWidget}
    transition_rules::AbstractDict{Tuple{Symbol,KeyInput},Symbol}
    active::Symbol
    on_draw::Union{Nothing,Function}
end

function execute_transition_rule(app::App, key)
    haskey(app.transition_rules, (app.active, key)) || return
    app.active = app.transition_rules[(app.active, key)]
end



app_controls = Dict(
    'q' => quit,
    Esc() => quit,
    'h' => toggle_help,
    'w' => active_widget_help,
    :setactive => execute_transition_rule
)

function App(
    layout::Expr,
    widgets::AbstractDict,
    transition_rules::Union{Nothing,AbstractDict{Tuple{Symbol,KeyInput},Symbol}} = nothing;
    controls::AbstractDict = app_controls, 
    on_draw::Union{Nothing,Function} = nothing,
)

    # parse the layout expression and get the compositor
    compositor = Compositor(layout)
    measure = render(compositor).measure

    # check that the layout and the widgets match
    layout_keys = compositor.elements |> keys |> collect
    widgets_keys = widgets |> keys |> collect
    @assert issetequal(layout_keys, widgets_keys) "Mismatch between widget names and layout names"

    # check that the widgets have the right size
    for k in layout_keys
        elem, widget = compositor.elements[k], widgets[k]
        @assert widget.measure.w <= elem.w "Widget $(k) has width $(widget.measure.w) but should have $(elem.w) to fit in layout"
        @assert widget.measure.h <= elem.h - 1 "Widget $(k) has height $(widget.measure.h) but should have $(elem.h-1) to fit in layout"

        widget.measure.w < elem.w &&
            @warn "Widget $(k) has width $(widget.measure.w) but should have $(elem.w) to fit in layout"
        widget.measure.h < elem.h - 1 &&
            @warn "Widget $(k) has height $(widget.measure.h) but should have $(elem.h-1) to fit in layout"
    end

    transition_rules =
        isnothing(transition_rules) ? Dict{Tuple{Symbol,KeyInput},Symbol}() :
        transition_rules

    # make an error message to show transition rules
    color = TERM_THEME[].emphasis_light
    transition_rules_message = []
    for ((at, key), v) in pairs(transition_rules)
        push!(
            transition_rules_message,
            "{$color}$key {/$color} moves from {$(color)}$at {/$color} to {$color}$v {/$color}",
        )
    end

    msg_style = TERM_THEME[].emphasis
    app = App(
        LiveInternals(;
            help_message = "\n{$msg_style}Transition rules{/$msg_style}" /
                           join(transition_rules_message, "\n"),
        ),
        measure,
        controls,
        nothing,
        compositor,
        widgets,
        transition_rules,
        widgets_keys[1],
        on_draw,
    )

    set_as_parent(app)
    return app
end

# ----------------------------------- frame ---------------------------------- #
function frame(app::App; kwargs...)
    isnothing(app.on_draw) || app.on_draw(app)

    for (name, widget) in pairs(app.widgets)
        content = frame(widget)
        content = app.active == name ? hLine(content.measure.w) / content : "" / content
        update!(app.compositor, name, content)
    end
    return render(app.compositor)
end
