--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: openvpn.lua 5448 2009-10-31 15:54:11Z jow $
]]--

local fs  = require "nixio.fs"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()
local utl = require "luci.util"

local function debug(string)
	sys.call("logger " .. string)
end

local m ,s, o, m2

m = Map("xl2tpd", translate("Layer 2 Tuneling Protocol"))
m.spec_dir = nil
-- m.pageaction = false

s = m:section( TypedSection, "service", translate("L2TP Configuration") )
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection_list1"
s.addremoveAdd = true


s.extedit = luci.dispatcher.build_url("admin", "services", "vpn", "l2tp", "s_%s")

local name = s:option( DummyValue, "_name", translate("Name"), translate("Name of the L2TP configuration. Used for easier L2TP configurations management purpose only"))
name.rawhtml = true
name.width   = "25%"
function name.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section) or ""
	return val:gsub("^%l", string.upper)
end

local ptype = s:option( DummyValue, "_type", translate("Type"), translate("A role that the L2TP configuration is in"))
ptype.rawhtml = true
ptype.width   = "25%"
function ptype.cfgvalue(self, section)
	return "Server"
end


--local status = s:option( DummyValue, "enabled", translate("Enabled"), translate("Indicates whether a configuration is active or not"))
status = s:option(Flag, "enabled", translate("Enable"), translate("Make a rule active/inactive"))
status.rawhtml = true
status.width   = "25%"
status.forcewrite = true
status.rmempty = false
--[[
function status.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if val == "1" then
		return translate("Yes")
	else
		return translate("No")
	end
end
--]]

m2 = Map("network", "")
m2.spec_dir = nil
--m2.pageaction = false

s = m2:section( TypedSection, "interface", "", "" )
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection_list2"
s.template_addremove = "openvpn/add_rem"
s.addremoveAdd = true
s.number = utl.trim(sys.exec("uci -q show xl2tpd | grep -c service"))

s.extedit = luci.dispatcher.build_url("admin", "services", "vpn", "l2tp", "c_%s")

local name = s:option( DummyValue, "_name", translate("Name"), translate("Name of the L2TP configuration. Used for easier L2TP configurations management purpose only"))

function name.cfgvalue(self, section)
	return section:gsub("^%l", string.upper) or "Unknown"
end

local ptype = s:option( DummyValue, "dev", translate("Type"), translate("A role that the L2TP configuration is in"))

function ptype.cfgvalue(self, section)
	return "Client"
end

status = s:option(Flag, "enabled", translate("Enable"), translate("Make a rule active/inactive"))
status.forcewrite = true
status.rmempty = false
function status.write(self, section, value)
	m.uci:set(self.config, section, "enabled", value)
	if value == "1" then
		m.uci:set(self.config, section, "disabled", "0")
	else
		m.uci:set(self.config, section, "disabled", "1")
	end
	m.uci:set(self.config, section, "defaultroute", "0")
	m.uci:commit(self.config)
end
--[[
local status = s:option( DummyValue, "enabled", translate("Enabled"), translate("Indicates whether a configuration is active or not"))
function status.cfgvalue(self, section)
	local val = AbstractValue.cfgvalue(self, section)
	if val == "1" then
		return translate("Yes")
	else
		return translate("No")
	end
end
--]]
function s.validate(self, value)
	proto = utl.trim(sys.exec("uci get network." .. value .. ".proto")) or "0"
	if proto ~= "l2tp" then
		return nil
	end
	return value
end

function s.parse(self, section)
	local cfgname = luci.http.formvalue("cbid." .. self.config .. "." .. self.sectiontype .. ".name")
	local delButtonFormString = "cbi.rts." .. self.config .. "."
	local delButtonPress
	local configName

	uci:foreach("network", "interface", function(x)
		configName = x[".name"] or ""
		if luci.http.formvalue(delButtonFormString .. configName) then
			delButtonPress = true
			uci:delete(self.config, configName)
			uci:commit("network")
		end
	end)

	if luci.http.formvalue("cbi.rts.xl2tpd.xl2tpd") then
		delButtonPress = true
		local deleted = false
		uci:foreach("firewall", "rule", function(x)
			if x._name == "xl2tpd" then
				uci:delete("firewall", x[".name"])
				deleted = true
			end
		end)
		uci:delete("xl2tpd", "xl2tpd")
		uci:commit("xl2tpd")
		uci:save("firewall")
		uci:commit("firewall")

		if deleted then
			sys.call("/etc/init.d/firewall reload >/dev/null 2>/dev/null")
		end
	end

	if delButtonPress then
		sys.call("/etc/init.d/xl2tpd restart >/dev/null 2>/dev/null")
		sys.call("/etc/init.d/network reload >/dev/null 2>/dev/null")
	elseif cfgname and cfgname ~= '' then
		vpn_new(self, cfgname)
 	end

	TypedSection.parse( self, section )
end


function vpn_new(self,name)
	local exist = false
	local t = {}
	local role = luci.http.formvalue("cbid." .. self.config .. "." .. self.sectiontype .. ".role"
	)

	if name and #name > 0 and role then
		if not (string.find(name, "[%c?%p?%s?]+") == nil) then
			m.message = translate("err: Only alphanumeric characters are allowed.")
		else
			if role == "server" then
				local number = utl.trim(sys.exec("uci -q show xl2tpd | grep -c service"))
				if number == "0" then
					t["_name"] = name
					t["enabled"] = "0"
					t["localip"] = "192.168.0.1"
					t["remoteip"] = "192.168.0.20-30"
					uci:section("xl2tpd", "service", "xl2tpd", t)
					uci:save("xl2tpd")
					m2.message = translate("scs: New L2TP server instance created successfully. Configure it now")
				else
					m2.message = translate("Only one instance of L2TP server is allowed.")
				end
			elseif role == "client" then
				uci:foreach("network", "interface", function(x)
					if x[".name"] == name then
						exist = true
						m2.message = translate("err: Can't create new L2TP client instance with the same name.")
					end
				end)

				if not exist then
					t["_name"] = name
					t["enabled"] = "0"
					t["proto"] = "l2tp"
					t["buffering"] = "1"
					uci:section("network", "interface", name,t)
					uci:save("network")
					m2.message = translate("scs: New L2TP client instance created successfully. Configure it now")
				end
			end

		end
	else
		m2.message = translate("To create a new L2TP instance it's name has to be entered!")
	end
end

m2:chain("network")

return m, m2
