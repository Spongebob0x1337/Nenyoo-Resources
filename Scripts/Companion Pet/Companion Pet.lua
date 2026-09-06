-- @nenyoo-menu
-- Companion Pet -- a dog that actually comes with you.
--
-- Follows, sits, begs, shakes a paw, rides in your car, defends you, and can be brought back if it
-- goes down.
--
-- On tricks: only the ROTTWEILER family (Chop) and the generic dog clipset carry sit/beg/paw. Huskies,
-- retrievers, pugs and the rest have their own move dictionaries with no trick animations, and cats
-- and wildlife share nothing with the dog skeleton at all. So tricks are resolved per breed and the
-- command is refused with an explanation rather than firing a native that would silently do nothing.
--
-- Threading (see CLAUDE.md): everything here runs on the SCRIPT thread. The card is drawn on the
-- RENDER thread from a published snapshot.

local NAME = "Companion Pet"
local CFG  = "companion_pet"

----------------------------------------------------------------------------------------------------
-- natives (hashes verified against src/invoker/natives.hpp)
----------------------------------------------------------------------------------------------------

local call = native.call

local N = {
    REQUEST_ANIM_DICT       = 0xD3BD40951412FEF6,
    HAS_ANIM_DICT_LOADED    = 0xD031A9162D01088C,
    TASK_PLAY_ANIM          = 0xEA47FE3719165B94,
    CLEAR_PED_TASKS         = 0xE1EF3C1216AFF2CD,
    TASK_FOLLOW_TO_OFFSET   = 0x304AE42E357B8C7E,
    TASK_GO_TO_ENTITY       = 0x6A071245EB0D1882,
    TASK_COMBAT_PED         = 0xF166E48407BAC484,
    TASK_ENTER_VEHICLE      = 0xC20E50AA46D09CA8,
    SET_PED_AS_GROUP_MEMBER = 0x9F3480FE65DB31B5,
    SET_PED_NEVER_LEAVES    = 0x3DBFC55D5C9BB447,
    GET_PLAYER_GROUP        = 0x0D127585F77030AF,
    SET_PED_KEEP_TASK       = 0x971D38760FBC02EF,
    SET_PED_CAN_RAGDOLL     = 0xB128377056A54E2A,
    SET_PED_CAN_BE_TARGETTED= 0x63F58F7C80513AAD,
    SET_PED_MAX_HEALTH      = 0xF5F6378C4F3419D3,
    SET_ENTITY_HEALTH       = 0x6B76DC1F3AE6E6A3,
    GET_ENTITY_HEALTH       = 0xEEF059FAD016D209,
    SET_ENTITY_INVINCIBLE   = 0x3882114BDE571AD4,
    RESURRECT_PED           = 0x71BC8E838B9C6035,
    IS_PED_DEAD_OR_DYING    = 0x3317DEDB88C95038,
    IS_PED_IN_COMBAT        = 0x4859F1FC66A6278E,
    IS_PED_IN_ANY_VEHICLE   = 0x997ABD671D25CA0B,
    IS_PED_SITTING_IN_VEH   = 0x826AA586EDB9FEF8,
    GET_VEHICLE_PED_IS_IN   = 0x9A9112A0FE9A4713,
    IS_VEHICLE_SEAT_FREE    = 0x22AC59A870E6A669,
    GET_FREE_AIM_TARGET     = 0x2975C866E6713290,
    ADD_BLIP_FOR_ENTITY     = 0x5CDE92C702A8FCE7,
    SET_BLIP_SPRITE         = 0xDF735600A4696DAF,
    SET_BLIP_COLOUR         = 0x03D7FB09E75D6B7E,
    SET_BLIP_SCALE          = 0xD38744167B2FA257,
    REMOVE_BLIP             = 0x86A652570E5F25DD,
    SET_PED_RELATIONSHIP    = 0xC80A74AC829DDD92,
}

local function nbool(h, ...) return call(h, ...) ~= 0 end

