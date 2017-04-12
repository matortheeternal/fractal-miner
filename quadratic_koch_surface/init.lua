-- Parameters
local YWATER = -31000
local fractal_iteration = 7 -- max value 10
local DEBUG = true
local fractal_block = minetest.get_content_id("default:stone")

-- Set mapgen parameters
local fractal_size = math.pow(3, fractal_iteration)
local fractal_side = (fractal_size - 1) / 2
local fractal_height = (fractal_size - 1) / 2
local fractal_y_origin = 0 - math.floor(fractal_height / 2)
local fractal_origin = 0 - fractal_side
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[quadratic_koch_surface] origin: "..fractal_origin)
  print ("[quadratic_koch_surface] y_origin: "..fractal_y_origin)
  print ("[quadratic_koch_surface] size: "..fractal_size)
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

-- Tests if a point is in the Quadratic Koch Surface
function koch_test(d0, x, y, z)
  local d3 = d0 / 3
  
  -- test if coords are inside of the set
  local xOut = (x < d3) or (x >= 2 * d3)
  local yOut = y >= (2 * d3)
  local zOut = (z < d3) or (z >= 2 * d3)
  local yIn = y < d3
  local xzOut = xOut or zOut
  
  if y < 0 then
    return false
  elseif yIn and not xzOut then
    return true
  elseif yOut or (xzOut and not yIn) then
    return false
  elseif d3 >= 3 then
    local x3 = x % d3
    local y3 = y % d3
    local z3 = z % d3
    local baseTest = koch_test(d3, x3, y3, z3)
    if (xOut and zOut) or (not yIn) or baseTest then
      return baseTest
    elseif xOut then
      if x < d3 then
        return koch_test(d3, y3, d3 - x3 - 1, z3) -- test left side
      else
        return koch_test(d3, y3, x3, z3) -- test right side
      end
    else
      if z < d3 then
        return koch_test(d3, x3, d3 - z3 - 1, y3) -- test front side
      else
        return koch_test(d3, x3, z3, y3) -- test back side
      end
    end
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
      print("[quadratic_koch_surface] Skipping "..region_text(minp, maxp))
    end
  else
    if DEBUG then
      print ("[quadratic_koch_surface] Generating blocks in "..region_text(minp, maxp))
    end
    
    -- Iterate over fixed region for the quadratic koch surface
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
          if koch_test(fractal_size, x - fractal_origin, y - fractal_y_origin, z - fractal_origin) then
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
    print ("[quadratic_koch_surface] "..chugent.." ms")
  end
end)
  
-- Player spawn point
minetest.register_on_newplayer(function(player)
  local elevation = fractal_y_origin + fractal_height + 1
  player:setpos({x=0, y=elevation, z=0})
end)