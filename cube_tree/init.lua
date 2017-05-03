-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local base_thickness = 1 -- use a value >= 1
local fractal_iteration = 6 -- max iteration is 13 - base_thickness
local DEBUG = true
local fractal_block = minetest.get_content_id("default:stone")
local octants = {0,0,0,0,1,1,1,1} -- the octants to recurse into

--[[
## about octants

The octants array is interpretted as shown below:

| x | z | y | index |
|---|---|---|-------|
| + | + | + |   0   |
| - | + | + |   1   |
| + | - | + |   2   |
| - | - | + |   3   |
| + | + | - |   4   |
| - | + | - |   5   |
| + | - | - |   6   |
| - | - | - |   7   |

Notable octant settings:
{1,0,0,0,0,0,0,0} (single tree)
{1,0,0,0,0,0,0,1} (diagonal tree)
{0,0,0,0,1,1,1,1} (vertical tree)
{1,1,1,0,1,0,0,0} (corner tree)
{1,1,0,0,0,0,1,1} (slant tree)
{1,0,0,1,0,1,1,0} (checkerboard tree)
{1,1,1,0,0,1,1,1} (stair tree)
{1,1,1,1,1,1,1,1} (full tree) 

]]--

-- Set mapgen parameters
local scale_rate = 10 * base_thickness + math.pow(2, base_thickness + 2)
local fractal_size = math.pow(2, fractal_iteration - 1) * scale_rate
local cube_size = math.pow(2, fractal_iteration - 1) * 10 * base_thickness
local max_thickness = math.pow(2, fractal_iteration - 1) * base_thickness
local max_offset = (fractal_size - cube_size) / 2
local fractal_side = fractal_size / 2
local fractal_height = fractal_size / 2
local fractal_origin = 0 - fractal_side + 1
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[cube_tree] origin: "..fractal_origin)
  print ("[cube_tree] size: "..fractal_size)
end

-- Localise data buffer
local dbuf = {}


-- ####################################################### --
-- CUBE TREE FUNCTIONS

-- Tests if a point is in a cube outline
function in_cube_outline(d, t, f, x, y, z)
  if (x < f) or (y < f) or (z < f) or (x >= f + d) or (y >= f + d) or (z >= f + d) then
    return false
  else
    local xIn = (x < f + t) or (x >= f + d - t)
    local yIn = (y < f + t) or (y >= f + d - t)
    local zIn = (z < f + t) or (z >= f + d - t)
    return (xIn and 1 or 0) + (yIn and 1 or 0) + (zIn and 1 or 0) >= 2
  end
end

-- Tests if an octant has been excluded from cube tree 
-- generation
function octant_excluded(d, x, y, z)
  local xp = (x >= d/2) and 1 or 0
  local yp = (y >= d/2) and 1 or 0
  local zp = (z >= d/2) and 1 or 0
  return octants[8 - (xp + zp * 2 + yp * 4)] == 0
end

-- Tests if a point is in the Cube Tree
function cube_test(d0, t0, f0, i, x, y, z)
  if in_cube_outline(d0, t0, f0, x, y, z) then
    return true
  elseif octant_excluded(d0 + 2 * f0, x, y, z) then
    return false
  elseif i > 1 then
    local d1 = d0 / 2
    local t1 = t0 / 2
    local f1 = f0 - math.pow(2, i)
    local r1 = d1 + 2 * f1
    return cube_test(d1, t1, f1, i - 1, x % r1, y % r1, z % r1)
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
    
    -- Iterate over fixed region for the cube tree
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size - 1)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
          if cube_test(cube_size, max_thickness, max_offset, fractal_iteration, x - fractal_origin, y - fractal_origin, z - fractal_origin) then
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
    print ("[cube_tree] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  local offset = fractal_origin + cube_size + max_offset - 1
  player:setpos({x=offset, y=offset + 1, z=offset})
end)