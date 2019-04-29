-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local log = require "luci.log"
local ut = require "luci.util"
local http = require "luci.http"
local m, m2, s, s2
local mode, device, apn, ifname, p, ip, netmask, gateway
local p_switch, p2_switch
local wmode, ssid, bssid, encr, cipher, wpakey

m = Map("network",translate("Network Conf"))
m:chain("luci")
m:chain("wireless")
m:chain("firewall")

s = m:section(NamedSection, "wan", "configurations")
s.anonymous = true
s.addremove = false

mode = s:option(ListValue, "mode", translate("Mode"))  
mode:value("4g", translate("4G")) 
mode:value("wireless", translate("Wireless")) 
mode:value("wire", translate("Wire")) 


device = s:option(Value, "device", translate("Device"))
device:depends("mode", "4g")

device.default = "/dev/cdc-wdm0"

apn = s:option(ListValue, "apn", translate("APN"))
apn:depends("mode", "4g")
apn:value("apn", "cnnet")
apn.default = "cnnet"

pdptype = s:option(ListValue, "pdptype", translate("Type"))
pdptype:depends("mode", "4g")
pdptype:value("ip")  
pdptype:value("ipv6")  
pdptype:value("ipv4v6")
                                                           
dhcpv6 = s:option(ListValue, "dhcpv6", translate("dhcpv6"))
dhcpv6:depends("mode", "4g")          
dhcpv6:value("1", translate("Enable"))
dhcpv6:value("0", translate("Disable"))
                                                     
dhcp = s:option(ListValue, "dhcp", translate("dhcp"))
dhcp:depends("mode", "4g")                   
dhcp:value("1", translate("Enable")) 
dhcp:value("0", translate("Disable")) 

ifname = s:option(ListValue, "ifname", translate("IFNAME"))
ifname:depends("mode", "4g")
ifname:depends("mode", "wire")
ifname.default = "wwan0"
ifname:value("wwan0", "wwan0", {mode = "4g"})
ifname:value("eth0.2", "eth0.2", {mode = "wire"})

p = s:option(ListValue, "proto", translate("Proto"))
p.default = "qmi"
p:value("qmi", translate("QMI"), {mode = "4g"})
p:value("dhcp", translate("Dhcp-cli"), {mode = "wireless"}, {mode = "wire"})
p:value("static", translate("Static"), {mode = "wireless"}, {mode = "wire"})
p:value("pppoe", translate("PPPOE"), {mode = "wire"})

ip = s:option(Value, "ipaddr", translate("IPv4 address"))
ip:depends("proto", "static")
ip.datatype = "ip4addr"                      
--ip.template = "cbi/ipaddr"

netmask = s:option(Value, "netmask", translate("IPv4 netmask"))     
netmask:depends("proto", "static")
netmask.datatype = "ip4addr"                                                       
netmask:value("255.255.255.0")                                                     
netmask:value("255.255.0.0")                                                       
netmask:value("255.0.0.0") 

gateway = s:option(Value, "gateway", translate("IPv4 gateway"))
gateway:depends("proto", "static")
gateway.datatype = "ip4addr"

username = s:option(Value, "username", translate("PAP/CHAP username"))                    
username:depends({proto = "pppoe"})
                                                                                                              
password = s:option(Value, "password", translate("PAP/CHAP password"))                    
password:depends({proto = "pppoe"})
password.password = true 


ac = s:option(Value, "ac",                                                                
        translate("Access Concentrator"),                                                                     
        translate("Leave empty to autodetect"))
ac:depends({proto = "pppoe"})
ac.placeholder = translate("auto")

service = s:option(Value, "service",                    
        translate("Service Name"),                                                                            
        translate("Leave empty to autodetect"))                                    
service:depends({proto = "pppoe"})
service.placeholder = translate("auto")

p_switch = s:option(Button, "_switch")                                                                                           
p_switch.title      = translate("WIFI Wan")
p_switch.inputtitle = translate("Open")
p_switch.inputstyle = "apply"
p_switch:depends("mode", "wireless")
local open = luci.http.formvalue("cbid.network.wan._switch")

p2_switch = s:option(Button, "_2switch")                   
p2_switch.title      = translate("WIFI Wan")
p2_switch.inputtitle = translate("Close")
p2_switch.inputstyle = "apply"
p2_switch:depends("mode", "wire")
p2_switch:depends("mode", "4g")
local close = luci.http.formvalue("cbid.network.wan._2switch")

local _mode = luci.http.formvalue("cbid.network.wan.mode")
--log.print("mode", _mode)

if _mode == "wireless" then
	----wifi-----
    m2 = Map("wireless","Wireless Configurations", translate("Wireless Configurations"))       
--    m2:chain("luci")
--    m2:chain("firewall")
    s2 = m2:section(NamedSection, "default_radio0","configurations")                 
    s2.anonymous = true                                                   
    s2.addremove = false

    wmode = s2:option(ListValue, "mode", translate("Mode")) 
    wmode:value("sta", translate("Client"))  

    wdevice = s2:option(ListValue, "device", translate("Device"))
    wdevice:value("radio0", translate("radio0"))

    ssid = s2:option(Value, "ssid", "SSID")                                                                                                           
    ssid.datatype = "maxlength(32)"

    bssid = s2:option(Value, "bssid", translate("<abbr title=\"Basic Service Set Identifier\">BSSID</abbr>"))                                         
    bssid.datatype = "macaddr"

    encr = s2:option(ListValue, "encryption", translate("Encryption")) 
    encr:value("none", "No Encryption")                                                                     
    encr:value("psk", "WPA-PSK")
    encr:value("psk2", "WPA2-PSK")
    encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode")

    cipher = s2:option(ListValue, "cipher", translate("Cipher"))                                                                                      
    cipher:depends({encryption="psk"})                                                                                                               
    cipher:depends({encryption="psk2"})                                                                                                              
    cipher:depends({encryption="psk-mixed"})                                                                                                         
    cipher:value("auto", translate("auto"))                                                                                                          
    cipher:value("ccmp", translate("Force CCMP (AES)"))                                                                                              
    cipher:value("tkip", translate("Force TKIP"))                                                                                                    
    cipher:value("tkip+ccmp", translate("Force TKIP and CCMP (AES)"))


    wpakey = s2:option(Value, "key", translate("Key"))                                                                                           
    wpakey:depends("encryption", "psk")                                                                                                              
    wpakey:depends("encryption", "psk2")                                                                                                             
    wpakey:depends("encryption", "psk-mixed")                                                                                                        
    wpakey.datatype = "wpakey"                                                                                                                       
    wpakey.rmempty = true                                                                                                                            
    wpakey.password = true 

    wnetwork = s2:option(Value, "network", translate("Network"),                                                                                       
        translate("Choose the network(s) you want to attach to this wireless interface or " ..                                                   
                "fill out the <em>create</em> field to define a new network."))                                                                  
                                                                                                                                                 
    wnetwork.rmempty = true                                                                                                                           
    wnetwork.template = "cbi/network_netlist"                 
    wnetwork.widget = "checkbox"                              
    wnetwork.novirtual = true
    
    ss = m2:section(NamedSection, "radio0", "wifi-device")                                                                                       
    disabled = ss:option(ListValue, "disabled", translate("Enable"))                                                                             
    disabled:value("0", translate("Enable"))                                                                                                     
    disabled:value("1", translate("disabled"))

else
    m2 = nil
end



return m,m2                                                   
