_lfos = require "lfo"
s = require "sequins"
MusicUtil = require("musicutil")
g = grid.connect()

dest = {"192.168.1.226", 57120}

previous_note = 0

notes_in_scale = {{1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0}, {0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
                  {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}}

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

    grid_dirty = true -- initialize with a redraw
    clock.run(grid_redraw_clock) -- start the grid redraw clock
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

    params:add{
        type = "option",
        id = "scale_custom",
        name = "scale custom",
        options = custom_scale_option,
        default = 2,
        action = function()
            build_custom_scale()
        end
    }

    -- note lfo
    note_lfo = _lfos:add{
        shape = "sine",
        min = 0,
        max = 127,
        depth = 1,
        mode = "clocked",
        period = 24,
        action = function(scaled, raw)
            local note = util.round(scaled)
            local note = MusicUtil.snap_note_to_array(note, scale_global)
            local note = MusicUtil.snap_note_to_array(note, scale_custom)
            if note ~= previous_note then
                send_osc()
                -- print(note)
            end
            previous_note = note
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
        end
    }

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
    end)

    params:add_number("note_lfo_min", "note lfo min", 0, 127, 45)
    params:set_action("note_lfo_min", function(x)
        if x >= params:get("note_lfo_max") then
            params:set("note_lfo_max", params:get("note_lfo_min") + 1)
        end
        note_lfo:set("min", x)
    end)

    params:add_number("note_lfo_max", "note lfo max", 0, 127, 110)
    params:set_action("note_lfo_max", function(x)
        if x <= params:get("note_lfo_min") then
            params:set("note_lfo_min", params:get("note_lfo_max") - 1)
        end
        note_lfo:set("max", x)
    end)

    -- velocity lfo
    vel_lfo = _lfos:add{
        shape = "saw",
        min = 0,
        max = 127,
        depth = 1,
        mode = "clocked",
        period = 24,
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
        end
    }

    vel_lfo_depth = note_lfo_depth:copy()
    params:add_control("vel_lfo_depth", "vel lfo depth", vel_lfo_depth)
    params:set_action("vel_lfo_depth", function(x)
        vel_lfo:set("depth", x)
    end)

    params:add_number("vel_lfo_min", "vel lfo min", 0, 127, 0)
    params:set_action("vel_lfo_min", function(x)
        if x >= params:get("vel_lfo_max") then
            params:set("vel_lfo_max", params:get("vel_lfo_min") + 1)
        end
        vel_lfo:set("min", x)
    end)

    params:add_number("vel_lfo_max", "vel lfo max", 0, 127, 127)
    params:set_action("vel_lfo_max", function(x)
        if x <= params:get("vel_lfo_min") then
            params:set("vel_lfo_min", params:get("vel_lfo_max") - 1)
        end
        vel_lfo:set("max", x)
    end)
end

function build_custom_scale()
    local temp_scale = {}
    if params:string("scale_custom") == "off" then
        scale_custom = scale_global
        return
    end

    for i = 0, 12, 1 do
        if (notes_in_scale[params:get("scale_custom") - 1][i + 1] == 1) then
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
    osc.send(dest, "/note", {note, vel})

    -- if note ~= previous_note then
    --     osc.send(dest, "/note", {note, vel})
    --     print("note: " .. note .. " vel: " .. vel)
    -- end
    -- previous_note = note
end

g.key = function(x, y, z)
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

function update_custom_scale(index)

    if notes_in_scale[params:get("scale_custom")][index] == 1 then
        notes_in_scale[params:get("scale_custom")][index] = 0
    else
        notes_in_scale[params:get("scale_custom")][index] = 1
    end

    -- for i = 1, #notes_in_scale[params:get("scale_custom")] do
    --     print(notes_in_scale[params:get("scale_custom")][i])
    -- end

    build_custom_scale()
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

    -- keyboard
    for i = 1, 3 do
        g:led(15, i, 5)
    end
    for i = 5, 6 do
        g:led(15, i, 5)
    end
    for i = 1, 7 do
        g:led(16, i, 10)
    end

    g:refresh()
end
