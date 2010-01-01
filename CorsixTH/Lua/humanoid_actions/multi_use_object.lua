--[[ Copyright (c) 2009 Peter "Corsix" Cawley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. --]]

local TH = require "TH"
local orient_mirror = {
  north = "west",
  west = "north",
  east = "south",
  south = "east",
}

local function action_multi_use_next_phase(action, phase)
  phase = phase + 1
  if phase < -3 then
    phase = -3
  end
  if phase == -3 and not action.anims.begin_use then
    phase = phase + 1
  end
  if phase == -2 and not action.anims.begin_use_2 then
    phase = phase + 1
  end
  if phase == -1 and not action.anims.begin_use_3 then
    phase = phase + 1
  end
  if phase == 0 and not action.anims.in_use then
    phase = phase + 1
  end
  if phase == 1 and not action.anims.finish_use then
    phase = phase + 1
  end
  if phase == 2 and not action.anims.finish_use_2 then
    phase = phase + 1
  end
  if phase > 2 then
    phase = 100
  end
  return phase
end

local action_multi_use_object_tick

local function action_multi_use_phase(action, humanoid, phase)
  local object = action.object
  humanoid.user_of = nil -- Temporary to avoid tile change warning
  action.phase = phase
  local anim_name = "in_use"
  if phase == -3 then
    anim_name = "begin_use"
  elseif phase == -2 then
    anim_name = "begin_use_2"
  elseif phase == -1 then
    anim_name = "begin_use_3"
  elseif phase == 1 then
    anim_name = "finish_use"
  elseif phase == 2 then
    anim_name = "finish_use_2"
  end
  local anim = action.anims[anim_name]
  humanoid:setAnimation(anim, action.mirror_flags)
  
  local offset = object.object_type.orientations
  if offset then
    local tx, ty
    offset = offset[object.direction]
    if offset.use_animate_from_use_position then
      tx, ty = object.tile_x + offset.use_position[1], object.tile_y + offset.use_position[2]
    else
      tx, ty = object:getRenderAttachTile()
    end
    offset = offset.animation_offset
    humanoid:setTilePositionSpeed(tx, ty, offset[1], offset[2])
  else
    humanoid:setTilePositionSpeed(object.tile_x, object.tile_y, 0, 0)
  end
  
  humanoid.user_of = object
  local length = humanoid.world:getAnimLength(anim)
  local secondary_anim = action.anims.secondary and action.anims.secondary[anim_name]
  if action.secondary_anim then
    secondary_anim = action.secondary_anim
    action.secondary_anim = nil
  end
  local use_with = action.use_with
  if secondary_anim then
    if type(secondary_anim) == "table" and secondary_anim[1] == "morph" then
      use_with:setAnimation(secondary_anim[2], action.mirror_flags)
      local morph_target = TH.animation()
      morph_target:setAnimation(use_with.world.anims, secondary_anim[3], action.mirror_flags)
      for layer, id in pairs(use_with.layers) do
        morph_target:setLayer(layer, id)
      end
      if secondary_anim.layers then
        for layer, id in pairs(use_with[secondary_anim.layers]) do
          morph_target:setLayer(layer, id)
        end
        action.change_secondary_layers = use_with[secondary_anim.layers]
      end
      use_with.th:setMorph(morph_target)
      secondary_anim = secondary_anim[3]
    else
      use_with:setAnimation(secondary_anim, action.mirror_flags)
    end
    use_with.th:makeVisible()
    local secondary_length = use_with.world:getAnimLength(secondary_anim)
    if secondary_length > length then
      length = secondary_length
    end
  else
    use_with.th:makeInvisible()
  end
  humanoid:setTimer(length, action_multi_use_object_tick)
end

local function copy_layers(dest, src)
  if class.is(dest, Staff) then
    dest:setLayer(0, src.layers[0])
    dest:setLayer(1, src.layers[1])
    dest:setLayer(2, src.layers[2])
    dest:setLayer(3, src.layers[3])
    dest:setLayer(4, src.layers[4])
  elseif class.is(src, Staff) then
    dest:setLayer(5, src.layers[5])
  end
