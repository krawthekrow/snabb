-- Use of this source code is governed by the Apache 2.0 license; see COPYING.

module(...,package.seeall)

local S = require("syscall")
local ffi = require("ffi")
local yang = require("lib.yang.yang")
local rpc = require("lib.yang.rpc")
local app = require("core.app")
local shm = require("core.shm")
local app_graph = require("core.config")
local channel = require("apps.config.channel")
local action_queue = require("apps.config.action_queue")

Follower = {
   config = {
      Hz = {default=1000},
   }
}

function Follower:new (conf)
   local ret = setmetatable({}, {__index=Follower})
   ret.period = 1/conf.Hz
   ret.next_time = app.now()
   ret.channel = channel.create('config-follower-channel', 1e6)
   return ret
end

function Follower:handle_actions_from_leader()
   local channel = self.channel
   while true do
      local buf, len = channel:peek_message()
      if not buf then break end
      local action = action_queue.decode_action(buf, len)
      app.apply_config_actions({action})
      channel:discard_message(len)
   end
end

function Follower:pull ()
   if app.now() < self.next_time then return end
   self.next_time = app.now() + self.period
   self:handle_actions_from_leader()
end

function selftest ()
   print('selftest: apps.config.follower')
   local c = config.new()
   config.app(c, "follower", Follower, {})
   engine.configure(c)
   engine.main({ duration = 0.0001, report = {showapps=true,showlinks=true}})
   engine.configure(config.new())
   print('selftest: ok')
end