local scratch
local function buf() if not scratch then scratch = memory.alloc(8) end return scratch end
local function remove_blip(b)
    if not b or b == 0 then return end
    local p = buf(); memory.write_int(p, b); call(N.REMOVE_BLIP, p)
end

----------------------------------------------------------------------------------------------------
-- breeds
--
-- `tricks` names the clipset that carries sit/beg/paw for that model. Every dict/anim pair below was
-- checked against the full animation catalogue.
----------------------------------------------------------------------------------------------------

local ROTT = "creatures@rottweiler@tricks@"
local DOG  = "creatures@dog@move"

local BREEDS = {
    { model = "a_c_chop",           name = "Chop",          tricks = ROTT, chop = true },
    { model = "a_c_rottweiler",     name = "Rottweiler",    tricks = ROTT, chop = true },
    { model = "a_c_rottweiler_02",  name = "Rottweiler II", tricks = ROTT, chop = true },
    { model = "a_c_husky",          name = "Husky",         tricks = DOG },
    { model = "a_c_retriever",      name = "Retriever",     tricks = DOG },
    { model = "a_c_shepherd",       name = "Shepherd",      tricks = DOG },
    { model = "a_c_poodle",         name = "Poodle",        tricks = DOG },
    { model = "a_c_pug",            name = "Pug",           tricks = DOG },
    { model = "a_c_westy",          name = "Westie",        tricks = DOG },
    { model = "a_c_cat_01",         name = "Cat",           tricks = nil },
    { model = "a_c_coyote",         name = "Coyote",        tricks = nil },
    { model = "a_c_mtlion",         name = "Mountain Lion", tricks = nil },
    { model = "a_c_boar",           name = "Boar",          tricks = nil },
    { model = "a_c_deer",           name = "Deer",          tricks = nil },
    { model = "a_c_pig",            name = "Pig",           tricks = nil },
    { model = "a_c_chimp",          name = "Chimp",         tricks = nil },
    { model = "a_c_rabbit_01",      name = "Rabbit",        tricks = nil },
}

-- Trick -> anim name inside the breed's trick clipset. Both ROTT and DOG carry all three.
local TRICKS = {
    { key = "sit",  label = "Sit",       anim = "sit_loop",       loop = true },
    { key = "beg",  label = "Beg",       anim = "beg_loop",       loop = true },
    { key = "paw",  label = "Shake Paw", anim = "paw_right_loop", loop = true },
}
-- Chop-only extras that live outside the tricks clipset.
local CHOP_ONLY = {
    { key = "sleep", label = "Sleep",   dict = "creatures@rottweiler@amb@sleep_in_kennel@",       anim = "sleep_in_kennel", loop = true },
    { key = "bark",  label = "Speak",   dict = "creatures@rottweiler@amb@world_dog_barking@idle_a", anim = "idle_a",        loop = false },
    { key = "pet",   label = "Pet Them", dict = ROTT,                                              anim = "petting_chop",   loop = false },
}

local function breed_by_model(m)
    for _, b in ipairs(BREEDS) do if b.model == m then return b end end
    return BREEDS[1]
end

----------------------------------------------------------------------------------------------------
-- config
----------------------------------------------------------------------------------------------------

local cfg = {
    model = "a_c_chop",
    petname = "Chop",
    invincible = true,
    protective = true,      -- attack anyone fighting you
    ride_along = true,      -- get in the car with you
    recall_dist = 70,       -- teleport back if further than this
    show_panel = true,
    panel_x = 2, panel_y = 60,
}

do
    local saved = settings.load(CFG)
    for k, v in pairs(saved) do if cfg[k] ~= nil then cfg[k] = v end end
end

local dirty_at = 0
local function mark_dirty() dirty_at = util.time_ms() + 1200 end

----------------------------------------------------------------------------------------------------
-- state
----------------------------------------------------------------------------------------------------

local S = {
    ped = nil,
    blip = nil,
    breed = nil,
    state = "away",         -- away | following | staying | trick | fighting | down
    trick = nil,
    last_cmd = 0,
    last_veh = nil,
}

local HUD = { snap = nil }
local ui = {}

