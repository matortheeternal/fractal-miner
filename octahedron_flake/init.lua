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
using the formula on line 36.

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
    if DEBUG then
      print("[octahedron_flake] Skipping "..region_text(minp, maxp))
    end
  else
    if DEBUG then
      print ("[octahedron_flake] Generating blocks in "..region_text(minp, maxp))
    end
    
    -- Iterate over fixed region for the octahedron flake
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