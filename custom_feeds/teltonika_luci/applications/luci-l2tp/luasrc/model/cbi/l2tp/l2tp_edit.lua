local sys = require("luci.sys")
local uci = require("luci.model.uci").cursor()
local utl = require "luci.util"
local dsp = require "luci.dispatcher"

local VPN_INST

local function cecho(string)
	sys.call("echo \"vpn: " .. string .. "\" >> /tmp/log.log")
end

if arg[1] then
	VPN_INST = arg[1]
	if string.sub(VPN_INST, 1, 2) == "c_" then
		mode="CLIENT"
		VPN_INST = string.sub(VPN_INST, 3)
	elseif string.sub(VPN_INST, 1, 2) == "s_" then
		mode="SERVER"
		VPN_INST = string.sub(VPN_INST, 3)
	else
		return nil
	end
else
	return nil
end

local o

if mode == "CLIENT" then
	local m = Map("network", translatef("L2TP Client Instance: %s", VPN_INST:gsub("^%l", string.upper)), "")
	m.redirect = dsp.build_url("admin/services/vpn/l2tp/")
	local s = m:section( NamedSection, VPN_INST, "interface", translate("Main Settings"), "")

	o = s:option( Flag, "enabled", translate("Enable"), translate("Check the box to enable the L2PT function") )
	o.forcewrite = true
	o.rmempty = false
	function o.write(self, section, value)
		m.uci:set(self.config, section, "enabled", value)
		if value == "1" then
			m.uci:set(self.config, section, "disabled", "0")
		else
			m.uci:set(self.config, section, "disabled", "1")
		end
		m.uci:set(self.config, section, "defaultroute", "0")
		m.uci:set(self.config, section, "checkup_interval", "20")
	end
	o = s:option( Value, "server", translate("Server"), translate("Specifies the server IP address") )
	o.datatype = "ip4addr"
	o = s:option( Value, "username", translate("Username"), translate("Specifies the server autorisation username") )
	o = s:option( Value, "password", translate("Password"), translate("Specifies the server autorisation password") )
	o.password = true

	return m
elseif mode == "SERVER" then

	local name = utl.trim(sys.exec("uci get -q xl2tpd." .. VPN_INST .. "._name"))

	local m = Map("xl2tpd", translatef("L2TP Server Instance: %s", name:gsub("^%l", string.upper)), "")
	m.redirect = dsp.build_url("admin/services/vpn/l2tp/")
	local s = m:section( NamedSection, "xl2tpd", "service", translate("Main Settings"), "")

	o = s:option( Flag, "enabled", translate("Enable"), translate("Enable current configuration") )
	o.forcewrite = true
	o.rmempty = false

	o = s:option( Value, "localip", translate("Local IP"), translate("Server IP address, e.g. 192.168.0.1") )
	o.datatype = "ip4addr"

	start = s:option( Value, "start", translate("Remote IP range begin"), translate("IP address leases begin, e.g. 192.168.0.20"))
	start.datatype = "ip4addr"
	start.default = "192.168.0.20"

	limit = s:option( Value, "limit", translate("Remote IP range end"), translate("IP address leases end, e.g. 192.168.0.30, but < 256"))
	limit.datatype = "ip4addr"
	limit.default = "192.168.0.30"

	function limit.validate(self, value, section)
		begin = luci.http.formvalue("cbid.xl2tpd.xl2tpd.start")
		theend = luci.http.formvalue("cbid.xl2tpd.xl2tpd.limit")
		o1,o2,o3,o4 = begin:match("(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)" )
		p1,p2,p3,p4 = theend:match("(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)" )

		if o1 < p1 then
			return value
		elseif o1 == p1 and o2 < p2 then
			return value
		elseif o1 == p1 and o2 == p2 and o3 < p3 then
			return value
		elseif o1 == p1 and o2 == p2 and o3 == p3 and o4 <= p4 then
			return value
		else
			return nil, "The value of remote IP range begin or end is invalid."
		end
	end


	sc1 = m:section(TypedSection, "login")
	sc1.addremove = true
	sc1.anonymous = true
	sc1.template  = "cbi/tblsection"

	usr = sc1:option(Value, "username", translate("User name"), translate("The user name for authorization with the server"))
	pass = sc1:option(Value, "password", translate("Password"), translate("The password for authorization with the server"))
	pass.password = true

	function m.on_commit(map)
		local t = {}
		local target = ""
		local _name = ""
		local proto = ""
		local dest_port = ""
		local family = ""
		local src = ""

		begin = luci.http.formvalue("cbid.xl2tpd.xl2tpd.start")
		theend = luci.http.formvalue("cbid.xl2tpd.xl2tpd.limit")
		remoteip = begin .."-".. theend
		sys.call("uci set xl2tpd.xl2tpd.remoteip="..remoteip.."; uci commit;")

		local pptpdEnable = m:formvalue("cbid.xl2tpd.xl2tpd.enabled")
		num = utl.trim(sys.exec("uci show firewall | grep -c =rule"))
		for i=0, num do
			target = utl.trim(sys.exec("uci get firewall.@rule["..i.."].target")) or "0"
			_name = utl.trim(sys.exec("uci get firewall.@rule["..i.."]._name")) or "0"
			proto = utl.trim(sys.exec("uci get firewall.@rule["..i.."].proto")) or "0"
			dest_port = utl.trim(sys.exec("uci get firewall.@rule["..i.."].dest_port")) or "0"
			family = utl.trim(sys.exec("uci get firewall.@rule["..i.."].family")) or "0"
			src = utl.trim(sys.exec("uci get firewall.@rule["..i.."].src")) or "0"
			if target == "ACCEPT" and _name == "l2tp" and proto == "udp" and dest_port == "1701" and family == "ipv4" and src == "wan" then
				sys.call("uci delete firewall.@rule["..i.."]")
			end
		end
		if pptpdEnable then
			id = utl.trim(sys.exec("uci add firewall rule"))
			uci:set("firewall", id, "target", "ACCEPT")
			uci:set("firewall", id, "_name", "l2tp")
			uci:set("firewall", id, "proto", "udp")
			uci:set("firewall", id, "dest_port", "1701")
			uci:set("firewall", id, "family", "ipv4")
			uci:set("firewall", id, "src", "wan")
			uci:save("firewall")
			uci:commit("firewall")
			sys.call("/etc/init.d/firewall reload > /dev/null")
			--sys.call("/etc/init.d/xl2tpd stop > /dev/null")
			--sys.call("/etc/init.d/xl2tpd start> /dev/null")

		--else
			--sys.call("/etc/init.d/xl2tpd stop > /dev/null")
		end
	end

	return m


end
