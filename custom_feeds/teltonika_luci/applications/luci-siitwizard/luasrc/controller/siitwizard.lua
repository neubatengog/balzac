--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id: siitwizard.lua 3934 2008-12-23 05:18:08Z jow $

]]--

module "luci.controller.siitwizard"

function index()
	entry({"admin", "network", "siitwizard"}, form("siitwizard"), translate("SIIT 4over6 assistent"), 99)
end
