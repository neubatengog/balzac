--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: forwards.lua 8117 2011-12-20 03:14:54Z jow $
]]--

local ds = require "luci.dispatcher"
local ft = require "luci.tools.input-output"

m = Map("ioman", translate("Input/Output"),	translate("Create rules for Input/Output configuration."))

s = m:section(TypedSection, "ioman", translate("Check Analog"))

interval = s:option(Value, "interval", translate("Interval [sec]"), translate("Interval to check analog input value"))
interval.default = "5"
interval.datatype = "range(1,999999)"
--
-- Port Forwards
--
s = m:section(TypedSection, "rule", translate("Input Rules"))
s.template  = "cbi/tblsection"
s.addremove = true
s.anonymous = true
s.sortable  = true
s.extedit   = ds.build_url("admin/services/input-output/inputs/%s")
s.template_addremove = "input-output/cbi_addinput"
s.novaluetext = translate("There are no inputs rules created yet")

function s.create(self, section)
	local t = m:formvalue("_newinput.type")
	local tr = m:formvalue("_newinput.triger")
	local tr2 = m:formvalue("_newinput.triger2")
	local tr3 = m:formvalue("_newinput.triger3")
	local a = m:formvalue("_newinput.action")

	created = TypedSection.create(self, section)
	self.map:set(created, "type",   t)
	if tr then
		self.map:set(created, "triger", tr)
	end
	if tr2 then
		self.map:set(created, "triger", tr2)
	end
	if tr3 then
		self.map:set(created, "triger", tr3)
	end
	self.map:set(created, "action", a)
	if t == "analog" then
		self.map:set(created, "rule", "false")
	end
end

function s.parse(self, ...)
	TypedSection.parse(self, ...)
	if created then
		m.uci:save("ioman")
		luci.http.redirect(ds.build_url("admin/services/input-output/inputs", created	))
	end
end
src = s:option(DummyValue, "type", translate("Type"), translate("Specifies type of input rule"))
src.rawhtml = true
src.width   = "18%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "type")
	local t = self.map:get(s, "triger")
	--os.execute("echo \"l"..z.."l\" >>/tmp/log.log")
	--return z
	if z == "digital1" then
		return translatef("Digital")
	elseif z == "digital2" then
		return translatef("Digital isolated")
	elseif z == "analog" then
		return translatef("Analog")
	else
	    return translatef("NA")
	end
end

src = s:option(DummyValue, "triger", translate("Trigger"), translate("Specifies trigger of input rule"))
src.rawhtml = true
src.width   = "18%"
function src.cfgvalue(self, s)
	local t = self.map:get(s, "triger")
	local z = self.map:get(s, "type")
	local min_v = self.map:get(s, "min")
	local max_v = self.map:get(s, "max")
	local min_max_line = ""
	if min_v == nil and max_v == nil then
		min_max_line = "( 0V - 0V )"
	end
	if min_v == nil then
		min_v = "0"
	end
	if max_v == nil then
		max_v = "24"
	end
	if min_max_line == "" then
		min_max_line = "( " .. min_v .. "V - " .. max_v .. "V )"
	end
	local max_v = self.map:get(s, "max")
	if t == "no" and z == "digital1" then
		return translatef("Input open")
	elseif t == "nc" and z == "digital1" then
		return translatef("Input shorted")
	elseif t == "both" and z == "digital1" then
		return translatef("Both")

	elseif t == "no" and z == "digital2" then
		return translatef("Low logic level")
	elseif t == "nc" and z == "digital2" then
		return translatef("High logic level")
	elseif t == "both" and z == "digital2" then
		return translatef("Both")

	elseif t == "in" and z == "analog" then
		return translatef("In" .. " " .. min_max_line)
	elseif t == "out" and z == "analog" then
		return translatef("Out" .. " " .. min_max_line)
	else
	    return translatef("NA")
	end
end

src = s:option(DummyValue, "action", translate("Action"), translate("Specifies action of input rule"))
src.rawhtml = true
src.width   = "18%"
function src.cfgvalue(self, s)
	local z = self.map:get(s, "action")
	if z == "sendSMS" then
		return translatef("Send SMS")
	elseif z == "sendEmail" then
		return translatef("Send Email")
	elseif z == "changeSimCard" then
		return translatef("Change SSIM Card")
	elseif z == "changeProfile" then
		return translatef("Change Profile")
	elseif z == "wifion" then
		return translatef("Turn on WiFi")
	elseif z == "wifioff" then
		return translatef("Turn off WiFi")
	elseif z == "reboot" then
		return translatef("Reboot")
	elseif z == "output" then
		local output_type = self.map:get(s, "outputnb")
		if output_type == "1" then
			output_type = "Open collector"
		elseif output_type == "2" then
			output_type = "Relay output"
		else
			output_type = "None"
		end
		return translatef("Output (" .. output_type .. ")" )
	else
	    return translatef("NA")
	end
end

ft.opt_enabled(s, Flag, translate("Enable"), translate("Uncheck to disable input rule, Check to enable input rule")).width = "18%"

local save = m:formvalue("cbi.apply")
if save then
	--Delete all usr_enable from ioman config
	m.uci:foreach("ioman", "rule", function(s)
		ioman_inst = s[".name"] or ""
		iomanEnable = m:formvalue("cbid.ioman." .. ioman_inst .. ".enabled") or "0"
		ioman_enable = s.enabled or "0"
		if iomanEnable ~= ioman_enable then
			m.uci:foreach("ioman", "rule", function(a)
				ioman_inst2 = a[".name"] or ""
				local usr_enable = a.usr_enable or ""
				if usr_enable == "1" then
					m.uci:delete("ioman", ioman_inst2, "usr_enable")
				end
			end)
		end
	end)
	m.uci:save("ioman")
	m.uci.commit("ioman")
end


return m