end

action_multi_use_object_tick = function(humanoid)
  local action = humanoid.action_queue[1]
  local use_with = action.use_with
  local object = action.object
  local phase = action.phase
  local oldphase = phase
  if phase ~= 0 or not action.prolonged_usage then
    phase = action_multi_use_next_phase(action, phase)
  elseif action.loop_callback then
    action:loop_callback()
  end
  if action.change_secondary_layers then
    for layer, id in pairs(action.change_secondary_layers) do
      use_with:setLayer(layer, id)
    end
    action.change_secondary_layers = nil
    copy_layers(humanoid, use_with)
  end
  if oldphase <= 2 and phase > 2 then
    object:setUser(nil)
    humanoid.user_of = nil
  end
  if phase == 100 then
    if action.layer3 then
      humanoid:setLayer(3, action.old_layer3_humanoid)
      use_with:setLayer(3, action.old_layer3_use_with)
    end
  
    use_with.th:makeVisible()
    use_with.action_queue[1].on_interrupt = action.idle_interrupt
    use_with.action_queue[1].must_happen = action.idle_must_happen
    local spec = object.object_type.orientations[object.direction]
    local pos = spec.finish_use_position or spec.use_position
    humanoid:setTilePositionSpeed(object.tile_x + pos[1], object.tile_y + pos[2])
    pos = spec.finish_use_position_secondary or spec.use_position_secondary
    use_with:setTilePositionSpeed(object.tile_x + pos[1], object.tile_y + pos[2])
    if action.after_use then
      action.after_use()
    end
    humanoid:finishAction(action)
  else
    action_multi_use_phase(action, humanoid, phase)
  end
end

local function action_multi_use_object_interrupt(action, humanoid)
  if not action.loop_callback then
    action.prolonged_usage = false
  end
end

local function action_multi_use_object_start(action, humanoid)
  local use_with = action.use_with
  if action.must_happen then
    -- Setting must_happen is slightly dangerous (though required in some
    -- situations), as the multi-usage cannot be sure to happen until the
    -- secondary user is present (at which point, must_happen is always set).
    if action.todo_interrupt then
      humanoid:finishAction(action)
      return
    end
  end
  if use_with.action_queue[1].name ~= "idle" then
    humanoid:queueAction({name = "idle", count = 2}, 0)
    return
  else
    action.idle_interrupt = use_with.action_queue[1].on_interrupt
    action.idle_must_happen = use_with.action_queue[1].must_happen
    use_with.action_queue[1].on_interrupt = nil
    use_with.action_queue[1].must_happen = true
  end
  action.must_happen = true
  if action.prolonged_usage then
    action.on_interrupt = action_multi_use_object_interrupt
    use_with.action_queue[1].on_interrupt = function()
      action:on_interrupt()
      action.on_interrupt = nil
    end
  end
  local object = action.object
  local orient = object.direction
  local flags = 0
  local anim_set = humanoid.humanoid_class .. " - " .. use_with.humanoid_class
  if not object.object_type.multi_usage_animations[anim_set][orient] then
    orient = orient_mirror[orient]
    flags = flags + 1
  end
  local spec = object.object_type.orientations[object.direction]
  -- early_list_while_in_use (if defined) will take precedence over early_list
  if spec.early_list_while_in_use or (spec.early_list_while_in_use == nil and spec.early_list) then
    flags = flags + 1024
  end
  local anims = object.object_type.multi_usage_animations[anim_set][orient]
  action.anims = anims
  action.mirror_flags = flags
  
  object:setUser(humanoid)
  humanoid.user_of = object
  copy_layers(humanoid, use_with)
  if action.layer3 then
    action.old_layer3_humanoid = humanoid.layers[3]
    action.old_layer3_use_with = use_with.layers[3]
    humanoid:setLayer(3, action.layer3)
    use_with:setLayer(3, action.layer3)
  end
  
  action_multi_use_phase(action, humanoid, action_multi_use_next_phase(action, -100))
end

return action_multi_use_object_start