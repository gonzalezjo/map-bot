require 'serializer'
require 'randomseed'

local run_simulation = require 'simulator'
local spsa = require 'spsa'

-- Loss function settings
local PENALTY_LIST = {
  BIDEN_WIN_PENALTY = 0,
  TRUMP_WIN_PENALTY = 0,
  BLOWOUT_PENALTY = 0,
  EC_WORKS_PENALTY = 16,
}

-- Settings for the optimizer.
local MIN = 0
local MAX = 1000

-- Leftover from pre-FFI optimizations. Can (and should) simplify this away.
local function parameters_to_changes(p)
  return {
    bidenshare = {
      underlying = {
        math.round(p[1]),
        math.round(p[2]),
        math.round(p[3]),
        math.round(p[4]),
        math.round(p[5])
      }
    },
    turnout = {
      underlying = {
        math.round(p[6]),
        math.round(p[7]),
        math.round(p[8]),
        math.round(p[9]),
        math.round(p[10])
      }
    }
  }
end

local function L(p) -- loss function
  local results = run_simulation(parameters_to_changes(p))
  local win_scale = results.winner == 'Biden' and 1 or -1

  local loss
  if results.pv_gap > 0 and win_scale < 0 then
    loss = results.pv_gap * win_scale
  elseif results.pv_gap < 0 and win_scale > 0 then
    loss = results.pv_gap * win_scale
  else
    loss = PENALTY_LIST.EC_WORKS_PENALTY * math.abs(results.pv_gap * win_scale)
  end

  -- Scale it down (easier for reading output and for the optimizer's settings)
  loss = loss / 1e6

  -- Add special rewards and penalties
  if PENALTY_LIST.BIDEN_WIN_PENALTY ~= 0 and
     PENALTY_LIST.TRUMP_WIN_PENALTY ~= 0 and
     results.winner == 'Biden' then
    loss = loss + PENALTY_LIST.BIDEN_WIN_PENALTY
  else
    loss = loss + PENALTY_LIST.TRUMP_WIN_PENALTY
  end

  if PENALTY_LIST.BLOWOUT_PENALTY ~= 0 then
    loss = loss + PENALTY_LIST.BLOWOUT_PENALTY * math.abs(269 - results.biden_evs)
  end

  return loss
end

local function on_new_optima(p, step)
  local URL_FMT = 'https://cookpolitical.com/swingometer?CEWv=%.f&NCWv=%.f' ..
                  '&AAv=%.f&HLv=%.f&AOv=%.f&CEWt=%.f&NCWt=%.f&AAt=%.f&HLt=' ..
                  '%.f&AOt=%.f'
  local changes = parameters_to_changes(p)
  local results = run_simulation(changes)

  if L(p) > -8 then
    return
  end

  io.write 'New optima... dumping results\n'

  io.write 'Changes\n'
  io.write(table.dump(changes))
  io.write '\n'

  io.write 'Simulation outcome\n'
  io.write(table.dump(results))
  io.write '\n'

  io.write 'Optimizer loss\n'
  io.write(tostring(L(p)))
  io.write '\n'

  io.write 'URL\n'
  io.write(string.format(URL_FMT, unpack(p)))
  io.write '\n'

  io.write 'Step\n'
  io.write(step)
  io.write '\n'

  io.flush()
end

while true do
  local default_parameters = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

  for i = 1, 10 do
    default_parameters[i] = 1000 * math.random()
  end

  spsa(L, default_parameters, MIN, MAX, on_new_optima)
end
