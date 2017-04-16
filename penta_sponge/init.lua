-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local fractal_iteration = 4 -- min value 0, max value 6
local DEBUG = true
local fractal_block = minetest.get_content_id("default:stone")
local hollow = false

-- Set mapgen parameters
local fractal_size = math.pow(5, fractal_iteration)
local fractal_origin = math.floor(0 - fractal_size / 2)
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[penta_sponge] origin: "..fractal_origin)
  print ("[penta_sponge] size: "..fractal_size)
end

-- Localise data buffer
local dbuf = {}


-- ####################################################### --
-- PENTA SPONGE FUNCTIONS

-- Tests if a component is outside of the penta sponge
function ptc(c, d)
  return ((c < d) or (c >= 4 * d) or ((c >= 2 * d) and (c < 3 * d))) and 1 or 0
end

-- Tests if a component is in the central 3/5 cube 
function cct(c, d)
  return (c >= d) and (c < 4 * d)
end

-- Tests if a point is in the Penta Sponge
function penta_test(d, x, y, z)
  local d5 = d / 5

  -- test if coords are outside of the set
  local score = ptc(x, d5) + ptc(y, d5) + ptc(z, d5)
  local cube_test = hollow or not (cct(x, d5) and cct(y, d5) and cct(z, d5))

  -- if two or more Cartesian values are out of range, return false
  -- else, if d5 >= 5 recurse with d5 and modulused Cartesian values
  -- else, return true
  if (score >= 2) and cube_test then
    return false
  elseif d5 >= 5 then
    return penta_test(d5, x % d5, y % d5, z % d5)
  else
    return true
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
    debug_message(DEBUG, "[penta_sponge] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[penta_sponge] Generating blocks in "..region_text(minp, maxp))
    
    -- Iterate over fixed region for the penta sponge
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size - 1)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
          if penta_test(fractal_size, x - fractal_origin, y - fractal_origin, z - fractal_origin) then
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
    print ("[penta_sponge] "..chugent.." ms")
  end
end)
  
-- Player spawn point
-- 1,1 .. 6,6 .. 31,31 .. 156,156
minetest.register_on_newplayer(function(player)
  local elevation = fractal_origin + fractal_size + 1
  local offset = (math.pow(5, fractal_iteration) - 1) / 4
  player:setpos({x=offset, y=elevation, z=offset})
end)