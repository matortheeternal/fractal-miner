-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local fractal_iteration = 1 -- min value 1, max value 14
local DEBUG = true
local fix_spread = false
local fractal_block = minetest.get_content_id("default:stone")
local fix_spread_block = minetest.get_content_id("default:dirt")

-- Set mapgen parameters
local fractal_size = 2 * math.pow(3, fractal_iteration) - 1
local fractal_side = (fractal_size - 1) / 2
local fractal_origin = 0 - fractal_side
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[peano_curve] origin: "..fractal_origin)
  print ("[peano_curve] size: "..fractal_size)
end

-- Localise data buffer
local dbuf = {}


-- ####################################################### --
-- PEANO CURVE FUNCTIONS

-- tests if a point is inside of an iteration 1 peano curve centered at 0,0,0
function base_peano_test(x, y, z)
  if (math.abs(x) == 2) then
    return (y % 2 == 0) or (y * z == 2)
  elseif (math.abs(x) == 0) then
    return (z % 2 == 0) or (y * z == 2)
  else 
    return (x * z < 0) and (x * z * y == 4)
  end
end

-- Tests if a point is in the Peano Curve
function peano_test(d0, x, y, z)
  if d0 > 5 then
    -- TODO: RECURSION
  else
    return base_peano_test(x, y, z)
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
    debug_message(DEBUG, "[peano_curve] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[peano_curve] Generating blocks in "..region_text(minp, maxp))
    
    -- Iterate over fixed region for the peano curve
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size - 1)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
          if peano_test(fractal_size, x, y, z) then
            data[vi] = fractal_block
          end
          vi = vi + 1
        end
      end
    end
    
    if fix_spread then
      fix_spreading_blocks(data, area, minv, maxv, fix_spread_block)
    end
  end
  
  vm:set_data(data)
  vm:calc_lighting(minp, maxp)
  vm:write_to_map(data)

  if DEBUG then
    local chugent = math.ceil((os.clock() - t0) * 1000)
    print ("[peano_curve] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  player:setpos({x=fractal_side, y=fractal_side + 1, z=fractal_side})
end)