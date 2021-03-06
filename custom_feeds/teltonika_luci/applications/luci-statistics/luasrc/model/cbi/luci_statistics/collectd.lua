--[[

Luci configuration model for statistics - general collectd configuration
(c) 2008 Freifunk Leipzig / Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0 

$Id: collectd.lua 6060 2010-04-13 20:42:26Z jow $

]]--

require("luci.sys")


m = Map("luci_statistics",
	translate("Collectd Settings"),
	translate("Collectd is a small daeomon for collecting data from various sources through different plugins. On this page you can change general settings for the collectd daemon."))

-- general config section
s = m:section( NamedSection, "collectd", "luci_statistics" )

-- general.hostname (Hostname)
hostname = s:option( Value, "Hostname", translate("Hostname") )
hostname.default  = luci.sys.hostname()
hostname.optional = true

-- general.basedir (BaseDir)
basedir = s:option( Value, "BaseDir", translate("Base Directory") )
basedir.default = "/var/run/collectd"

-- general.include (Include)
include = s:option( Value, "Include", translate("Directory for sub-configurations") )
include.default = "/etc/collectd/conf.d/*.conf"

-- general.plugindir (PluginDir)
plugindir = s:option( Value, "PluginDir", translate("Directory for collectd plugins") )
plugindir.default = "/usr/lib/collectd/"

-- general.pidfile (PIDFile)
pidfile = s:option( Value, "PIDFile", translate("Used PID file") )
pidfile.default = "/var/run/collectd.pid"

-- general.typesdb (TypesDB)
typesdb = s:option( Value, "TypesDB", translate("Datasets definition file") )
typesdb.default = "/etc/collectd/types.db"

-- general.interval (Interval)
interval = s:option( Value, "Interval", translate("Data collection interval"), translate("Seconds") )
interval.default  = 60
interval.isnumber = true

-- general.readthreads (ReadThreads)
readthreads = s:option( Value, "ReadThreads", translate("Number of threads for data collection") )
readthreads.default  = 5
readthreads.isnumber = true

-- general.fqdnlookup (FQDNLookup)
fqdnlookup = s:option( Flag, "FQDNLookup", translate("Try to lookup fully qualified hostname") )
fqdnlookup.enabled  = "true"
fqdnlookup.disabled = "false"
fqdnlookup.default  = "false"
fqdnlookup.optional = true
fqdnlookup:depends( "Hostname", "" )


return m
