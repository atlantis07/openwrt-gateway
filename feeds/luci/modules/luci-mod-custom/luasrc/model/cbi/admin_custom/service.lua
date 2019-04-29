-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local sys   = require "luci.sys"
local conf  = require "luci.config"

local m, s, o, p, q

m = Map("service", translate("Service Configurations"))
m:chain("luci")

s = m:section(TypedSection, "mqtt", translate("mqtt configurations"))
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "enable", translate("Mqtt Enable"))  
o:value(1, translate("Enable")) 
o:value(0, translate("Disable")) 

o = s:option(Value, "server", translate("Mqtt Server"))
o.optional	= false
o.default 	= "0.0.0.0"
o.datatype	= "ip4addr" 
o:depends("enable", 1)


o = s:option(Value, "user", translate("User"))
o.optional 	= false
o.default 	= "user"
o.datatype	= "string" 
o:depends("enable", 1)


o = s:option(Value, "passwd", translate("Password"))
o.optional	= false
o.default 	= "passwd"
o.datatype	= "string" 
o:depends("enable", 1)


o = s:option(Value, "sub", translate("Sub Topic"))
o.optional	= false
o.default 	= "sub-topic"
o.datatype	= "string" 
o:depends("enable", 1)


o = s:option(Value, "pub", translate("Pub Topic"))
o.optional	= false
o.default 	= "pub-topic"
o.datatype	= "string" 
o:depends("enable", 1)


p = m:section(TypedSection, "tcp", translate("tcp configurations"))
p.anonymous = true
p.addremove = false

q = p:option(ListValue, "enable", translate("Tcp Enable"))  
q:value(1, translate("Enable")) 
q:value(0, translate("Disable")) 

q = p:option(Value, "server", translate("TCP Server"))
q.optional	= false
q.default 	= "1.1.1.1"
q.datatype	= "ip4addr" 
q:depends("enable", 1)

q = p:option(Value, "port", translate("TCP Port"))
q.optional	= false
q.default	= 8001
q.datatype	= "uinteger"
q:depends("enable", 1)

return m
