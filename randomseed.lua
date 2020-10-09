local ffi = require 'ffi'

local source = io.open('/dev/urandom','rb')
local random = {source:read(4):byte(1, 8)}

source:close()

local seed = ffi.new([[union {
  char underlying[8];
  uint64_t seed;
}]], {underlying = random}).seed

math.randomseed(tonumber(seed))
