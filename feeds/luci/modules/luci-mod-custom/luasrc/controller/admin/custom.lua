-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.admin.custom", package.seeall)

function index()
	entry({"admin", "custom", "overview"}, template("admin_custom/index"), _("Overview"), 1)

	entry({"admin", "custom", "wan"}, cbi("admin_custom/wan"), _("WanConf"), 2)
	
	entry({"admin", "custom", "lan"}, cbi("admin_custom/lan"), _("LanConf"), 3)

	entry({"admin", "custom", "wireless"}, cbi("admin_custom/wireless"), _("Wireless"), 4)

	entry({"admin", "custom", "service"}, cbi("admin_custom/service"), _("Service"), 5)

        entry({"admin", "custom", "reboot"}, template("admin_custom/reboot"), _("Reboot"), 90)
	entry({"admin", "custom", "reboot", "call"}, post("action_reboot"))
end

function action_reboot()
        luci.sys.reboot()
end
