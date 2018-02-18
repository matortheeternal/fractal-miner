-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local scale = 3 -- 1 <= scale < 15
local fractal_iteration = 7 -- max value is 15 - scale
local DEBUG = true
local fractal_block = minetest.get_content_id("default:sandstonebrick")

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
end

-- Localize data buffer
local dbuf = {}


-- ####################################################### --
-- SPHERE TREE FUNCTIONS

local function box_in_sphere(minp, maxp, pos, rad)
  local x = math.min(math.max(pos.x, minp.x), maxp.x)
  local y = math.min(math.max(pos.y, minp.y), maxp.y)
  local z = math.min(math.max(pos.z, minp.z), maxp.z)
  return (x-pos.x)^2 + (y-pos.y)^2 + (z-pos.z)^2 <= rad^2
end

local min_sphere_size = 2
local first_radius = 256

local function list_spheres(t, minp, maxp, d0, center, r)
  if box_in_sphere(minp, maxp, center, d0*1.5) then
    local radius = d0 / 2.0
    if box_in_sphere(minp, maxp, center, radius) then
      table.insert(t, {center, radius})
    end
    local newradius = radius / 2
    if d0 <= sphere_size then
      return
    end
    local d1 = (d0 + 1) / 2 - 1
    local offset = d1 + (d1 + 1) / 2
    local influence_zone = radius*0.75 -- Influence zone of child spheres at a given direction begin at 3/4 radius in this direction
    if r ~= 1 and maxp.y >= center.y + influence_zone then
      list_spheres(t, minp, maxp, d1, {x=center.x, y=center.y+offset, z=center.z}, 2) -- Top
    end
    if r ~= 2 and minp.y <= center.y - influence_zone then
      list_spheres(t, minp, maxp, d1, {x=center.x, y=center.y-offset, z=center.z}, 1) -- Bottom
    end
    if r ~= 3 and maxp.x >= center.x + influence_zone then
      list_spheres(t, minp, maxp, d1, {x=center.x+offset, y=center.y, z=center.z}, 4) -- East
    end
    if r ~= 4 and minp.x <= center.x - influence_zone then
      list_spheres(t, minp, maxp, d1, {x=center.x-offset, y=center.y, z=center.z}, 3) -- West
    end
    if r ~= 5 and maxp.z >= center.z + influence_zone then
      list_spheres(t, minp, maxp, d1, {x=center.x, y=center.y, z=center.z+offset}, 6) -- North
    end
    if r ~= 6 and minp.z <= center.z - influence_zone then
      list_spheres(t, minp, maxp, d1, {x=center.x, y=center.y, z=center.z-offset}, 5) -- South
    end
  end
end

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

  debug_message(DEBUG, "[sphere_tree] Generating blocks in "..region_text(minp, maxp))
  
  local spheres = {}
  list_spheres(spheres, minp, maxp, base_size, {x=0,y=0,z=0})
  print("[sphere_tree] " .. #spheres .. " spheres to generate")

  for _, sphere in ipairs(spheres) do
    local center, radius = unpack(sphere)
    generate_sphere(data, area, minp, maxp, center, radius, fractal_block)
  end

  vm:set_data(data)
  vm:calc_lighting(minp, maxp)
  vm:write_to_map(data)

  if DEBUG then
    local chugent = math.ceil((os.clock() - t0) * 1000)
    print ("[sphere_tree] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  player:setpos({x=0, y=fractal_side + 1, z=0})
end)
