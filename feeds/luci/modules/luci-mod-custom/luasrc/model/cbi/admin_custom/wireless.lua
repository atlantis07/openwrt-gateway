-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local sys   = require "luci.sys"
local conf  = require "luci.config"

local wa = require "luci.tools.webadmin" 
local nw = require "luci.model.network"  
local ut = require "luci.util"   
local nt = require "luci.sys".net      
local fs = require "nixio.fs" 

local log = require "luci.log"

local m, s, ssid, hidden, vmm

m = Map("wireless",translate("Wireless Configurations"))       
--m:chain("network")       
m:chain("firewall")

ss = m:section(NamedSection, "radio0", "wifi-device")
disabled = ss:option(ListValue, "disabled", translate("Enable"))
disabled:value("0", translate("Enable"))                       
disabled:value("1", translate("disabled")) 

s = m:section(NamedSection, "default_radio0", "wifi-iface") 
--s = m:section(TypedSection, "wifi-iface") 
s.addremove = false 
s.anonymous = true

device = s:option(ListValue, "device", translate("Device"))                             
device:value("radio0", translate("radio0")) 


mode = s:option(ListValue, "mode", translate("Mode"))    
mode.override_values = true    
mode:value("ap", translate("Access Point"))    
mode:value("sta", translate("Client")) 
--mode:value("adhoc", translate("Ad-Hoc")) 


ssid = s:option(Value, "ssid", "SSID")
ssid.datatype = "maxlength(32)"  
ssid:depends({mode="ap"})
ssid:depends({mode="sta"})       
ssid:depends({mode="adhoc"})     
ssid:depends({mode="ahdemo"})    
ssid:depends({mode="monitor"})   
ssid:depends({mode="ap-wds"})    
ssid:depends({mode="sta-wds"})    
ssid:depends({mode="wds"})

bssid = s:option(Value, "bssid", translate("<abbr title=\"Basic Service Set Identifier\">BSSID</abbr>"))   
bssid.datatype = "macaddr"
bssid:depends({mode="adhoc"})    
bssid:depends({mode="sta"})      
bssid:depends({mode="sta-wds"})

encr = s:option(ListValue, "encryption", translate("Encryption"))                                                               
encr.override_values = true                                                                                                                      
encr.override_depends = true                                                                                                                     
encr:depends({mode="ap"})                                                                                                                        
encr:depends({mode="sta"})                                                                                                                       
encr:depends({mode="adhoc"})                                                                                                                     
encr:depends({mode="ahdemo"})                                                                                                                    
encr:depends({mode="ap-wds"})                                                                                                                    
encr:depends({mode="sta-wds"})                                                                                                                   
encr:depends({mode="mesh"})

cipher = s:option(ListValue, "cipher", translate("Cipher"))                                                                     
cipher:depends({encryption="wpa"})                                                                                                               
cipher:depends({encryption="wpa2"})                                                                                                              
cipher:depends({encryption="psk"})                                                                                                               
cipher:depends({encryption="psk2"})                                                                                                              
cipher:depends({encryption="wpa-mixed"})                                                                                                         
cipher:depends({encryption="psk-mixed"})                                                                                                         
cipher:value("auto", translate("auto"))                                                                                                          
cipher:value("ccmp", translate("Force CCMP (AES)"))                                                                                              
cipher:value("tkip", translate("Force TKIP"))                                                                                                    
cipher:value("tkip+ccmp", translate("Force TKIP and CCMP (AES)"))

function encr.cfgvalue(self, section)                                                                                                            
        local v = tostring(ListValue.cfgvalue(self, section))                                                                                    
        if v == "wep" then                                                                                                                       
                return "wep-open"                                                                                                                
        elseif v and v:match("%+") then                                                                                                          
                return (v:gsub("%+.+$", ""))                                                                                                     
        end                                                                                                                                      
        return v                                                                                                                                 
end                                                                                                                                              
                                                                                                                                                 
