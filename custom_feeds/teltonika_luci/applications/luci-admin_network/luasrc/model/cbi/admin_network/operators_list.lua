
m = Map("operctl", translatef("Operators list"))

s1 = m:section(NamedSection, "general", "operctl", translate("Settings"))

o = s1:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

function o.write(self, section, value)
	local conf_val = m.uci:get(self.config, section, self.option)
	if value == "0" and value ~= conf_val then
		require "teltonika_lua_functions"
		if not fileExists("/var/run/", "operctl.pid") then
			os.execute("/etc/init.d/gsmd restart 2>/dev/null")
		end
	end
	m.uci:set(self.config, section, self.option, value)
end

o = s1:option(ListValue, "mode", translate("Mode"))
	o:value("whitelist", "White list")
	o:value("blacklist", "Blacklist")

s = m:section(TypedSection, "list", translate("Operators List"));
s.addremove = true
s.anonymous = true
s.sortable = true
s.template = "cbi/tblsection"

o = s:option(Value, "name", translate("Name"))

o = s:option(Value, "code", translate("Operator code"))
	o.datatype = "integer"

return m