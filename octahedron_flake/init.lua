-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

-- Parameters
local YWATER = -31000
local octahedron_size = 7 -- use an odd value >= 3
local fractal_iteration = 7 -- see chart
local DEBUG = true
local fractal_block = minetest.get_content_id("default:stone")

--[[
## octahedron flake size chart

The maximum fractal iteration you can use depends on the
octahedron_size you use.  This chart shows the maximum
iteration for several octahedron_size values.  You can
calculate the fractal size for a given size and iteration
using the formula on line 39.

| octahedron_size | fractal_iteration | fractal_size |
|-----------------|-------------------|--------------|
| 3               | 13                | 32767        |
| 5               | 13                | 49151        |
| 7               | 12                | 32767        |
| 9               | 12                | 40959        |
| 11              | 12                | 49151        |
| 13              | 12                | 57343        |
| 15              | 11                | 32767        |
| 17              | 11                | 36863        |
| 19              | 11                | 40960        |
| 21              | 11                | 45055        |
| 23              | 11                | 49151        |
| 25              | 11                | 53247        |
| 27              | 11                | 57343        |

]]--

-- Set mapgen parameters
local fractal_size = (octahedron_size + 1) * math.pow(2, fractal_iteration) - 1
local fractal_side = (fractal_size - 1) / 2
local fractal_origin = 0 - fractal_side
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[octahedron_flake] origin: "..fractal_origin)
  print ("[octahedron_flake] size: "..fractal_size)
end

-- Localise data buffer
local dbuf = {}


-- ####################################################### --
-- OCTAHEDRON FLAKE FUNCTIONS

-- Tests if a point is in the Octahedron Flake
function octahedron_test(d0, x, y, z)
  local d1 = (d0 - 1) / 2
  local max_x = (d0 - 2 * math.abs(y) - 2 * math.abs(z) - 1) / 2

  if (math.abs(x) > max_x) then
    return false;
  elseif d1 >= octahedron_size then
    local offset = (d1 - 1) / 2 + 1
    return octahedron_test(d1, x, y - offset, z) or -- top octahedron 
        octahedron_test(d1, x, y + offset, z) or -- bottom octahedron
        octahedron_test(d1, x - offset, y, z) or -- right octahedron
        octahedron_test(d1, x, y, z + offset) or -- front octahedron
        octahedron_test(d1, x + offset, y, z) or -- left octahedron 
        octahedron_test(d1, x, y, z - offset) -- back octahedron
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
    debug_message(DEBUG, "[octahedron_flake] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[octahedron_flake] Generating blocks in "..region_text(minp, maxp))
    
    -- Iterate over fixed region for the octahedron flake
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size - 1)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
          if octahedron_test(fractal_size, x, y, z) then
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
    print ("[octahedron_flake] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  player:setpos({x=0, y=fractal_side + 1, z=0})
end)