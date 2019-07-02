-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local sys   = require "luci.sys"
local conf  = require "luci.config"

local m, s, o, p, q

m = Map("remote_control", translate("Door Control"))
m:chain("luci")

s = m:section(TypedSection, "door", translate("Door"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "ipaddr", translate("Mqtt Server"))
o.optional	= false
o.default 	= "0.0.0.0"
o.datatype	= "ip4addr" 


sub = s:option(Value, "subtopic", translate("Sub Topic"))
sub.optional	= false
sub.default 	= "sub-dev1"
sub.datatype	= "string" 


pub = s:option(Value, "pubtopic", translate("Pub Topic"))
o.optional	= false
o.default 	= "pub-dev1"
o.datatype	= "string" 


switch = s:option(Value, "switch", translate("Switch GPIO"))
switch.optional	= false
switch.default	= 2
switch.datatype	= "uinteger"

buzzer = s:option(Value, "buzzer", translate("Buzzer GPIO"))
buzzer.optional	= false
buzzer.default	= 4
buzzer.datatype	= "uinteger"

ss = s:option(Value, "switchsleep", translate("Switch Sleep s"))
ss.optional	= false
ss.default	= 1
ss.datatype	= "uinteger"


bs = s:option(Value, "buzzersleep", translate("Buzzer Sleep ms"))
bs.optional	= false
bs.default	= 250
bs.datatype	= "uinteger"


return m
