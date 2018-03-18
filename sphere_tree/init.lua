-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local scale = 1 -- 1 <= scale < 15
local fractal_iteration = 7 -- max value is 15 - scale
local DEBUG = true

-- Test Palette
local fractal_palette = {
  minetest.get_content_id("wool:cyan"),
  minetest.get_content_id("wool:blue"),
  minetest.get_content_id("wool:green"),
  minetest.get_content_id("wool:yellow"),
  minetest.get_content_id("wool:orange"),
  minetest.get_content_id("wool:red"),
  minetest.get_content_id("wool:violet"),
  minetest.get_content_id("wool:magenta"),
  minetest.get_content_id("wool:pink"),
  minetest.get_content_id("wool:white"),
  minetest.get_content_id("wool:grey"),
  minetest.get_content_id("wool:black"),
  minetest.get_content_id("wool:brown")
}

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

local function get_level_from_size(d)
  local level = 0
  while d > sphere_size do
    d = (d + 1) / 2 - 1
    level = level + 1
  end
  return level
end

local function get_block_from_radius(radius)
  local level = get_level_from_size(radius * 2 + 1)
  return fractal_palette[level % #fractal_palette]
end

local function box_in_sphere(minp, maxp, pos, rad)
  local x = math.min(math.max(pos.x, minp.x), maxp.x)
  local y = math.min(math.max(pos.y, minp.y), maxp.y)
  local z = math.min(math.max(pos.z, minp.z), maxp.z)
  return (x-pos.x)^2 + (y-pos.y)^2 + (z-pos.z)^2 <= rad^2
end

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
  local zmin = math.max(math.ceil(center.z-sphere_radius), minp.z) -- Minimum and maximum Z bounds of the sphere
  local zmax = math.min(math.floor(center.z+sphere_radius), maxp.z)
  for z = zmin, zmax do
    local zdist = center.z - z
    local disc_radius2 = sphere_radius^2 - zdist^2 -- Intersection between the Z plane and the sphere is a disc, whose radius can be calculated using Pythagorean theorem.
    local disc_radius = math.sqrt(disc_radius2)
    local ymin = math.max(math.ceil(center.y-disc_radius), minp.y) -- Minimum and maximum Y bounds of the disc
    local ymax = math.min(math.floor(center.y+disc_radius), maxp.y)
    for y = ymin, ymax do
      local ydist = center.y - y
      local line_radius = math.sqrt(disc_radius2 - ydist^2) -- Intersection between the disc and the straight line at Y and Z constants and X variable is a short line between 2 X coordiantes that are calculated using Pythagorean theorem.
      local xmin = math.max(math.ceil(center.x-line_radius), minp.x) -- Minimum and maximum Z bounds of the line
      local xmax = math.min(math.floor(center.x+line_radius), maxp.x)
      local i = a:index(xmin, y, z)
      for x = xmin, xmax do
        data[i] = c
        i = i + 1
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
  if #spheres == 0 then
    debug_message(DEBUG, "[sphere_tree] Skipping "..region_text(minp, maxp))
  else
    print("[sphere_tree] " .. #spheres .. " spheres to generate")

    for _, sphere in ipairs(spheres) do
      local center, radius = unpack(sphere)
      local fractal_block = get_block_from_radius(radius)
      generate_sphere(data, area, minp, maxp, center, radius, fractal_block)
    end

    vm:set_data(data)
    vm:calc_lighting(minp, maxp)
    vm:write_to_map(data)

    if DEBUG then
      local chugent = math.ceil((os.clock() - t0) * 1000)
      print ("[sphere_tree] "..chugent.." ms")
    end
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  player:setpos({x=0, y=fractal_side + 1, z=0})
end)