_lfos = require "lfo"
s = require "sequins"
MusicUtil = require("musicutil")
tabutil = require "tabutil"
g = grid.connect()

dest = {"192.168.1.50", 57120}

previous_note = 0
grid_param_resolution = 12

custom_scales = {{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                 {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                 {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                 {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}}

state_index = 1
states = {}
scale_custom = {}

scale_names = {}
for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, MusicUtil.SCALES[i].name)
end

custom_scale_option = {"off", 1, 2, 3, 4, 5, 6, 7, 8}

function init()
    sync_vals = s {1, 1 / 3, 1 / 2, 1 / 6, 2}
    clock.run(iter)

    init_params()
    params:bang()

    for i = 1, 8 do
        table.insert(states, {
            note_lfo_speed = params:get("note_lfo_speed"),
            note_lfo_depth = params:get("note_lfo_depth"),
            note_lfo_min = params:get("note_lfo_min"),
            note_lfo_max = params:get("note_lfo_max"),
            note_lfo_shape = params:get("note_lfo_shape"),
            vel_lfo_speed = params:get("vel_lfo_speed"),
            vel_lfo_depth = params:get("vel_lfo_depth"),
            vel_lfo_min = params:get("vel_lfo_min"),
            vel_lfo_max = params:get("vel_lfo_max"),
            vel_lfo_shape = params:get("vel_lfo_shape"),
            custom_scale = {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
        })
    end

    params:add_number("state", "state", 1, 8, 1)
    params:set_action("state", function(x)
        save_state(state_index)
        state_index = x
        change_state(state_index)
    end)

    grid_dirty = true -- initialize with a redraw
    clock.run(grid_redraw_clock) -- start the grid redraw clock

    -- local folder_path = norns.state.data .. "custom_scales.lua"
    -- test = {1}
    -- result = tabutil.save(test, folder_path)
    -- print(result)
    -- stored = tabutil.load(folder_path .. "custom_scales.lua")
    -- print(stored)

    -- test = {1, 2}
    -- path = norns.state.data .. "/test_tab.dat"
    -- result = tabutil.save(test, path)
    -- print(result)
    -- path = norns.state.data .. "/test_tab.dat"
    -- loaded_tab = tabutil.load(path)
    -- tabutil.print(loaded_tab)
    tabutil.print(states[params:get("state")].custom_scale)
end

function init_params()
    params:add{
        type = "option",
        id = "scale_global",
        name = "scale global",
        options = scale_names,
        default = 41,
        action = function(x)
            scale_global = MusicUtil.generate_scale(0, x, 10)
        end
    }

    -- params:add{
    --     type = "option",
    --     id = "scale_custom",
    --     name = "scale custom",
    --     options = custom_scale_option,
    --     default = 2,
    --     action = function()
    --         build_custom_scale()
    --     end
    -- }

    -- params:add_number("scale_custom", "scale custom", 1, 8, 1)
    -- params:set_action("scale_custom", function(x)
    --     build_custom_scale()
    -- end)

    -- note lfo
    note_lfo = _lfos:add{
        shape = "sine",
        min = 0,
        max = 127,
        depth = 1,
        mode = "free",
        period = 1,
        action = function(scaled, raw)
            -- local note = util.round(scaled)
            -- local note = MusicUtil.snap_note_to_array(note, scale_global)
            -- local note = MusicUtil.snap_note_to_array(note, scale_custom)
            -- if note ~= previous_note then
            --     send_osc()
            --     -- print(note)
            -- end
            -- previous_note = note
            send_osc()
        end
    }
    note_lfo:start()

    params:add{
        type = "option",
        id = "note_lfo_shape",
        name = "note lfo shape",
        options = {"sine", "saw", "square", "random"},
        default = 1,
        action = function()
            note_lfo:set("shape", params:string("note_lfo_shape"))
            grid_dirty = true
        end
    }

    note_lfo_speed = controlspec.def {
        min = 0.01, -- the minimum value
        max = 10.0, -- the maximum value
        warp = 'lin', -- a shaping option for the raw value
        step = 0.01, -- output value quantization
        default = 1.0, -- default value
        -- units = 'khz', -- displayed on PARAMS UI
        quantum = 0.01, -- each delta will change raw value by this much
        wrap = false -- wrap around on overflow (true) or clamp (false)
    }
    params:add_control("note_lfo_speed", "note lfo speed", note_lfo_speed)
    params:set_action("note_lfo_speed", function(x)
        note_lfo:set("period", x)
        grid_dirty = true
    end)

    note_lfo_depth = controlspec.def {
        min = 0.01, -- the minimum value
        max = 1.0, -- the maximum value
        warp = 'lin', -- a shaping option for the raw value
        step = 0.01, -- output value quantization
        default = 1.0, -- default value
        -- units = 'khz', -- displayed on PARAMS UI
        quantum = 0.01, -- each delta will change raw value by this much
        wrap = false -- wrap around on overflow (true) or clamp (false)
    }
    params:add_control("note_lfo_depth", "note lfo depth", note_lfo_depth)
    params:set_action("note_lfo_depth", function(x)
        note_lfo:set("depth", x)
        grid_dirty = true
    end)

    params:add_number("note_lfo_min", "note lfo min", 0, 127, 45)
    params:set_action("note_lfo_min", function(x)
        if x >= params:get("note_lfo_max") then
            params:set("note_lfo_max", params:get("note_lfo_min") + 1)
        end
        note_lfo:set("min", x)
        grid_dirty = true
    end)

    params:add_number("note_lfo_max", "note lfo max", 0, 127, 110)
    params:set_action("note_lfo_max", function(x)
        if x <= params:get("note_lfo_min") then
            params:set("note_lfo_min", params:get("note_lfo_max") - 1)
        end
        note_lfo:set("max", x)
        grid_dirty = true
    end)

    -- velocity lfo
    vel_lfo = _lfos:add{
        shape = "saw",
        min = 0,
        max = 127,
        depth = 1,
        mode = "free",
        period = 1,
        baseline = "center",
        action = function(scaled, raw)
        end
    }
    vel_lfo:start()

    params:add{
        type = "option",
        id = "vel_lfo_shape",
        name = "vel lfo shape",
        options = {"sine", "saw", "square", "random"},
        default = 1,
        action = function()
            vel_lfo:set("shape", params:string("vel_lfo_shape"))
            grid_dirty = true
        end
    }

    vel_lfo_speed = note_lfo_speed:copy()
    params:add_control("vel_lfo_speed", "vel lfo speed", vel_lfo_speed)
    params:set_action("vel_lfo_speed", function(x)
        vel_lfo:set("period", x)
        grid_dirty = true
    end)

    vel_lfo_depth = note_lfo_depth:copy()
    params:add_control("vel_lfo_depth", "vel lfo depth", vel_lfo_depth)
    params:set_action("vel_lfo_depth", function(x)
        vel_lfo:set("depth", x)
        grid_dirty = true
    end)

    params:add_number("vel_lfo_min", "vel lfo min", 0, 127, 0)
    params:set_action("vel_lfo_min", function(x)
        if x >= params:get("vel_lfo_max") then
            params:set("vel_lfo_max", params:get("vel_lfo_min") + 1)
        end
        vel_lfo:set("min", x)
        grid_dirty = true
    end)

    params:add_number("vel_lfo_max", "vel lfo max", 0, 127, 127)
    params:set_action("vel_lfo_max", function(x)
        if x <= params:get("vel_lfo_min") then
            params:set("vel_lfo_min", params:get("vel_lfo_max") - 1)
        end
        vel_lfo:set("max", x)
        grid_dirty = true
    end)
end

function change_state()
    local state = states[state_index]
    params:set("note_lfo_speed", state.note_lfo_speed)
    params:set("note_lfo_depth", state.note_lfo_depth)
    params:set("note_lfo_min", state.note_lfo_min)
    params:set("note_lfo_max", state.note_lfo_max)
    params:set("vel_lfo_speed", state.vel_lfo_speed)
    params:set("vel_lfo_depth", state.vel_lfo_depth)
    params:set("vel_lfo_min", state.vel_lfo_min)
    params:set("vel_lfo_max", state.vel_lfo_max)
    params:set("note_lfo_shape", state.note_lfo_shape)
    params:set("vel_lfo_shape", state.vel_lfo_shape)
    build_custom_scale()
end

function save_state(state_index)
    local state = states[state_index]
    state.note_lfo_speed = params:get("note_lfo_speed")
    state.note_lfo_depth = params:get("note_lfo_depth")
    state.note_lfo_min = params:get("note_lfo_min")
    state.note_lfo_max = params:get("note_lfo_max")
    state.vel_lfo_speed = params:get("vel_lfo_speed")
    state.vel_lfo_depth = params:get("vel_lfo_depth")
    state.vel_lfo_min = params:get("vel_lfo_min")
    state.vel_lfo_max = params:get("vel_lfo_max")
    state.note_lfo_shape = params:get("note_lfo_shape")
    state.vel_lfo_shape = params:get("vel_lfo_shape")
end

function update_custom_scale(custom_scale_index)
    if states[params:get("state")].custom_scale[custom_scale_index] == 1 then
        states[params:get("state")].custom_scale[custom_scale_index] = 0
    else
        states[params:get("state")].custom_scale[custom_scale_index] = 1
    end

    -- for i = 1, #custom_scales[params:get("scale_custom")] do
    --     print("pos #" .. i .. ": " .. custom_scales[params:get("scale_custom")][i])
    -- end

    build_custom_scale()
end

function build_custom_scale()
    local temp_scale = {}

    -- add logic for what happens if custom scale is off
    -- if params:string("scale_custom") == "off" then
    --     scale_custom = scale_global
    --     return
    -- end

    for i = 0, 12, 1 do
        if (states[state_index].custom_scale[i + 1] == 1) then
            for j = i, 127, 12 do
                table.insert(temp_scale, j)
            end
        end
    end

    table.sort(temp_scale)

    scale_custom = temp_scale
    -- for i = 1, #scale_custom do
    --     print(scale_custom[i])
    -- end
end

function iter()
    while true do
        clock.sync(sync_vals())
    end
end

function send_osc()
    if #scale_custom == 0 then
        -- when no notes are selected, don't send any note
        return
    end

    local note = util.round(note_lfo:get("scaled"))
    -- local note = util.wrap(note, params:get("note_lfo_min"), params:get("note_lfo_max"))
    local note = MusicUtil.snap_note_to_array(note, scale_global)
    local note = MusicUtil.snap_note_to_array(note, scale_custom)
    local vel = util.round(vel_lfo:get("scaled"))

    if note ~= previous_note then
        osc.send(dest, "/note", {note, vel})
        -- print("note: " .. note .. " vel: " .. vel)
    end
    previous_note = note
end

g.key = function(x, y, z)

    -- note lfo speed
    if x <= grid_param_resolution and y == 8 and z == 1 then
        local range = params:get_range("note_lfo_speed")
        params:set("note_lfo_speed", util.linlin(1, grid_param_resolution, range[2], range[1], x))
    end

    -- note lfo depth
    if x <= grid_param_resolution and y == 7 and z == 1 then
        local range = params:get_range("note_lfo_depth")
        params:set("note_lfo_depth", util.linlin(1, grid_param_resolution, range[2], range[1], x))
    end

    -- note lfo min
    if x <= grid_param_resolution and y == 6 and z == 1 then
        local range = params:get_range("note_lfo_min")
        params:set("note_lfo_min", util.round(util.linlin(1, grid_param_resolution, range[2], range[1], x)))
    end

    -- note lfo max
    if x <= grid_param_resolution and y == 5 and z == 1 then
        local range = params:get_range("note_lfo_max")
        params:set("note_lfo_max", util.round(util.linlin(1, grid_param_resolution, range[2], range[1], x)))
    end

    -- note lfo shape
    if x == 13 and y > 4 and z == 1 then
        params:set("note_lfo_shape", 9 - y)
    end

    -- vel lfo speed
    if x <= grid_param_resolution and y == 4 and z == 1 then
        local range = params:get_range("vel_lfo_speed")
        params:set("vel_lfo_speed", util.linlin(1, grid_param_resolution, range[2], range[1], x))
    end

    -- vel lfo depth
    if x <= grid_param_resolution and y == 3 and z == 1 then
        local range = params:get_range("vel_lfo_depth")
        params:set("vel_lfo_depth", util.linlin(1, grid_param_resolution, range[2], range[1], x))
    end

    -- vel lfo min
    if x <= grid_param_resolution and y == 2 and z == 1 then
        local range = params:get_range("vel_lfo_min")
        params:set("vel_lfo_min", util.round(util.linlin(1, grid_param_resolution, range[2], range[1], x)))
    end

    -- vel lfo max
    if x <= grid_param_resolution and y == 1 and z == 1 then
        local range = params:get_range("vel_lfo_max")
        params:set("vel_lfo_max", util.round(util.linlin(1, grid_param_resolution, range[2], range[1], x)))
    end

    -- vel lfo shape
    if x == 13 and y < 5 and z == 1 then
        params:set("vel_lfo_shape", 5 - y)
    end

    -- custom scale
    -- if x == 14 and z == 1 then
    --     params:set("scale_custom", 9 - y)
    -- end

    -- state
    if x == 14 and z == 1 then
        params:set("state", 9 - y)
    end

    -- keyboard
    if x == 15 and y < 4 and z == 1 then
        update_custom_scale(grid_to_note(x, y))
    elseif x == 15 and y > 4 and y < 7 and z == 1 then
        update_custom_scale(grid_to_note(x, y))
    elseif x == 16 and y < 8 and z == 1 then
        update_custom_scale(grid_to_note(x, y))
    end

    grid_dirty = true
end

function grid_to_note(x, y)
    local note
    if x == 16 and y == 7 then
        note = 1
    elseif x == 15 and y == 6 then
        note = 2
    elseif x == 16 and y == 6 then
        note = 3
    elseif x == 15 and y == 5 then
        note = 4
    elseif x == 16 and y == 5 then
        note = 5
    elseif x == 16 and y == 4 then
        note = 6
    elseif x == 15 and y == 3 then
        note = 7
    elseif x == 16 and y == 3 then
        note = 8
    elseif x == 15 and y == 2 then
        note = 9
    elseif x == 16 and y == 2 then
        note = 10
    elseif x == 15 and y == 1 then
        note = 11
    elseif x == 16 and y == 1 then
        note = 12
    end
    -- print("x: " .. x .. " y: " .. y .. " note: " .. note)

    return note
end

function grid_redraw_clock() -- our grid redraw clock
    while true do -- while it's running...
        clock.sleep(1 / 30) -- refresh at 30fps.
        if grid_dirty then -- if a redraw is needed...
            grid_redraw() -- redraw...
            grid_dirty = false -- then redraw is no longer needed.
        end
    end
end

function grid_redraw()
    g:all(0)

    -- note lfo speed
    local note_lfo_speed_range = params:get_range("note_lfo_speed")
    local note_lfo_speed = params:get("note_lfo_speed")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(
                util.linlin(note_lfo_speed_range[1], note_lfo_speed_range[2], grid_param_resolution, 1, note_lfo_speed)) then
            led = 15
        end
        g:led(i, 8, led)
    end

    -- note lfo depth
    local note_lfo_depth_range = params:get_range("note_lfo_depth")
    local note_lfo_depth = params:get("note_lfo_depth")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(
                util.linlin(note_lfo_depth_range[1], note_lfo_depth_range[2], grid_param_resolution, 1, note_lfo_depth)) then
            led = 15
        end
        g:led(i, 7, led)
    end

    -- note lfo min
    local note_lfo_min_range = params:get_range("note_lfo_min")
    local note_lfo_min = params:get("note_lfo_min")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(util.linlin(note_lfo_min_range[1], note_lfo_min_range[2], grid_param_resolution, 1, note_lfo_min)) then
            led = 15
        end
        g:led(i, 6, led)
    end

    -- note lfo max
    local note_lfo_max_range = params:get_range("note_lfo_max")
    local note_lfo_max = params:get("note_lfo_max")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(util.linlin(note_lfo_max_range[1], note_lfo_max_range[2], grid_param_resolution, 1, note_lfo_max)) then
            led = 15
        end
        g:led(i, 5, led)
    end

    -- note lfo shape
    for i = 5, 8 do
        local led = 1
        if i == 9 - params:get("note_lfo_shape") then
            led = 15
        end
        g:led(13, i, led)
    end

    -- vel lfo speed
    local vel_lfo_speed_range = params:get_range("vel_lfo_speed")
    local vel_lfo_speed = params:get("vel_lfo_speed")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(
                util.linlin(vel_lfo_speed_range[1], vel_lfo_speed_range[2], grid_param_resolution, 1, vel_lfo_speed)) then
            led = 15
        end
        g:led(i, 4, led)
    end

    -- vel lfo depth
    local vel_lfo_depth_range = params:get_range("vel_lfo_depth")
    local vel_lfo_depth = params:get("vel_lfo_depth")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(
                util.linlin(vel_lfo_depth_range[1], vel_lfo_depth_range[2], grid_param_resolution, 1, vel_lfo_depth)) then
            led = 15
        end
        g:led(i, 3, led)
    end

    -- vel lfo min
    local vel_lfo_min_range = params:get_range("vel_lfo_min")
    local vel_lfo_min = params:get("vel_lfo_min")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(util.linlin(vel_lfo_min_range[1], vel_lfo_min_range[2], grid_param_resolution, 1, vel_lfo_min)) then
            led = 15
        end
        g:led(i, 2, led)
    end

    -- vel lfo max
    local vel_lfo_max_range = params:get_range("vel_lfo_max")
    local vel_lfo_max = params:get("vel_lfo_max")
    for i = 1, grid_param_resolution do
        local led = 5
        if i ==
            util.round(util.linlin(vel_lfo_max_range[1], vel_lfo_max_range[2], grid_param_resolution, 1, vel_lfo_max)) then
            led = 15
        end
        g:led(i, 1, led)
    end

    -- vel lfo shape
    for i = 1, 4 do
        local led = 1
        if i == 5 - params:get("vel_lfo_shape") then
            led = 15
        end
        g:led(13, i, led)
    end

    -- custom scale
    -- for i = 1, 8 do
    --     local led = 5
    --     if i == 9 - params:get("scale_custom") then
    --         led = 15
    --     end
    --     g:led(14, i, led)
    -- end

    -- state
    for i = 1, 8 do
        local led = 5
        if i == 9 - params:get("state") then
            led = 15
        end
        g:led(14, i, led)
    end

    -- keyboard
    local keyboard = {{16, 7}, {15, 6}, {16, 6}, {15, 5}, {16, 5}, {16, 4}, {15, 3}, {16, 3}, {15, 2}, {16, 2}, {15, 1},
                      {16, 1}}

    for i = 1, #keyboard do
        local led = 5
        if states[params:get("state")].custom_scale[i] == 1 then
            led = 15
        end
        g:led(keyboard[i][1], keyboard[i][2], led)
    end

    g:refresh()
end
