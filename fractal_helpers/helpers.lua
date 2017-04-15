-- ####################################################### --
-- HELPER FUNCTIONS --

-- Prints message if DEBUG is true
function debug_message(DEBUG, message)
  if DEBUG then
    print (message)
  end
end

-- Fixes buried spreading blocks such as dirt_with_snow and dirt_with_grass
function fix_spreading_blocks(data, area, minv, maxv, fix_spread_block)
  for z = minv.z, maxv.z do
    for x = minv.x, maxv.x do
      local last_block_solid = false
      for y = maxv.y, minv.y, -1 do
        local vi = area:index(x, y, z)
        local is_air = data[vi] == 126
        if last_block_solid and not is_air then
          data[vi] = fix_spread_block
        end
        last_block_solid = not is_air
      end
    end
  end
end

-- Restricts the region specified by two vectors minp, maxp to a 
-- cubical region size^3 starting at origin
function get_fractal_region(minp, maxp, origin, size)
  return {
    x = math.max(minp.x, origin),
    y = math.max(minp.y, origin),
    z = math.max(minp.z, origin)
  }, {
    x = math.min(maxp.x, origin + size),
    y = math.min(maxp.y, origin + size),
    z = math.min(maxp.z, origin + size)
  }
end

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

-- Multiplies a constant and a vector together
function vector_mult(c, v)
  return {
    x = c * v.x,
    y = c * v.y,
    z = c * v.z
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