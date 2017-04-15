-- Import Helpers
dofile(minetest.get_modpath("fractal_helpers").."/helpers.lua")

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
    debug_message(DEBUG, "[mandelbulb] Skipping "..region_text(minp, maxp))
  else
    debug_message(DEBUG, "[mandelbulb] Generating blocks in "..region_text(minp, maxp))
    
    -- Iterate over fixed region for the cantor dust
    local minv, maxv = get_fractal_region(minp, maxp, fractal_origin, fractal_size)

    for z = minv.z, maxv.z do
      for y = minv.y, maxv.y do
        local vi = area:index(minv.x, y, z)
        for x = minv.x, maxv.x do
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