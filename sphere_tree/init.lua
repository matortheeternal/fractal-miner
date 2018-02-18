--[[-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local scale = 3 -- 1 <= scale < 15
local fractal_iteration = 7 -- max value is 15 - scale
local DEBUG = true]]
local fractal_block = minetest.get_content_id("default:sandstonebrick")

--[[-- Constants
local sqrt2i = 1.0 / math.sqrt(2)

-- Set mapgen parameters
local sphere_size = math.pow(2, scale) - 1
local rate = fractal_iteration + scale - 1
local base_size = math.pow(2, rate) - 1
local scale_offset = math.pow(2, scale + 1) - 2 * (scale + 1)
local fractal_size = 3 * (math.pow(2, rate) - 1) - 2 * fractal_iteration - scale_offset
local fractal_side = (fractal_size - 1) / 2
local fractal_origin = 0 - fractal_side
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[sphere_tree] origin: "..fractal_origin)
  print ("[sphere_tree] size: "..fractal_size)
end]]

-- Localize data buffer
local dbuf = {}


-- ####################################################### --
-- SPHERE TREE FUNCTIONS

--[[local function boxes_intersect(minp1, maxp1, minp2, maxp2)
  return math.min(maxp1.x, maxp2.x) > math.max(minp1.x, minp2.x)
     and math.min(maxp1.y, maxp2.y) > math.max(minp1.y, minp2.y)
     and math.min(maxp1.z, maxp2.z) > math.max(minp1.z, minp2.z)
end]]

local function box_in_sphere(minp, maxp, pos, rad)
  local x = math.min(math.max(pos.x, minp.x), maxp.x)
  local y = math.min(math.max(pos.y, minp.y), maxp.y)
  local z = math.min(math.max(pos.z, minp.z), maxp.z)
  return (x-pos.x)^2 + (y-pos.y)^2 + (z-pos.z)^2 <= rad^2
end

-- Tests if a point is in a sphere
--[[function in_sphere(r, x, y, z)
  return math.pow(x, 2) + math.pow(y, 2) + math.pow(z, 2) <= math.pow(r, 2)
end]]

local min_sphere_size = 2
local first_radius = 256

local function list_spheres(t, minp, maxp, radius, center, r)
  if box_in_sphere(minp, maxp, center, radius*3) then
    if box_in_sphere(minp, maxp, center, radius) then
      table.insert(t, {center, radius})
    end
    local newradius = radius / 2
    if newradius < min_sphere_size then
      return
    end
    local offset = radius*1.5
    local influence_zone = radius*0.75 -- Influence zone of child spheres at a given direction begin at 3/4 radius in this direction
    if r ~= 1 and maxp.y >= center.y + influence_zone then
      list_spheres(t, minp, maxp, newradius, {x=center.x, y=center.y+offset, z=center.z}, 2) -- Top
    end
    if r ~= 2 and minp.y <= center.y - influence_zone then
      list_spheres(t, minp, maxp, newradius, {x=center.x, y=center.y-offset, z=center.z}, 1) -- Bottom
    end
    if r ~= 3 and maxp.x >= center.x + influence_zone then
      list_spheres(t, minp, maxp, newradius, {x=center.x+offset, y=center.y, z=center.z}, 4) -- East
    end
    if r ~= 4 and minp.x <= center.x - influence_zone then
      list_spheres(t, minp, maxp, newradius, {x=center.x-offset, y=center.y, z=center.z}, 3) -- West
    end
    if r ~= 5 and maxp.z >= center.z + influence_zone then
      list_spheres(t, minp, maxp, newradius, {x=center.x, y=center.y, z=center.z+offset}, 6) -- North
    end
    if r ~= 6 and minp.z <= center.z - influence_zone then
      list_spheres(t, minp, maxp, newradius, {x=center.x, y=center.y, z=center.z-offset}, 5) -- South
    end
  end
end


-- Tests if a point is in the Sphere Tree
--[[function sphere_test(d0, r, x, y, z)
  local d1 = (d0 + 1) / 2 - 1
  local radius = d0 / 2.0
  if in_sphere(radius, x, y, z) then
    return true
  elseif d0 > sphere_size then
    local offset = d1 + (d1 + 1) / 2
    local lp = sqrt2i * radius
    local ln = -lp
    return (y > lp and r ~= 1 and sphere_test(d1, 2, x, y - offset, z)) or -- top sphere
      (y < ln and r ~= 2 and sphere_test(d1, 1, x, y + offset, z)) or -- bottom sphere
      (x > lp and r ~= 3 and sphere_test(d1, 4, x - offset, y, z)) or -- right sphere
      (x < ln and r ~= 4 and sphere_test(d1, 3, x + offset, y, z)) or -- left sphere
      (z > lp and r ~= 5 and sphere_test(d1, 6, x, y, z - offset)) or -- front sphere
      (z < ln and r ~= 6 and sphere_test(d1, 5, x, y, z + offset)) -- back sphere
  else 
    return false
  end
end]]

local function generate_sphere(data, a, minp, maxp, center, sphere_radius, c)
  local xmin = math.max(math.ceil(center.x-sphere_radius), minp.x)
  local xmax = math.min(math.floor(center.x+sphere_radius), maxp.x)
  for x = xmin, xmax do
    local xdist = center.x - x
    local circle_radius2 = sphere_radius^2 - xdist^2
    local circle_radius = math.sqrt(circle_radius2)
    local ymin = math.max(math.ceil(center.y-circle_radius), minp.y)
    local ymax = math.min(math.floor(center.y+circle_radius), maxp.y)
    for y = ymin, ymax do
      local ydist = center.y - y
      local line_radius = math.sqrt(circle_radius2 - ydist^2)
      local zmin = math.max(math.ceil(center.z-line_radius), minp.z)
      local zmax = math.min(math.floor(center.z+line_radius), maxp.z)
      for z = zmin, zmax do
        i = a:index(x, y, z)
        data[i] = c
      end
    end
  end
end

-- ####################################################### --
-- Minetest hooks

-- Chunk generation function
minetest.register_on_generated(function(minp, maxp, seed)
  local t0 = os.clock()

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
  local data = vm:get_data(dbuf)

  --[[if outside_region(fractal_origin, fractal_size, minp, maxp) then
    debug_message(DEBUG, "[cube_tree] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[cube_tree] Generating blocks in "..region_text(minp, maxp))]]
    
    local spheres = {}
    list_spheres(spheres, minp, maxp, first_radius, {x=0,y=0,z=0})
    print("[cube_tree] " .. #spheres .. " spheres to generate")

    for _, sphere in ipairs(spheres) do
      local center, radius = unpack(sphere)
      generate_sphere(data, area, minp, maxp, center, radius, fractal_block)
    end
  --end
  vm:set_data(data)
  vm:calc_lighting(minp, maxp)
  vm:write_to_map(data)

  if DEBUG then
    local chugent = math.ceil((os.clock() - t0) * 1000)
    print ("[sphere_tree] "..chugent.." ms")
  end
end)
  
-- Player spawn point
--[[minetest.register_on_newplayer(function(player)
  player:setpos({x=0, y=fractal_side + 1, z=0})
end)]]
