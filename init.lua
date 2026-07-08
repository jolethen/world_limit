-- Localizing functions for maximum speed (Direct memory access)
local abs = math.abs
local get_time = minetest.get_gametime
local get_players = minetest.get_connected_players
local check_privs = minetest.check_player_privs
local chat_send = minetest.chat_send_player
local colorize = minetest.colorize

-- Settings
local LIMIT = 2000
local WARNING_ZONE = 1990
local PUSH_BACK = 10
local TICK_RATE = 1 -- Dropped to 1 second for highly responsive border enforcement
local WARN_COOLDOWN = 15 -- Cooldown for the warning zone in seconds

-- Variables
local timer = 0
local last_warned = {} -- Tracks timestamp of last HUD warning per player

-- Ensure the privilege exists
minetest.register_privilege("developer", {
    description = "Allows bypassing the world border.",
    give_to_singleplayer = false,
})

-- Clean up tracking table when a player leaves
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if name then
        last_warned[name] = nil
    end
end)

minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < TICK_RATE then return end
    timer = 0

    local all_players = get_players()
    if #all_players == 0 then return end

    local current_time = get_time()

    for i = 1, #all_players do
        local player = all_players[i]
        
        -- 1. Safety Check: Ensure player object and name are not nil
        if player and player:is_player() then
            local name = player:get_player_name()

            -- 2. Performance Check: Skip if developer
            if name and not check_privs(name, {developer = true}) then
                local pos = player:get_pos()

                -- 3. Position Nil-Check (Important for lag spikes/teleports)
                if pos and pos.x and pos.z then
                    local abs_x = abs(pos.x)
                    local abs_z = abs(pos.z)

                    -- HARD LIMIT CHECK (Triggers instantly, ignores cooldown)
                    if abs_x > LIMIT or abs_z > LIMIT then
                        local new_pos = {x = pos.x, y = pos.y, z = pos.z}
                        
                        if abs_x > LIMIT then
                            new_pos.x = pos.x > 0 and (LIMIT - PUSH_BACK) or (-LIMIT + PUSH_BACK)
                        end
                        if abs_z > LIMIT then
                            new_pos.z = pos.z > 0 and (LIMIT - PUSH_BACK) or (-LIMIT + PUSH_BACK)
                        end

                        player:set_pos(new_pos)
                        chat_send(name, colorize("#FF0000", "BORDER REACHED: You cannot pass 2000 blocks!"))
                    
                    -- WARNING ZONE CHECK (Enforces a 15-second cooldown per player)
                    elseif abs_x > WARNING_ZONE or abs_z > WARNING_ZONE then
                        local last_warn = last_warned[name] or 0
                        if (current_time - last_warn) >= WARN_COOLDOWN then
                            -- The 'true' at the end sends it to the HUD (Action Bar)
                            chat_send(name, colorize("#FFD700", "Warning: 10 blocks until world border."), true)
                            last_warned[name] = current_time
                        end
                    end
                end
            end
        end
    end
end)
