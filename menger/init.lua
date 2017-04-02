-- Parameters

local YWATER = -31000
local menger_size = 729
local DEBUG = true
local menger_block = minetest.get_content_id("default:stone")

-- Set mapgen parameters

minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

-- Localise data buffer

local dbuf = {}

-- Helper function, generates text for a region's coordinates

function region_text(minp, maxp)
  return "("..minp.x..","..minp.y..","..minp.z..") to ("..maxp.x..","..maxp.y..","..maxp.z..")"
end

-- Helper function, tests if a point is outside of the object region

function outside_region(d, minp, maxp)
  return (maxp.x < 0) or (maxp.y < 0) or (maxp.z < 0) 
      or (minp.x > d) or (minp.y > d) or (minp.z > d)
end

-- Helper function, tests if a point is in the Menger Sponge

function menger_test(d, x, y, z)
  local d3 = d / 3

  -- test if coords are outside of the set
  local xOut = (x >= d3) and (x < 2 * d3)
  local yOut = (y >= d3) and (y < 2 * d3)
  local zOut = (z >= d3) and (z < 2 * d3)

  -- if two Cartesian values are out of range, return false
  -- else, if d3 >= 3 recurse with d3 and modulused Cartesian values
  -- else, return true
  if (xOut and yOut) or (yOut and zOut) or (zOut and xOut) then
    return false
  elseif d3 >= 3 then
    return menger_test(d3, x % d3, y % d3, z % d3)
  else
    return true
  end
end

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
  local t0 = os.clock()

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
  local data = vm:get_data(dbuf)

  if outside_region(menger_size, minp, maxp) then
    if DEBUG then
      print("Skipping "..region_text(minp, maxp))
    end
  else
    if DEBUG then
      print ("Generating blocks in "..region_text(minp, maxp))
    end
    
    -- Iterate over fixed region for the menger sponge
    local x1 = math.min(maxp.x, menger_size)
    local y1 = math.min(maxp.y, menger_size)
    local z1 = math.min(maxp.z, menger_size)
    local x0 = math.max(minp.x, 0)
    local y0 = math.max(minp.y, 0)
    local z0 = math.max(minp.z, 0)

    for z = z0, z1 do
      for y = y0, y1 do
        local vi = area:index(x0, y, z)
        for x = x0, x1 do
          if menger_test(menger_size, x, y, z) then
            data[vi] = menger_block
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
    print ("[menger] "..chugent.." ms")
  end
end)
  
minetest.register_on_newplayer(function(player)
  local elevation = menger_size + 1
  player:setpos({x=0, y=elevation, z=0})
end)