function encr.write(self, section, value)                                                                                                        
        local e = tostring(encr:formvalue(section))                                                                                              
        local c = tostring(cipher:formvalue(section))                                                                                            
        if value == "wpa" or value == "wpa2"  then                                                                                               
                self.map.uci:delete("wireless", section, "key")                                                                                  
        end                                                                                                                                      
        if e and (c == "tkip" or c == "ccmp" or c == "tkip+ccmp") then                                                                           
                e = e .. "+" .. c                                                                                                                
        end                                                                                                                                      
        self.map:set(section, "encryption", e)                                                                                                   
end

function cipher.cfgvalue(self, section)                                                                                                          
        local v = tostring(ListValue.cfgvalue(encr, section))                                                                                    
        if v and v:match("%+") then                                                                                                              
                v = v:gsub("^[^%+]+%+", "")                                                                                                      
                if v == "aes" then v = "ccmp"                                                                                                    
                elseif v == "tkip+aes" then v = "tkip+ccmp"                                                                                      
                elseif v == "aes+tkip" then v = "tkip+ccmp"                                                                                      
                elseif v == "ccmp+tkip" then v = "tkip+ccmp"                                                                                     
                end                                                                                                                              
        end                                                                                                                                      
        return v                                                                                                                                 
end                                                                                                                                              
                                                                                                                                                 
function cipher.write(self, section)                                                                                                             
        return encr:write(section)                                                                                                               
end 

