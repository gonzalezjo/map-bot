local spsa = require 'spsa'

local function pwrap(fn)
  return function(...)
    print(...)
    return fn(...)
  end
end

local piecewise_test = function(t)
  local x, y = t[1], t[2]
  return math.abs((2 * (x + 6))) + math.abs(4 * y)
end

spsa(piecewise_test, {10, 10})
