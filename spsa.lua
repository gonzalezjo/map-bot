--[[
  A pure-Lua (5.1 compatible) implementation of SPSA by @gonzalezjo on GitHub.
  Minimizes a given loss function with a given starting list of parameters

  The algorithm is documented here:
  https://www.jhuapl.edu/SPSA/PDF-SPSA/Spall_Implementation_of_the_Simultaneous.PDFs

  Information about this script:

  Essentially no documentation is provided, though it shouldn't be too hard to
  figure this out. SPSA is a fairly simple and well-documented algorithm, and
  Lua is a fairly simple and well-documented programming language.

  I will note two things, however:

  First, you may want to initialize the random number generator with a unique
  math.randomseed when this is first used. If convergence ever fails because
  of a bad seed, then without setting randomseed yourself, you're unlikely to
  *ever* see convergence.

  Second, change a, c, and A. A is easy to change. Most numbersaround 1000 work
  a and c will vary greatly based on the loss function and landscape. If it
  helps, I can't conceive of any situation in which ¬(0 < a, c < A) is even
  a little bit reasonable. So you could experiment with such bounds.
]]--

-- Utility settings
local VERBOSE = false
local EPSILON = 1e-4  -- How much better an optima must be to get logged

-- (Non-negative) SPSA parameters
local a = 13          -- Scale factor for movement along the gradient estimate
local c = 37          -- Scale factor for the perturbation vector.
local A = 1337        -- Starting decay factor for a. MAX_ITERATIONS / 10 works
local alpha = 0.602   -- This is the paper's recommendation, along w/ 1.0
local gamma = 0.101   -- This is the paper's recommendation, along w/ 1/6

-- Miscellaneous optimizer parameters that are orthogonal to any SPSA constants
local EARLY_EXIT = true       -- Aborts search if improvement appears unlikely
local MAX_ITERATIONS = A * 10 -- Self explanatory. Though even 500 works well enough.
local STOCHASTICITY = true    -- Add noise to the gradient when stuck
local dist = function(n)      -- Used to reshape random() distribution.
  --[[
    `n` is a real-valued, uniformly distributed random number on [-1/2, 1/2].
    `r` is chosen to represent the return value of this function.

    In theory, SPSA will perform best when `r` is Bernoulli-distributed
    such that it either takes the value of 1 or -1.

    Then, the scaling of the perturbation vector should be implicit through
    c. In practice, I've seen situations in which reshaping the distribution
    (making it a bit closer to uniform) has been helpful. Generally, however,
    you should be tweaking `a` and `c` instead of adjusting this function.
  ]]--

  return n < 0 and 1 or -1
end

-- Helper functions
function math.noise(e)
  local sf = 2e-7
  local dr = 1e3

  if e then
    sf = sf * 10^e
  end

  return math.random(-dr, dr) * sf
end

function math.clamp(a, b, c)
  if type(b) == 'table' then
    for i = 1, #b do
      b[i] = math.clamp(a, b[i], c)
    end
  else
    if a and b < a then
      return a
    elseif c and b > c then
      return c
    else
      return b
    end
  end
end

function math.round(n)
  if n < 0 then
    return math.floor(n + 0.5)
  else
    return math.ceil(n - 0.5)
  end
end

function math.pretty(n)
  if math.abs(n - math.round(n)) < EPSILON then
    return math.round(n)
  else
    return n
  end
end

function math.vadd(v1, v2, sf, update)
  local v3 = update and v1 or {}
  local sf = sf or 1

  for i = 1, #v1 do
    v3[i] = v1[i] + (sf * v2[i])
  end

  return v3
end

-- Optimizer
local function optimize(L, p, min, max, callback)
  local log
  local best
  local best_loss = L(p)
  local improvements = 0
  local t = {}
  local d = {}
  local n_p = #p

  -- Initialize theta
  for i = 1, n_p do
    t[i] = p[i]
  end

  if VERBOSE then
    local math_pretty = math.pretty
    function log(iteration)
      io.write(string.format('(Iteration %d) Current best loss: %.6f\n', iteration, best_loss))
      io.write('Current best p: ')

      for _, n in ipairs(best) do
        io.write(math_pretty(n) .. ' ')
      end

      io.write('\n')
    end
  end

  -- This seems to help avoid a few interpreter fallbacks, even on LJ 2.1.
  -- Bizarre, given that some of these functions still index into math...
  local math_vadd = math.vadd
  local math_clamp = math.clamp
  local math_noise = math.noise
  local math_random = math.random

  for k = 0, MAX_ITERATIONS - 1 do
    local a_k = a / (k + 1 + A)^alpha
    local c_k = c / (k + 1)^gamma

    -- Create perturbation vector
    for i = 1, n_p do
      d[i] = dist(math_random() - 1/2)
    end

    local t_p = math_vadd(t, d, c_k)
    local t_m = math_vadd(t, d, -c_k)

    -- Constrain theta
    math_clamp(min, t_p, max)
    math_clamp(max, t_m, max)

    local l_p = L(t_p)
    local l_m = L(t_m)

    local diff = (l_m - l_p == 0) and (STOCHASTICITY and math_noise() or 0) or l_m - l_p

    -- Update t
    math_vadd(t, d, a_k * diff / (2 * c_k), true)
    math_clamp(min, t, max)

    -- Logging
    local l = L(t)
    if l  < (best_loss - EPSILON) or
       l_p < (best_loss - EPSILON) or
       l_m < (best_loss - EPSILON) then

      improvements = improvements + 1

      best_loss = math.min(l, l_p, l_m)

      if l <= l_p and l <= l_m then
        best = t
      elseif l_p <= l and l_p <= l_m then
        best = t_p
      elseif l_m <= l and l_m <= l_p then
        best = t_m
      else
        io.write(l, l_m, l_p)
        assert(false, 'This should never get executed.')
      end

      if VERBOSE then
        log(k)
      end

      if callback then
        callback(best, k)
      end
    end

    -- Early exits
    if EARLY_EXIT then
      if k > 150 and best_loss > -0.0005 then
        return
      elseif k > 50 and improvements == 0 then
        return
      end
    end
  end
end

return optimize
