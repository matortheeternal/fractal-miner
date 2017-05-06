-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local fractal_iteration = 5 -- min value 1, max value 14
local DEBUG = true
local fix_spread = true
local fractal_block = minetest.get_content_id("default:dirt_with_snow")
local fix_spread_block = minetest.get_content_id("default:dirt")

-- Set mapgen parameters
local fractal_size = math.pow(2, fractal_iteration + 1) - 1
local fractal_side = (fractal_size - 1) / 2
local fractal_origin = 0 - fractal_side
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[hilbert_curve] origin: "..fractal_origin)
  print ("[hilbert_curve] size: "..fractal_size)
end

-- Localise data buffer
local dbuf = {}


-- ####################################################### --
-- HILBERT CURVE FUNCTIONS

-- tests if a point is inside of an iteration 1 hilbert curve centered at 0,0,0
function base_hilbert_test(x, y, z)
  return ((math.abs(x) == 1) and (math.abs(z) == 1)) or 
         ((y == 1) and (math.abs(x) == 1)) or 
         ((z == 1) and (y == -1))
end

-- Tests if a point is in the Hilbert Curve
function hilbert_test(d0, x, y, z)
  if d0 > 3 then
    local d1 = (d0 - 1) / 2
    local xz = (x == 0)
    local yz = (y == 0)
    local zz = (z == 0)
    local score = (xz and 1 or 0) + (yz and 1 or 0) + (zz and 1 or 0)
    if (score > 1) then
      return false
    elseif (score == 1) then
      return (yz and (x % d1 == 0) and (z % d1 == 0)) or -- y = 0 plane
             (xz and (y == -1) and (z == d1)) or -- x = 0 plane
             (zz and (y == 1) and (x % d1 == 0)) -- z = 0 plane
    else
      -- recursion
      local xp = x > 0
      local yp = y > 0
      local zp = z > 0
      local f = (d1 - 1) / 2 + 1
      if yp then 
        local q = (xp and 1 or -1)
        return hilbert_test(d1, q * (math.abs(z) - f), f + q * (0 - x), y - f)  
      else
        if zp then
          return hilbert_test(d1, f - math.abs(x), 0 - f - y, f - z)
        else
          local q = (xp and 1 or -1)
          return hilbert_test(d1, q * (math.abs(y) - f), f + z, f + q * (0 - x))
        end
      end
    end
  else
    return base_hilbert_test(x, y, z)
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
    debug_message(DEBUG, "[hilbert_curve] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[hilbert_curve] Generating blocks in "..region_text(minp, maxp))
    
    -- Iterate over fixed region for the hilbert curve
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size - 1)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
          if hilbert_test(fractal_size, x, y, z) then
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
    print ("[hilbert_curve] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  player:setpos({x=fractal_side, y=fractal_side + 1, z=fractal_side})
end)