local function alive()
    return S.ped and S.ped ~= 0 and entity.exists(S.ped) and not nbool(N.IS_PED_DEAD_OR_DYING, S.ped, 1)
end

local function dist_to_player()
    if not alive() then return 0 end
    return entity.coords(S.ped):distance(entity.coords(player.ped()))
end

local function refresh_rows()
    if ui.status then menu.set_value(ui.status, S.ped and S.state or "not out") end
    if ui.breed then menu.set_value(ui.breed, S.breed and S.breed.name or breed_by_model(cfg.model).name) end
    if ui.name then menu.set_value(ui.name, cfg.petname) end
end

----------------------------------------------------------------------------------------------------
-- behaviour
----------------------------------------------------------------------------------------------------

local function follow()
    if not alive() then return end
    call(N.CLEAR_PED_TASKS, S.ped)
    -- offset behind and to the side so it heels rather than walking through you
    call(N.TASK_FOLLOW_TO_OFFSET, S.ped, player.ped(), -0.6, -1.2, 0.0, 2.0, -1, 2.5, true)
    S.state, S.trick = "following", nil
end

local function stay()
    if not alive() then return end
    call(N.CLEAR_PED_TASKS, S.ped)
    S.state, S.trick = "staying", nil
end

local function play_trick(t)
    if not alive() then return end
    local dict = t.dict or (S.breed and S.breed.tricks)
    if not dict then
        notify.push(NAME, string.format("A %s has no trick animations.", (S.breed or {}).name or "pet"), 1, 4.0)
        return
    end
    if t.chop_only and not (S.breed and S.breed.chop) then
        notify.push(NAME, string.format("Only Chop and the rottweilers know %s.", t.label), 1, 4.0)
        return
    end

    call(N.REQUEST_ANIM_DICT, dict)
    local deadline = util.time_ms() + 2500
    while not nbool(N.HAS_ANIM_DICT_LOADED, dict) do
        if util.time_ms() > deadline then
            notify.push(NAME, "That animation would not load.", 2, 4.0)
            return
        end
        util.yield()
    end

    call(N.CLEAR_PED_TASKS, S.ped)
    call(N.TASK_PLAY_ANIM, S.ped, dict, t.anim, 4.0, -4.0, -1, t.loop and 1 or 0, 0.0, false, false, false)
    S.state, S.trick = "trick", t.label
end

local function attack_target()
    if not alive() then return end
    local me = player.ped()

    -- what you are aiming at wins; otherwise whoever is already fighting you
    local target = call(N.GET_FREE_AIM_TARGET, player.id(), buf())
    target = memory.read_int(buf())
    if not target or target == 0 or not entity.exists(target) then
        target = nil
        local best, bestd = nil, 1e9
        local mypos = entity.coords(me)
        for _, p in ipairs(entity.all_peds()) do
            if p ~= me and p ~= S.ped and entity.exists(p) and not nbool(N.IS_PED_DEAD_OR_DYING, p, 1) then
                if nbool(N.IS_PED_IN_COMBAT, p, me) then
                    local d = entity.coords(p):distance(mypos)
                    if d < bestd then best, bestd = p, d end
                end
            end
        end
        target = best
    end

    if not target then
        notify.push(NAME, "Nothing to go after right now.", 1, 3.0)
        return
    end
    call(N.CLEAR_PED_TASKS, S.ped)
    call(N.TASK_COMBAT_PED, S.ped, target, 0, 16)
    S.state, S.trick = "fighting", nil
end

local function dismiss()
    if S.ped and S.ped ~= 0 then
        remove_blip(S.blip)
        if entity.exists(S.ped) then entity.delete(S.ped) end
    end
    S.ped, S.blip, S.breed, S.trick = nil, nil, nil, nil
    S.state = "away"
    refresh_rows()
end

