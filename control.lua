local mod_gui = require("mod-gui")
local util = require("util")

local TICKS_PER_SECOND = 60
local SECONDS_PER_MINUTE = 60

---@return number
local function calculate_heating_requirements(surface, force)
    local heating_requirement_in_watts = 0
    local entities = surface.find_entities_filtered({force = force})
    for _, entity in pairs(entities) do
        local heating_energy = entity.prototype.heating_energy
        local heating_energy_in_watts = heating_energy * TICKS_PER_SECOND
        heating_requirement_in_watts = heating_requirement_in_watts + heating_energy_in_watts
    end
    return heating_requirement_in_watts
end

local function get_frame_name(surface)
    return "aq-" .. surface.name
end

script.on_event(defines.events.on_player_changed_surface, function(event)
    local player = game.get_player(event.player_index)
    local new_surface = player.surface

    local frame_flow = mod_gui.get_frame_flow(player)

    -- Delete old thermometer frame
    if event.surface_index then
        local old_surface = game.get_surface(event.surface_index)
        local old_frame = frame_flow[get_frame_name(old_surface)]
        if old_frame then
            old_frame.destroy()
        end
    end

    -- Check if the new surface requires a thermometer
    local surface_requires_heating = new_surface.planet and new_surface.planet.prototype.entities_require_heating
    if not surface_requires_heating then return end

    local frame = frame_flow.add({
        type = "frame",
        name = get_frame_name(new_surface),
        caption = {"aq.frame-caption", new_surface.localised_name or new_surface.planet.prototype.localised_name}
    })

    local labels = frame.add({
        type = "flow",
        direction = "vertical"
    })

    -- Add heating requirements
    local heating_requirement_in_watts = calculate_heating_requirements(new_surface, player.force)
    labels.add({
        type = "label",
        caption = {"aq.heating-requirements", util.format_number(heating_requirement_in_watts, true)}
    })

    do
        -- Add rocket fuel consumption rate
        local rocket_fuel = prototypes.item["rocket-fuel"]
        local heating_tower = prototypes.entity["heating-tower"]
        if not (rocket_fuel and heating_tower and heating_tower.burner_prototype) then return end

        local fuel_value = rocket_fuel.fuel_value
        local burner_effectivity = heating_tower.burner_prototype.effectivity
        local watts_per_rocket_fuel = fuel_value * burner_effectivity
        local rocket_fuel_per_minute = heating_requirement_in_watts / watts_per_rocket_fuel * SECONDS_PER_MINUTE

        labels.add({
            type = "label",
            caption = { "aq.rocket-fuel-rate", "[item=rocket-fuel]", "[entity=heating-tower]", string.format("%.1f", rocket_fuel_per_minute) }
        })
    end
end)
