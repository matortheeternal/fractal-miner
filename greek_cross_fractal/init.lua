-- Parameters
local YWATER = -31000
local cross_size = 9 -- use an odd value >= 5
local fractal_iteration = 7 -- see chart
local DEBUG = true
local fractal_block = minetest.get_content_id("default:sandstonebrick")

--[[
## greek cross fractal size chart

The maximum fractal iteration you can use depends on the
cross_size you use.  This chart shows the maximum
iteration for several cross_size values.  You can
calculate the fractal size for a given size and iteration
using the formula on line 35.

| cross_size | fractal_iteration | fractal_size |
|------------|-------------------|--------------|
| 5          | 13                | 49151        |
| 7          | 12                | 32767        |
| 9          | 12                | 40959        |
| 11         | 12                | 49151        |
| 13         | 12                | 57343        |
| 15         | 11                | 32767        |
| 17         | 11                | 36863        |
| 19         | 11                | 40960        |
| 21         | 11                | 45055        |
| 23         | 11                | 49151        |
| 25         | 11                | 53247        |
| 27         | 11                | 57343        |

]]--

-- Set mapgen parameters
local fractal_size = (cross_size + 1) * math.pow(2, fractal_iteration) - 1
local fractal_side = (fractal_size - 1) / 2
local fractal_origin = 0 - fractal_side
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[greek_cross_fractal] origin: "..fractal_origin)
  print ("[greek_cross_fractal] size: "..fractal_size)
end

-- Localise data buffer
local dbuf = {}


-- ####################################################### --
-- HELPER FUNCTIONS --

-- Generates text for a region's coordinates
function region_text(minp, maxp)
  return "("..minp.x..","..minp.y..","..minp.z..") to ("..maxp.x..","..maxp.y..","..maxp.z..")"
end

-- Tests if a point is outside of the object region
function outside_region(s, d, minp, maxp)
  return (maxp.x < s) or (maxp.y < s) or (maxp.z < s) 
      or (minp.x > s + d) or (minp.y > s + d) or (minp.z > s + d)
end


-- ####################################################### --
-- GREEK CROSS FRACTAL FUNCTIONS

-- Tests if a point is in the Greek Cross Fractal
function cross_test(d0, x, y, z)
  local d1 = (d0 - 1) / 2
  
  -- test if coords are in the set
  local xIn = x == 0
  local yIn = y == 0
  local zIn = z == 0
  
  if (math.abs(x) > d1) or (math.abs(y) > d1) or (math.abs(z) > d1) then
    return false
  elseif (xIn and yIn) or (yIn and zIn) or (xIn and zIn) then
    return true
  elseif d1 >= cross_size then
    local offset = (d1 - 1) / 2 + 1
    return cross_test(d1, x, y - offset, z) or -- top cross 
        cross_test(d1, x, y + offset, z) or -- bottom cross
        cross_test(d1, x - offset, y, z) or -- right cross
        cross_test(d1, x, y, z + offset) or -- front cross
        cross_test(d1, x + offset, y, z) or -- left cross 
        cross_test(d1, x, y, z - offset) -- back cross
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
    if DEBUG then
      print("[greek_cross_fractal] Skipping "..region_text(minp, maxp))
    end
  else
    if DEBUG then
      print ("[greek_cross_fractal] Generating blocks in "..region_text(minp, maxp))
    end
    
    -- Iterate over fixed region for the greek cross fractal
    local x1 = math.min(maxp.x, fractal_side)
    local y1 = math.min(maxp.y, fractal_side)
    local z1 = math.min(maxp.z, fractal_side)
    local x0 = math.max(minp.x, fractal_origin)
    local y0 = math.max(minp.y, fractal_origin)
    local z0 = math.max(minp.z, fractal_origin)

    for z = z0, z1 do
      for y = y0, y1 do
        local vi = area:index(x0, y, z)
        for x = x0, x1 do
          if cross_test(fractal_size, x, y, z) then
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
    print ("[greek_cross_fractal] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  player:setpos({x=0, y=fractal_side + 1, z=0})
end)