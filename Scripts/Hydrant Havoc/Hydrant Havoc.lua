-- @nenyoo-menu
-- Hydrant Havoc
-- Bursts attached water-hydrant explosions beneath nearby peds and the local vehicle.

local nv = native_invoker

local enabled = false
local nearby_peds = true
local my_vehicle = false
local include_players = false
local range = 35
local interval_ms = 3000
local max_targets = 16
local next_burst_at = 0
local last_target_count = 0
local enabled_row = nil
local missing_api_warned = false

local WATER_HYDRANT_EXPLOSION = 13
local UNDER_PED_OFFSET = -1.0
local UNDER_WHEEL_OFFSET = 0.35
local WHEELS = {
    { bone = "wheel_lf", fallback = { -0.9,  1.4, -0.7 } },
    { bone = "wheel_rf", fallback = {  0.9,  1.4, -0.7 } },
    { bone = "wheel_lr", fallback = { -0.9, -1.3, -0.7 } },
    { bone = "wheel_rr", fallback = {  0.9, -1.3, -0.7 } },
}

local function call_bool(hash, setup)
    nv.begin_call()
    if setup then setup() end
    nv.end_call(hash)
    return nv.get_return_value_bool()
end

local function call_int(hash, setup)
    nv.begin_call()
    if setup then setup() end
    nv.end_call(hash)
    return nv.get_return_value_int()
end

local function call_vector(hash, setup)
    nv.begin_call()
    if setup then setup() end
    nv.end_call(hash)
    return v3.new(nv.get_return_value_vector3())
end

local function is_player_ped(ped)
    return call_bool("12534C348C6CB68B", function()
        nv.push_arg_int(ped)
    end)
end

local function is_dead(ped)
    return call_bool("5F9532F3B5CC2551", function()
        nv.push_arg_int(ped)
        nv.push_arg_bool(false)
    end)
end

local function offset_from_entity(ent, x, y, z)
    nv.begin_call()
    nv.push_arg_int(ent)
    nv.push_arg_float(x)
    nv.push_arg_float(y)
    nv.push_arg_float(z)
    nv.end_call("1899F328B0E12848") -- GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS
    return v3.new(nv.get_return_value_vector3())
end

local function entity_bone(ent, name)
    return call_int("FB71170B7E76ACBA", function()
        nv.push_arg_int(ent)
        nv.push_arg_string(name)
    end) -- GET_ENTITY_BONE_INDEX_BY_NAME
end

local function wheel_position(vehicle, wheel)
    local bone = entity_bone(vehicle, wheel.bone)
    if bone >= 0 then
        local pos = call_vector("44A8FCB8ED227738", function()
            nv.push_arg_int(vehicle)
            nv.push_arg_int(bone)
        end) -- GET_WORLD_POSITION_OF_ENTITY_BONE
        return v3.new(pos.x, pos.y, pos.z - UNDER_WHEEL_OFFSET)
    end

    local fallback = wheel.fallback
    return offset_from_entity(vehicle, fallback[1], fallback[2], fallback[3])
end

local function water_burst(ent, pos, no_damage)
    if explosion and explosion.add_attached then
        return explosion.add_attached(
            ent, pos.x, pos.y, pos.z,
            WATER_HYDRANT_EXPLOSION,
            0,     -- unowned
            1.0,   -- scale
            0.0,   -- camera shake
            true,  -- audible
            false, -- visible
            no_damage ~= false
        )
    end

    if not missing_api_warned then
        missing_api_warned = true
        util.toast("Attached explosion API unavailable in this DLL.")
    end
    return false
end

local function current_vehicle()
    local ped = player.ped()
    local vehicle = call_int("9A9112A0FE9A4713", function()
        nv.push_arg_int(ped)
        nv.push_arg_bool(false)
    end) -- GET_VEHICLE_PED_IS_IN
    if entity.exists(vehicle) then return vehicle end

    vehicle = call_int("9A9112A0FE9A4713", function()
        nv.push_arg_int(ped)
        nv.push_arg_bool(true)
    end) -- GET_VEHICLE_PED_IS_IN (last vehicle)
    return entity.exists(vehicle) and vehicle or 0
end

local function burst_under_my_vehicle(show_error)
    local vehicle = current_vehicle()
    if vehicle == 0 then
        if show_error then util.toast("Enter a vehicle once first.") end
        return false
    end

    local created = 0
    for _, wheel in ipairs(WHEELS) do
        if water_burst(vehicle, wheel_position(vehicle, wheel), true) then
            created = created + 1
        end
    end
    return created
end

local function collect_targets()
    local me = player.ped()
    local origin = entity.coords(me)
    local found = {}

    for _, ped in ipairs(entity.all_peds()) do
        if ped ~= me and entity.exists(ped) and not is_dead(ped) then
            local player_ped = is_player_ped(ped)
            if include_players or not player_ped then
                local pos = entity.coords(ped)
                local distance = origin:distance(pos)
                if distance <= range then
                    found[#found + 1] = { handle = ped, distance = distance }
                end
            end
        end
    end

    table.sort(found, function(a, b)
        return a.distance < b.distance
    end)
    return found
end

local function burst_now()
    local targets = nearby_peds and collect_targets() or {}
    local vehicle_count = my_vehicle and burst_under_my_vehicle(false) or 0
    local ped_limit = math.max(0, max_targets - vehicle_count)
    local count = math.min(#targets, ped_limit)

    for i = 1, count do
        local ped = targets[i].handle
        if entity.exists(ped) then
            water_burst(ped, offset_from_entity(ped, 0.0, 0.0, UNDER_PED_OFFSET))
        end
    end

    last_target_count = count + vehicle_count
    next_burst_at = util.time_ms() + interval_ms
end

local root = menu.my_root()

enabled_row = menu.toggle(root, "Enabled", {}, "Run attached water hydrants beneath the selected targets", function(on)
    enabled = on
    next_burst_at = on and util.time_ms() or 0
    if not on then last_target_count = 0 end
end, false)

menu.toggle(root, "Nearby Peds", {}, "Burst hydrants beneath nearby pedestrian targets", function(on)
    nearby_peds = on
end, true)

menu.toggle(root, "My Vehicle", {}, "Attach a hydrant beneath your current or last-used vehicle", function(on)
    my_vehicle = on
end, false)

menu.toggle(root, "Include Players", {}, "Include other player peds; the local player remains excluded", function(on)
    include_players = on
end, false)

menu.slider(root, "Range", {}, "Maximum distance in metres around you", 5, 100, range, 5, function(value)
    range = value
end)

menu.slider(root, "Interval", {}, "Seconds between hydrant bursts", 1, 10, 3, 1, function(value)
    interval_ms = value * 1000
end)

menu.slider(root, "Max Targets", {}, "Limit simultaneous hydrants to protect the game's explosion pool", 1, 16, max_targets, 1, function(value)
    max_targets = value
end)

menu.action(root, "Burst Now", {}, "Trigger all enabled hydrant targets immediately", burst_now)

menu.action(root, "Burst Under My Vehicle", {}, "Attach one hydrant beneath your current or last-used vehicle", function()
    burst_under_my_vehicle(true)
end)

menu.action(root, "Restore Normal", {}, "Disable Hydrant Havoc and stop future bursts", function()
    if enabled_row then menu.set_value(enabled_row, false) end
    enabled = false
    next_burst_at = 0
    last_target_count = 0
end)

script.on_tick(function()
    local now = util.time_ms()
    if enabled and now >= next_burst_at then
        burst_now()
    end
end)

util.toast("Hydrant Havoc loaded.")
