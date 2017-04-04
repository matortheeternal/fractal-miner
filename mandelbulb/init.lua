-- Parameters
local YWATER = -31000
local fractal_size = 512    -- max value 62000
local base_iteration = 4    -- the iteration at which we should start placing blocks
local power = 8             -- the mandelbulb power multiplier
local fallout = 1024        -- the value at which we should consider a point in the mandelbulb
local DEBUG = true

-- Test Palette
local fractal_palette = {
  minetest.get_content_id("default:stone"),
  minetest.get_content_id("wool:white"),
  minetest.get_content_id("wool:grey"),
  minetest.get_content_id("wool:dark_grey"),
  minetest.get_content_id("wool:black"),
  minetest.get_content_id("wool:red"),
  minetest.get_content_id("wool:orange"),
  minetest.get_content_id("wool:yellow"),
  minetest.get_content_id("wool:green"),
  minetest.get_content_id("wool:dark_green"),
  minetest.get_content_id("wool:blue"),
  minetest.get_content_id("wool:cyan"),
  minetest.get_content_id("wool:pink"),
  minetest.get_content_id("wool:magenta"),
  minetest.get_content_id("wool:violet"),
  minetest.get_content_id("wool:brown")
}
local iterations = 12 -- must not exceed palette length

-- Set mapgen parameters
local fractal_origin = math.floor(0 - fractal_size / 2)
local max_iteration = base_iteration + iterations
minetest.set_mapgen_params({mgname = "singlenode", flags = "nolight", water_level = YWATER})

if DEBUG then
  print ("[mandelbulb] origin: "..fractal_origin)
  print ("[mandelbulb] size: "..fractal_size)
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

-- Gets the magnitude of a vector

function vector_magnitude(v)
  return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- Adds two vectors together
function vector_add(v1, v2)
  return {
    x = v1.x + v2.x,
    y = v1.y + v2.y,
    z = v1.z + v2.z
  }
end

-- Gets the theta value of a vector (circular coordinates)
local tiny_value = 0.0000001 -- used to avoid division by zero
function theta(v)
  return math.acos(v.z / (vector_magnitude(v) + tiny_value))
end

-- Gets the phi value of a vector (circular coordinates)
function phi(v)
  return math.atan(v.y / (v.x + tiny_value))
end


-- ####################################################### --
-- MANDELBULB FUNCTIONS

-- Applies the mandelbulb formula to a vector
function formula(v, n)
  local t = theta(v)
  local p = phi(v)
  local k = math.pow(vector_magnitude(v), n)
  return {
    x = k * math.sin(n * t) * math.cos(n * p),
    y = k * math.sin(n * t) * math.sin(n * p),
    z = k * math.cos(n * t)
  }
end

-- Tests if a point is in the mandelbulb
function mandelbulb_test(d, x, y, z)
  local C = {
    x = (2 * x / d) - 1,
    y = (2 * y / d) - 1,
    z = (2 * z / d) - 1
  }
  local Z = {x=0, y=0, z=0}
  local n = -1
  local fallout_exceeded = false
  
  -- fold points until they fallout or we reach the maximum iteration
  while (not fallout_exceeded) and (n < max_iteration) do
    Z = vector_add(formula(Z, power), C)
    n = n + 1
    fallout_exceeded = (vector_magnitude(Z) > fallout)
  end
  
  -- return index of iteration we fell out on
  if fallout_exceeded then
    return n - base_iteration
  else 
    return -1
  end
end


-- ####################################################### --
-- Minetest hooks

-- On generated function
minetest.register_on_generated(function(minp, maxp, seed)
  local t0 = os.clock()

  local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
  local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
  local data = vm:get_data(dbuf)

  if outside_region(fractal_origin, fractal_size, minp, maxp) then
    if DEBUG then
      print("[mandelbulb] Skipping "..region_text(minp, maxp))
    end
  else
    if DEBUG then
      print ("[mandelbulb] Generating blocks in "..region_text(minp, maxp))
    end
    
    -- Iterate over fixed region for the cantor dust
    local x1 = math.min(maxp.x, fractal_origin + fractal_size)
    local y1 = math.min(maxp.y, fractal_origin + fractal_size)
    local z1 = math.min(maxp.z, fractal_origin + fractal_size)
    local x0 = math.max(minp.x, fractal_origin)
    local y0 = math.max(minp.y, fractal_origin)
    local z0 = math.max(minp.z, fractal_origin)

    for z = z0, z1 do
      for y = y0, y1 do
        local vi = area:index(x0, y, z)
        for x = x0, x1 do
          local n = mandelbulb_test(fractal_size, x - fractal_origin, y - fractal_origin, z - fractal_origin) 
          if n > -1 then
            data[vi] = fractal_palette[n + 1]
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
    print ("[mandelbulb] "..chugent.." ms")
  end
end)

-- TODO: should generate a 3x3 glass platform at elevation + 2 for player to stand on
minetest.register_on_newplayer(function(player)
  local elevation = fractal_origin + fractal_size + 1
  local offset = 0.06 * fractal_size
  player:setpos({x=-offset, y=elevation, z=offset})
end)