encr:value("none", "No Encryption")
encr:value("wep-open",   translate("WEP Open System"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"}, {mode="ahdemo"}, {mode="wds"})
encr:value("wep-shared", translate("WEP Shared Key"),  {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"}, {mode="ahdemo"}, {mode="wds"})

local supplicant = fs.access("/usr/sbin/wpa_supplicant")                                                                                 
local hostapd = fs.access("/usr/sbin/hostapd")                                                                                           
                                                                                                                                                 
-- Probe EAP support                                                                                                                     
local has_ap_eap  = (os.execute("hostapd -veap >/dev/null 2>/dev/null") == 0)                                                            
local has_sta_eap = (os.execute("wpa_supplicant -veap >/dev/null 2>/dev/null") == 0)                                                     
                                                                                                                                                 
-- Probe SAE support                                                                                                                     
local has_ap_sae  = (os.execute("hostapd -vsae >/dev/null 2>/dev/null") == 0)                                                            
local has_sta_sae = (os.execute("wpa_supplicant -vsae >/dev/null 2>/dev/null") == 0)                                                     
                                                                                                                                                 
-- Probe OWE support                                                                                                                     
local has_ap_owe  = (os.execute("hostapd -vowe >/dev/null 2>/dev/null") == 0)                                                            
local has_sta_owe = (os.execute("wpa_supplicant -vowe >/dev/null 2>/dev/null") == 0)
if hostapd and supplicant then                                                                                                           
    encr:value("psk", "WPA-PSK", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"})                       
    encr:value("psk2", "WPA2-PSK", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"})                     
    encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"})
    if has_ap_sae and has_sta_sae then                                                                                               
        encr:value("sae", "WPA3-SAE", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"}, {mode="mesh"})
        encr:value("sae-mixed", "WPA2-PSK/WPA3-SAE Mixed Mode", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"})
    end                                                                                                                              
    if has_ap_eap and has_sta_eap then                                                                                               
        encr:value("wpa", "WPA-EAP", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})                               
        encr:value("wpa2", "WPA2-EAP", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})                             
    end                                                                                                                              
    if has_ap_owe and has_sta_owe then                                                                                               
        encr:value("owe", "OWE", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"})                   
    end
elseif hostapd and not supplicant then                                                                                                   
    encr:value("psk", "WPA-PSK", {mode="ap"}, {mode="ap-wds"})                                                                       
    encr:value("psk2", "WPA2-PSK", {mode="ap"}, {mode="ap-wds"})                                                                     
    encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="ap"}, {mode="ap-wds"})                                             
    if has_ap_sae then                                                                                                               
        encr:value("sae", "WPA3-SAE", {mode="ap"}, {mode="ap-wds"})                                                              
        encr:value("sae-mixed", "WPA2-PSK/WPA3-SAE Mixed Mode", {mode="ap"}, {mode="ap-wds"})                                    
    end                                                                                                                              
    if has_ap_eap then                                                                                                               
        encr:value("wpa", "WPA-EAP", {mode="ap"}, {mode="ap-wds"})                                                               
        encr:value("wpa2", "WPA2-EAP", {mode="ap"}, {mode="ap-wds"})                                                             
    end                                                                                                                              
    if has_ap_owe then                                                                                                               
        encr:value("owe", "OWE", {mode="ap"}, {mode="ap-wds"})                                                                   
    end                                                                                                                              
    encr.description = translate(                                                                                                    
                   "WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..                                        
                        "and ad-hoc mode) to be installed."                                                                                      
    )
elseif not hostapd and supplicant then                                                                                                   
    encr:value("psk", "WPA-PSK", {mode="sta"}, {mode="sta-wds"}, {mode="adhoc"})                                                     
    encr:value("psk2", "WPA2-PSK", {mode="sta"}, {mode="sta-wds"}, {mode="adhoc"})                                                   
    encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="sta"}, {mode="sta-wds"}, {mode="adhoc"})                           
    if has_sta_sae then                                                                                                              
        encr:value("sae", "WPA3-SAE", {mode="sta"}, {mode="sta-wds"}, {mode="mesh"})                                             
        encr:value("sae-mixed", "WPA2-PSK/WPA3-SAE Mixed Mode", {mode="sta"}, {mode="sta-wds"})                                  
    end                                                                                                                              
    if has_sta_eap then                                                                                                              
        encr:value("wpa", "WPA-EAP", {mode="sta"}, {mode="sta-wds"})                                                             
        encr:value("wpa2", "WPA2-EAP", {mode="sta"}, {mode="sta-wds"})                                                           
    end                                                                                                                              
    if has_sta_owe then                                                                                                              
        encr:value("owe", "OWE", {mode="sta"}, {mode="sta-wds"})                                                                 
    end                                                                                                                              
    encr.description = translate(                                                                                                    
                  "WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..                                        
                        "and ad-hoc mode) to be installed."                                                                                      
    )                                                                                                                                
else                                                                                                                                     
    encr.description = translate(                                                                                                    
           "WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..                                        
                    "and ad-hoc mode) to be installed."                                                                                      
    )                                                                                                                                
end

auth_server = s:option(Value, "auth_server", translate("Radius-Authentication-Server"))                                         
auth_server:depends({mode="ap", encryption="wpa"})                                                                                               
auth_server:depends({mode="ap", encryption="wpa2"})                                                                                              
auth_server:depends({mode="ap-wds", encryption="wpa"})                                                                                           
auth_server:depends({mode="ap-wds", encryption="wpa2"})                                                                                          
auth_server.rmempty = true                                                                                                                       
auth_server.datatype = "host(0)"                                                                                                                 
                                                                                                                                                 
auth_port = s:option(Value, "auth_port", translate("Radius-Authentication-Port"), translatef("Default %d", 1812))               
auth_port:depends({mode="ap", encryption="wpa"})                                                                                                 
auth_port:depends({mode="ap", encryption="wpa2"})                                                                                                
auth_port:depends({mode="ap-wds", encryption="wpa"})                                                                                             
auth_port:depends({mode="ap-wds", encryption="wpa2"})                                                                                            
auth_port.rmempty = true                                                                                                                         
auth_port.datatype = "port"                                                                                                                      
                                                                                                                                                 
auth_secret = s:option(Value, "auth_secret", translate("Radius-Authentication-Secret"))                                         
auth_secret:depends({mode="ap", encryption="wpa"})                                                                                               
auth_secret:depends({mode="ap", encryption="wpa2"})                                                                                              
auth_secret:depends({mode="ap-wds", encryption="wpa"})                                                                                           
auth_secret:depends({mode="ap-wds", encryption="wpa2"})                                                                                          
auth_secret.rmempty = true                                                                                                                       
auth_secret.password = true                                                                                                                      
                                                                                                                                                 
acct_server = s:option(Value, "acct_server", translate("Radius-Accounting-Server"))                                             
acct_server:depends({mode="ap", encryption="wpa"})                                                                                               
acct_server:depends({mode="ap", encryption="wpa2"})                                                                                              
acct_server:depends({mode="ap-wds", encryption="wpa"})                                                                                           
acct_server:depends({mode="ap-wds", encryption="wpa2"})                                                                                          
acct_server.rmempty = true                                                                                                                       
acct_server.datatype = "host(0)" 

acct_port = s:option(Value, "acct_port", translate("Radius-Accounting-Port"), translatef("Default %d", 1813))                   
acct_port:depends({mode="ap", encryption="wpa"})                                                                                                 
acct_port:depends({mode="ap", encryption="wpa2"})                                                                                                
acct_port:depends({mode="ap-wds", encryption="wpa"})                                                                                             
acct_port:depends({mode="ap-wds", encryption="wpa2"})                                                                                            
acct_port.rmempty = true                                                                                                                         
acct_port.datatype = "port"                                                                                                                      
                                                                                                                                                 
acct_secret = s:option(Value, "acct_secret", translate("Radius-Accounting-Secret"))                                             
acct_secret:depends({mode="ap", encryption="wpa"})                                                                                               
acct_secret:depends({mode="ap", encryption="wpa2"})                                                                                              
acct_secret:depends({mode="ap-wds", encryption="wpa"})                                                                                           
acct_secret:depends({mode="ap-wds", encryption="wpa2"})                                                                                          
acct_secret.rmempty = true                                                                                                                       
acct_secret.password = true


dae_port = s:option(Value, "dae_port", translate("DAE-Port"), translatef("Default %d", 3799))                                   
dae_port:depends({mode="ap", encryption="wpa"})                                                                                                  
dae_port:depends({mode="ap", encryption="wpa2"})                                                                                                 
dae_port:depends({mode="ap-wds", encryption="wpa"})                                                                                              
dae_port:depends({mode="ap-wds", encryption="wpa2"})                                                                                             
dae_port.rmempty = true                                                                                                                          
dae_port.datatype = "port"                                                                                                                       
                                                                                                                                                 
dae_secret = s:option(Value, "dae_secret", translate("DAE-Secret"))                                                             
dae_secret:depends({mode="ap", encryption="wpa"})                                                                                                
dae_secret:depends({mode="ap", encryption="wpa2"})                                                                                               
dae_secret:depends({mode="ap-wds", encryption="wpa"})                                                                                            
dae_secret:depends({mode="ap-wds", encryption="wpa2"})                                                                                           
dae_secret.rmempty = true                                                                                                                        
dae_secret.password = true

wpakey = s:option(Value, "_wpa_key", translate("Key"))                                                                          
wpakey:depends("encryption", "psk")                                                                                                              
wpakey:depends("encryption", "psk2")                                                                                                             
wpakey:depends("encryption", "psk+psk2")                                                                                                         
wpakey:depends("encryption", "psk-mixed")                                                                                                        
wpakey:depends("encryption", "sae")                                                                                                              
wpakey:depends("encryption", "sae-mixed")                                                                                                        
wpakey.datatype = "wpakey"                                                                                                                       
wpakey.rmempty = true                                                                                                                            
wpakey.password = true                                                                                                                           
                                                                                                                                                 
wpakey.cfgvalue = function(self, section, value)                                                                                                 
        local key = m.uci:get("wireless", section, "key")                                                                                        
        if key == "1" or key == "2" or key == "3" or key == "4" then                                                                             
                return nil                                                                                                                       
        end                                                                                                                                      
        return key                                                                                                                               
end                                                                                                                                              
                                                                                                                                                 
wpakey.write = function(self, section, value)                                                                                                    
        self.map.uci:set("wireless", section, "key", value)                                                                                      
        self.map.uci:delete("wireless", section, "key1")                                                                                         
end

wepslot = s:option(ListValue, "_wep_key", translate("Used Key Slot"))                                                           
wepslot:depends("encryption", "wep-open")                                                                                                        
wepslot:depends("encryption", "wep-shared")                                                                                                      
wepslot:value("1", translatef("Key #%d", 1))                                                                                                     
wepslot:value("2", translatef("Key #%d", 2))                                                                                                     
wepslot:value("3", translatef("Key #%d", 3))                                                                                                     
wepslot:value("4", translatef("Key #%d", 4))                                                                                                     
                                                                                                                                                 
wepslot.cfgvalue = function(self, section)                                                                                                       
        local slot = tonumber(m.uci:get("wireless", section, "key"))                                                                             
        if not slot or slot < 1 or slot > 4 then                                                                                                 
                return 1                                                                                                                         
        end                                                                                                                                      
        return slot                                                                                                                              
end                                                                                                                                              
                                                                                                                                                 
wepslot.write = function(self, section, value)                                                                                                   
        self.map.uci:set("wireless", section, "key", value)                                                                                      
end

local slot                                                                                                                                       
for slot=1,4 do                                                                                                                                  
        wepkey = s:option(Value, "key" .. slot, translatef("Key #%d", slot))                                                    
        wepkey:depends("encryption", "wep-open")                                                                                                 
        wepkey:depends("encryption", "wep-shared")                                                                                               
        wepkey.datatype = "wepkey"                                                                                                               
        wepkey.rmempty = true                                                                                                                    
        wepkey.password = true                                                                                                                   
                                                                                                                                                 
        function wepkey.write(self, section, value)                                                                                              
                if value and (#value == 5 or #value == 13) then                                                                                  
                        value = "s:" .. value                                                                                                    
                end                                                                                                                              
                return Value.write(self, section, value)                                                                                         
        end                                                                                                                                      
end



network = s:option(Value, "network", translate("Network"),                                                                         
        translate("Choose the network(s) you want to attach to this wireless interface or " ..                                                   
                "fill out the <em>create</em> field to define a new network."))                                                                  
                                                                                                                                                 
network.rmempty = true                                                                                                                           
network.template = "cbi/network_netlist"                                                                                                         
network.widget = "checkbox"                                                                                                                      
network.novirtual = true 



hidden = s:option(Flag, "hidden", translate("Hide <abbr title=\"Extended Service Set Identifier\">SSID</abbr>"))  
hidden:depends({mode="ap"})      
hidden:depends({mode="ap-wds"})

isolate = s:option(Flag, "isolate", translate("Isolate Clients"), 
	translate("Prevents client-to-client communication"))   
isolate:depends({mode="ap"})     
isolate:depends({mode="ap-wds"})

wmm = s:option(Flag, "wmm", translate("WMM Mode")) 
wmm:depends({mode="ap"}) 
wmm:depends({mode="ap-wds"})     
wmm.default = wmm.enabled

mp = s:option(ListValue, "macfilter", translate("MAC-Address Filter"))   
mp:depends({mode="ap"})  
mp:depends({mode="ap-wds"})      
mp:value("", translate("disable"))       
mp:value("allow", translate("Allow listed only"))
mp:value("deny", translate("Allow all except listed"))   
 
ml = s:option(DynamicList, "maclist", translate("MAC-List"))     
ml.datatype = "macaddr"  
ml:depends({macfilter="allow"})  
ml:depends({macfilter="deny"})   
nt.mac_hints(function(mac, name) ml:value(mac, "%s (%s)" %{ mac, name }) end)

mode:value("ap-wds", "%s (%s)" % {translate("Access Point"), translate("WDS")})  
mode:value("sta-wds", "%s (%s)" % {translate("Client"), translate("WDS")})
function mode.write(self, section, value)
  if value == "ap-wds" then
    ListValue.write(self, section, "ap")     
    m.uci:set("wireless", section, "wds", 1) 
  elseif value == "sta-wds" then   
    ListValue.write(self, section, "sta")    
    m.uci:set("wireless", section, "wds", 1) 
  else     
    ListValue.write(self, section, value)    
    m.uci:delete("wireless", section, "wds") 
  end      
end      
 
function mode.cfgvalue(self, section)    
  local mode = ListValue.cfgvalue(self, section)   
  local wds  = m.uci:get("wireless", section, "wds") == "1"
 
  if mode == "ap" and wds then     
    return "ap-wds"  
  elseif mode == "sta" and wds then
    return "sta-wds" 
  else     
    return mode      
  end      
end 

return m
