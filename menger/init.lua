-- Parameters

local YWATER = -31000
local menger_size = 729
local DEBUG = true
local menger_block = minetest.get_content_id("default:stone")

-- Set mapgen parameters

minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

-- Localise data buffer

local dbuf = {}

-- Helper function, tests if a point is in the Menger Sponge

function menger_test(d, x, y, z)
  if (x < d) and (y < d) and (z < d) and (x >= 0) and (y >= 0) and (z >= 0) then
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
  else
    return false
  end
end

-- On generated function

minetest.register_on_generated(function(minp, maxp, seed)
  local t0 = os.clock()

  local x1 = maxp.x
  local y1 = maxp.y
  local z1 = maxp.z
  local x0 = minp.x
  local y0 = minp.y
  local z0 = minp.z

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
  local data = vm:get_data(dbuf)

  if (x1 < 0) or (y1 < 0) or (z1 < 0) or (x0 > menger_size) or (y0 > menger_size) or (z0 > menger_size) then
    if DEBUG then
      print("Skipping ("..x0..","..y0..","..z0..") to ("..x1..","..y1..","..z1..")")
    end
  else
    if DEBUG then
      print ("Placing blocks at ("..x0..","..y0..","..z0..") to ("..x1..","..y1..","..z1..")")
    end

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
  vm:calc_lighting({x = x0, y = y0, z = z0}, {x = x1, y = y1, z = z1})
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