local function spawn_pet()
    dismiss()
    local b = breed_by_model(cfg.model)
    local me = player.ped()
    local p = entity.coords(me)

    local h = entity.spawn_ped(b.model, v3.new(p.x + 1.2, p.y + 1.2, p.z), 0.0, true)
    if not h or h == 0 then
        notify.push(NAME, "The pet could not be spawned.", 2, 4.0)
        return
    end

    S.ped, S.breed = h, b
    call(N.SET_PED_MAX_HEALTH, h, 400)
    call(N.SET_ENTITY_HEALTH, h, 400, 0)
    call(N.SET_ENTITY_INVINCIBLE, h, cfg.invincible)
    call(N.SET_PED_CAN_RAGDOLL, h, true)
    call(N.SET_PED_CAN_BE_TARGETTED, h, false)
    call(N.SET_PED_KEEP_TASK, h, true)
    call(N.SET_PED_RELATIONSHIP, h, call(0x7DBDD04862D95F04, me))   -- share your relationship group

    -- Joining the player's group is what makes it treat you as its owner rather than a stranger.
    local grp = call(N.GET_PLAYER_GROUP, player.id())
    call(N.SET_PED_AS_GROUP_MEMBER, h, grp)
    call(N.SET_PED_NEVER_LEAVES, h, true)

    S.blip = call(N.ADD_BLIP_FOR_ENTITY, h)
    if S.blip and S.blip ~= 0 then
        call(N.SET_BLIP_SPRITE, S.blip, 442)
        call(N.SET_BLIP_COLOUR, S.blip, 2)
        call(N.SET_BLIP_SCALE, S.blip, 0.7)
    end

    follow()
    refresh_rows()
    notify.push(NAME, string.format("%s is with you.", cfg.petname), 0, 4.0)
end

local function revive()
    if not S.ped or S.ped == 0 or not entity.exists(S.ped) then
        notify.push(NAME, "There is nobody to bring back.", 1, 3.0)
        return
    end
    local p = entity.coords(player.ped())
    call(N.RESURRECT_PED, S.ped)
    entity.set_coords(S.ped, p.x + 1.2, p.y + 1.2, p.z)
    call(N.SET_ENTITY_HEALTH, S.ped, 400, 0)
    call(N.SET_ENTITY_INVINCIBLE, S.ped, cfg.invincible)
    follow()
    notify.push(NAME, string.format("%s is back on their feet.", cfg.petname), 0, 4.0)
end

----------------------------------------------------------------------------------------------------
-- tick
----------------------------------------------------------------------------------------------------

util.create_thread(function()
    while true do
        if S.ped and S.ped ~= 0 then
            local me = player.ped()

            if not alive() then
                if S.state ~= "down" then
                    S.state = "down"
                    notify.push(NAME, string.format("%s is down.", cfg.petname), 2, 5.0)
                    refresh_rows()
                end
            else
                if S.state == "down" then S.state = "following" end

                -- ride along: get in whatever you are driving, and out again when you leave
                if cfg.ride_along then
                    local veh = nbool(N.IS_PED_IN_ANY_VEHICLE, me, false)
                        and call(N.GET_VEHICLE_PED_IS_IN, me, false) or 0
                    if veh ~= 0 and veh ~= S.last_veh then
                        if not nbool(N.IS_PED_SITTING_IN_VEH, S.ped) then
                            for seat = 0, 3 do
                                if nbool(N.IS_VEHICLE_SEAT_FREE, veh, seat, false) then
                                    call(N.TASK_ENTER_VEHICLE, S.ped, veh, 12000, seat, 2.0, 1, 0)
                                    break
                                end
                            end
                        end
                        S.last_veh = veh
                    elseif veh == 0 and S.last_veh then
                        S.last_veh = nil
                        if S.state == "following" then follow() end
                    end
                end

                -- defend: pick up anyone who starts a fight with you
                if cfg.protective and S.state == "following" and (util.time_ms() - S.last_cmd) > 2000 then
                    for _, p in ipairs(entity.all_peds()) do
                        if p ~= me and p ~= S.ped and entity.exists(p)
                           and nbool(N.IS_PED_IN_COMBAT, p, me) then
                            local d = entity.coords(p):distance(entity.coords(me))
                            if d < 25.0 then
                                call(N.TASK_COMBAT_PED, S.ped, p, 0, 16)
                                S.state = "fighting"
                                S.last_cmd = util.time_ms()
                            end
                            break
                        end
                    end
                end

                -- a fight that is over hands control back to heeling
                if S.state == "fighting" and (util.time_ms() - S.last_cmd) > 4000
                   and not nbool(N.IS_PED_IN_COMBAT, S.ped, 0) then
                    follow()
                end

                -- do not let it get lost
                if S.state ~= "staying" and dist_to_player() > cfg.recall_dist then
                    local p = entity.coords(me)
                    entity.set_coords(S.ped, p.x + 1.0, p.y + 1.0, p.z)
                    follow()
                end
            end
        end

        if dirty_at ~= 0 and util.time_ms() >= dirty_at then
            dirty_at = 0
            settings.save(CFG, cfg)
        end

        util.yield()
    end
end)

