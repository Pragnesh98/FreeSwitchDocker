--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

	require "resources.functions.config";
	debug["sql"] = false;
	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end
	
	api = freeswitch.API();
	--beep_detetcted = 0;
	local Database = require "resources.functions.database";
	domain_name = session:getVariable("sip_h_X-context");
	beep_detected = session:getVariable("beep_detetcted");
	
	if beep_detected == nil then
		beep_detetcted = 0;
	else
		freeswitch.consoleLog("notice","Beep_detected : "..beep_detected.."\n");
	end
