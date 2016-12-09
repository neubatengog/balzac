--[[
LuCI - Lua Configuration Interface

Copyright 2008 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: trunks.lua 4358 2009-03-21 05:06:45Z jow $

]]--

local ast = require("luci.asterisk")

cbimap = Map("asterisk", translate("Trunks"))
cbimap.pageaction = false

local sip_peers = { }
cbimap.uci:foreach("asterisk", "sip",
	function(s)
		if s.type == "peer" then
			s.name = s['.name']
			s.info = ast.sip.peer(s.name)
			sip_peers[s.name] = s
		end
	end)


sip_table = cbimap:section(TypedSection, "sip", translate("SIP Trunks"))
sip_table.template    = "cbi/tblsection"
sip_table.extedit     = luci.dispatcher.build_url("admin", "asterisk", "trunks", "sip", "%s")
sip_table.addremove   = true
sip_table.sectionhead = translate("Extension")

function sip_table.filter(self, s)
	return s and (
		cbimap.uci:get("asterisk", s, "type") == nil or
		cbimap.uci:get_bool("asterisk", s, "provider")
	)
end

function sip_table.create(self, section)
	if TypedSection.create(self, section) then
		created = section
	else
		self.invalid_cts = true
	end
end

function sip_table.parse(self, ...)
	TypedSection.parse(self, ...)
	if created then
		cbimap.uci:tset("asterisk", created, {
			type     = "friend",
			qualify  = "yes",
			provider = "yes"
		})

		cbimap.uci:save("asterisk")
		luci.http.redirect(luci.dispatcher.build_url(
			"admin", "asterisk", "trunks", "sip", created
		))
	end
end


user = sip_table:option(DummyValue, "username", translate("Username"))

context = sip_table:option(DummyValue, "context", translate("Dialplan"))
context.href = luci.dispatcher.build_url("admin", "asterisk", "dialplan")
function context.cfgvalue(...)
	return AbstractValue.cfgvalue(...) or "(default)"
end

online = sip_table:option(DummyValue, "online", translate("Registered"))
function online.cfgvalue(self, s)
	if sip_peers[s] and sip_peers[s].info.online == nil then
		return "n/a"
	else
		return sip_peers[s] and sip_peers[s].info.online
			and "yes" or "no (%s)" %{
				sip_peers[s] and sip_peers[s].info.Status:lower() or "unknown"
			}
	end
end

delay = sip_table:option(DummyValue, "delay", translate("Delay"))
function delay.cfgvalue(self, s)
	if sip_peers[s] and sip_peers[s].info.online then
		return "%i ms" % sip_peers[s].info.delay
	else
		return "n/a"
	end
end

info = sip_table:option(Button, "_info", translate("Info"))
function info.write(self, s)
	luci.http.redirect(luci.dispatcher.build_url(
		"admin", "asterisk", "trunks", "sip", s, "info"
	))
end

return cbimap