util.create_thread(function()
    while true do
        if not (cfg.show_panel and S.ped and S.ped ~= 0 and entity.exists(S.ped)) then
            HUD.snap = nil
        else
            local hp = call(N.GET_ENTITY_HEALTH, S.ped)
            HUD.snap = {
                name  = cfg.petname,
                breed = S.breed and S.breed.name or "",
                state = S.trick or S.state,
                hp    = math.max(0.0, math.min(1.0, hp / 400.0)),
                down  = not alive(),
                dist  = dist_to_player(),
                px = cfg.panel_x, py = cfg.panel_y,
            }
        end
        util.yield(120)
    end
end)

----------------------------------------------------------------------------------------------------
-- panel (render thread -- no natives)
----------------------------------------------------------------------------------------------------

overlay.on_draw(NAME, function()
    local s = HUD.snap
    if not s then return end

    local sw, sh = ctx.screen_w(), ctx.screen_h()
    local ar, ag, ab = theme.accent()
    local pad, w, h = 14, 208, 74
    local x = math.max(4, math.min(sw - w - 4, sw * (s.px / 100.0)))
    local y = math.max(4, math.min(sh - h - 4, sh * (s.py / 100.0)))
    local left, right = x + pad, x + w - pad

    local function rt(f, rx, ty, r, g, b, a, str)
        text.draw(f, rx - text.width(f, str), ty, r, g, b, a, str)
    end

    local dr, dg, db = ar, ag, ab
    if s.down then dr, dg, db = 224, 72, 72 end

    draw.rect(x, y, x + w, y + h, 10, 10, 16, 216, 7)
    draw.rect(x, y, x + 3, y + h, dr, dg, db, 245, 3)

    text.draw_ellipsis(font.item, left, y + 10, 234, 234, 242, 255, s.name, w - pad * 2 - 42)
    rt(font.small, right, y + 13, 148, 148, 160, 255, s.breed)

    text.draw_ellipsis(font.small, left, y + 30, 168, 168, 180, 255,
                       s.down and "down" or s.state, w - pad * 2 - 46)
    rt(font.small, right, y + 30, 130, 130, 144, 255, string.format("%.0f m", s.dist))

    local by = y + h - 20
    draw.rect(left, by, right, by + 6, 38, 38, 46, 230, 3)
    if s.hp > 0 then
        draw.rect(left, by, left + (right - left) * s.hp, by + 6, dr, dg, db, 245, 3)
    end
end)

----------------------------------------------------------------------------------------------------
-- menu
----------------------------------------------------------------------------------------------------

local root = menu.my_root()

menu.action(root, "Call Them Over", {}, "Spawn your pet next to you.", function() spawn_pet() end)
menu.action(root, "Send Them Away", {}, "Dismiss the pet.", function()
    dismiss()
    notify.push(NAME, "Sent away.", 0, 3.0)
end)

