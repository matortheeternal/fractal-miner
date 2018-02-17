-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local scale = 3 -- 1 <= scale < 15
local fractal_iteration = 7 -- max value is 15 - sphere_size
local DEBUG = true
local fractal_block = minetest.get_content_id("default:sandstonebrick")

-- Constants
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
end

-- Localize data buffer
local dbuf = {}


-- ####################################################### --
-- SPHERE TREE FUNCTIONS

-- Tests if a point is in a sphere
function in_sphere(r, x, y, z)
  return math.pow(x, 2) + math.pow(y, 2) + math.pow(z, 2) <= math.pow(r, 2)
end

-- Tests if a point is in the Sphere Tree
function sphere_test(d0, r, x, y, z)
  local d1 = (d0 + 1) / 2 - 1
  local radius = d0 / 2.0
  if in_sphere(radius, x, y, z) then
    return true
  elseif d0 > sphere_size then
    local offset = d1 + (d1 + 1) / 2
    local lp = sqrt2i * radius
    local ln = 0 - lp
    return (y > lp and r ~= 1 and sphere_test(d1, 2, x, y - offset, z)) or -- top sphere
      (y < ln and r ~= 2 and sphere_test(d1, 1, x, y + offset, z)) or -- bottom sphere
      (x > lp and r ~= 3 and sphere_test(d1, 4, x - offset, y, z)) or -- right sphere
      (x < ln and r ~= 4 and sphere_test(d1, 3, x + offset, y, z)) or -- left sphere
      (z > lp and r ~= 5 and sphere_test(d1, 6, x, y, z - offset)) or -- front sphere
      (z < ln and r ~= 6 and sphere_test(d1, 5, x, y, z + offset)) -- back sphere
  else 
    return false
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

  if outside_region(fractal_origin, fractal_size, minp, maxp) then
    debug_message(DEBUG, "[cube_tree] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[cube_tree] Generating blocks in "..region_text(minp, maxp))
    
    -- Iterate over fixed region for the sphere tree
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size - 1)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
          if sphere_test(base_size, 0, x, y, z) then
            data[vi] = fractal_block
          end
          vi = vi + 1
        end
      end
    end
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