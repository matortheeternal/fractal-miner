-- Parameters
local YWATER = -31000
local pyramid_size = 7 -- use an odd value >= 3
local fractal_iteration = 5 -- see chart
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
    if DEBUG then
      print("[pyramid_fractal] Skipping "..region_text(minp, maxp))
    end
  else
    if DEBUG then
      print ("[pyramid_fractal] Generating blocks in "..region_text(minp, maxp))
    end
    
    -- Iterate over fixed region for the pyramid fractal
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