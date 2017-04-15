-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local pyramid_size = 7 -- use an odd value >= 3
local fractal_iteration = 8 -- see chart
local DEBUG = true
local fractal_block = minetest.get_content_id("default:stone")

--[[
## pyramid fractal size chart

The maximum fractal iteration you can use depends on the
pyramid_size you use.  This chart shows the maximum
iteration for several pyramid_size values.  You can
calculate the fractal size for a given size and iteration
using the formula on line 36.

| pyramid_size | fractal_iteration | fractal_size |
|--------------|-------------------|--------------|
| 3            | 13                | 32767        |
| 5            | 13                | 49151        |
| 7            | 12                | 32767        |
| 9            | 12                | 40959        |
| 11           | 12                | 49151        |
| 13           | 12                | 57343        |
| 15           | 11                | 32767        |
| 17           | 11                | 36863        |
| 19           | 11                | 40960        |
| 21           | 11                | 45055        |
| 23           | 11                | 49151        |
| 25           | 11                | 53247        |
| 27           | 11                | 57343        |

]]--

-- Set mapgen parameters
local fractal_size = (pyramid_size + 1) * math.pow(2, fractal_iteration) - 1
local fractal_side = (fractal_size - 1) / 2
local fractal_height = (fractal_size + 1) / 2
local fractal_y_origin = 0 - math.floor(fractal_height / 2)
local fractal_origin = 0 - fractal_side
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[pyramid_fractal] origin: "..fractal_origin)
  print ("[pyramid_fractal] y_origin: "..fractal_y_origin)
  print ("[pyramid_fractal] size: "..fractal_size)
end

-- Localise data buffer
local dbuf = {}


-- ####################################################### --
-- PYRAMID FRACTAL FUNCTIONS

-- Tests if a point is in the Pyramid Fractal
function pyramid_test(d0, x, y, z)
  local d1 = (d0 - 1) / 2
  local max_x = (d0 - 2 * y - 2 * math.abs(z) - 1) / 2

  if (y < 0) or (math.abs(x) > max_x) then
    return false;
  elseif d1 >= pyramid_size then
    local offset = (d1 - 1) / 2 + 1
    return pyramid_test(d1, x, y - offset, z) or -- top pyramid 
        pyramid_test(d1, x - offset, y, z) or -- right pyramid
        pyramid_test(d1, x, y, z + offset) or -- front pyramid
        pyramid_test(d1, x + offset, y, z) or -- left pyramid 
        pyramid_test(d1, x, y, z - offset) -- back pyramid
  else
    return true;
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
    debug_message(DEBUG, "[pyramid_fractal] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[pyramid_fractal] Generating blocks in "..region_text(minp, maxp))
    
    -- Iterate over fixed region for the pyramid fractal
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size - 1)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
          if pyramid_test(fractal_size, x, y - fractal_y_origin, z) then
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
    print ("[pyramid_fractal] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  local elevation = fractal_y_origin + fractal_height + 1
  player:setpos({x=0, y=elevation, z=0})
end)