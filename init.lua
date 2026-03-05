-- Localizing functions for maximum speed (Direct memory access)
local abs = math.abs
local get_players = minetest.get_connected_players
local check_privs = minetest.check_player_privs
local chat_send = minetest.chat_send_player
local colorize = minetest.colorize

-- Settings
local LIMIT = 2000
local WARNING_ZONE = 1950
local PUSH_BACK = 15
local TICK_RATE = 0.8 -- Check every 0.8 seconds (even lighter on CPU)

-- Variables
local timer = 0

-- Ensure the privilege exists
minetest.register_privilege("developer", {
    description = "Allows bypassing the world border.",
    give_to_singleplayer = true,
})

minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < TICK_RATE then return end
    timer = 0

    local all_players = get_players()
    if #all_players == 0 then return end

    for i = 1, #all_players do
        local player = all_players[i]
        
        -- 1. Safety Check: Ensure player object and name are not nil
        if player and player:is_player() then
            local name = player:get_player_name()

            -- 2. Performance Check: Skip if developer
            if not check_privs(name, {developer = true}) then
                local pos = player:get_pos()

                -- 3. Position Nil-Check (Important for lag spikes/teleports)
                if pos and pos.x and pos.z then
                    local abs_x = abs(pos.x)
                    local abs_z = abs(pos.z)

                    -- HARD LIMIT CHECK
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
                    
                    -- WARNING ZONE CHECK
                    elseif abs_x > WARNING_ZONE or abs_z > WARNING_ZONE then
                        -- The 'true' at the end sends it to the HUD (Action Bar)
                        chat_send(name, colorize("#FFD700", "Warning: 50 blocks until world border."), true)
                    end
                end
            end
        end
    end
end)