menu.divider(root, "Commands")
menu.action(root, "Heel", {}, "Come back and follow at your side.", function()
    if alive() then S.last_cmd = util.time_ms(); follow() else notify.push(NAME, "No pet out.", 1, 3.0) end
end)
menu.action(root, "Stay", {}, "Hold position until told otherwise.", function()
    if alive() then S.last_cmd = util.time_ms(); stay() else notify.push(NAME, "No pet out.", 1, 3.0) end
end)
for _, t in ipairs(TRICKS) do
    menu.action(root, t.label, {}, "", function()
        if not alive() then notify.push(NAME, "No pet out.", 1, 3.0); return end
        S.last_cmd = util.time_ms(); play_trick(t)
    end)
end
menu.action(root, "Sic 'Em", {}, "Attack whoever you are aiming at, or whoever is fighting you.", function()
    if alive() then S.last_cmd = util.time_ms(); attack_target() else notify.push(NAME, "No pet out.", 1, 3.0) end
end)

local chop_list = menu.list(root, "Chop's Extras", {}, "Tricks only the rottweilers know.")
for _, t in ipairs(CHOP_ONLY) do
    local tt = { key = t.key, label = t.label, dict = t.dict, anim = t.anim, loop = t.loop, chop_only = true }
    menu.action(chop_list, t.label, {}, "", function()
        if not alive() then notify.push(NAME, "No pet out.", 1, 3.0); return end
        S.last_cmd = util.time_ms(); play_trick(tt)
    end)
end

menu.divider(root, "Your Pet")
ui.name  = menu.readonly(root, "Name", cfg.petname)
ui.breed = menu.readonly(root, "Breed", breed_by_model(cfg.model).name)
ui.status = menu.readonly(root, "Doing", "not out")

local breed_list = menu.list(root, "Choose Breed", {}, "Dogs know tricks. Everything else just follows.")
local breed_refs = {}
for _, b in ipairs(BREEDS) do
    breed_refs[b.model] = menu.action(breed_list, b.name, {},
        b.tricks and "Knows tricks." or "No trick animations for this species.",
        function()
            cfg.model = b.model
            if cfg.petname == breed_by_model(cfg.model).name or cfg.petname == "" then cfg.petname = b.name end
            for m, r in pairs(breed_refs) do menu.set_ticked(r, m == b.model) end
            mark_dirty(); refresh_rows()
            if S.ped then spawn_pet() end
        end)
end
for m, r in pairs(breed_refs) do menu.set_ticked(r, m == cfg.model) end

if menu.text_input then
    menu.text_input(root, "Rename", {}, "Give your pet a name.", function(t)
        if t and #t > 0 then cfg.petname = t; mark_dirty(); refresh_rows() end
    end, cfg.petname)
end

menu.divider(root, "Behaviour")
menu.toggle(root, "Invincible", {}, "Your pet cannot be hurt.", function(on)
    cfg.invincible = on
    if alive() then call(N.SET_ENTITY_INVINCIBLE, S.ped, on) end
    mark_dirty()
end, cfg.invincible)
menu.toggle(root, "Defends You", {}, "Goes after anyone who picks a fight with you.", function(on)
    cfg.protective = on; mark_dirty()
end, cfg.protective)
menu.toggle(root, "Rides Along", {}, "Gets in the car with you.", function(on)
    cfg.ride_along = on; mark_dirty()
end, cfg.ride_along)
menu.slider(root, "Recall Distance", {}, "How far they can stray before being brought back to you.", 20, 200, cfg.recall_dist, 10, function(v)
    cfg.recall_dist = v; mark_dirty()
end)

menu.divider(root, "Panel")
menu.toggle(root, "Show Panel", {}, "The pet card.", function(on) cfg.show_panel = on; mark_dirty() end, cfg.show_panel)
menu.slider(root, "Panel X", {}, "Horizontal position, percent of screen.", 0, 92, cfg.panel_x, 1, function(v) cfg.panel_x = v; mark_dirty() end)
menu.slider(root, "Panel Y", {}, "Vertical position, percent of screen.", 0, 88, cfg.panel_y, 1, function(v) cfg.panel_y = v; mark_dirty() end)

menu.divider(root, "")
menu.action(root, "Bring Them Back", {}, "Revive your pet and heal them.", function() revive() end)

refresh_rows()

if util.on_stop then util.on_stop(function() dismiss() end) end
