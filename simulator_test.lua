local run_simulation = require 'simulator'

-- https://cookpolitical.com/swingometer?CEWv=134&NCWv=860&AAv=14&HLv=1000&AOv=1000&CEWt=875&NCWt=175&AAt=20&HLt=1000&AOt=998
local outcome = run_simulation {
  bidenshare = {
    underlying = {
        134,
        860,
        14,
        1000,
        1000
    }
  },
  turnout = {
    underlying = {
      875,
      175,
      20,
      1000,
      998
    }
  }
}

print('Biden EVs: ' .. outcome.biden_evs)
assert(outcome.biden_evs == 268)
assert(outcome.winner == 'Trump')
