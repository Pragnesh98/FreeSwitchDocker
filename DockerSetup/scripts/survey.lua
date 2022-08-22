--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--include config.lua

	require "resources.functions.config";
	debug["sql"] = false;
	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end
	
	api = freeswitch.API();

	local Database = require "resources.functions.database";
	domain_name = session:getVariable("sip_h_X-context");
	caller_id_number = session:getVariable("caller_id_number");
	to_number = session:getVariable("sip_h_X-DID");
	camp_uuid = session:getVariable("sip_h_X-CAMP-UUID");
	domain_uuid = session:getVariable("domain_uuid");
	cc_callback_enabled = session:getVariable("cc_callback_enabled");
	cc_callback_extension = session:getVariable("cc_callback_extension");

	if (cc_callback_enabled == "true") then
		freeswitch.consoleLog("notice","[SURVEY] : Queue Callback Enabled \n");
		if (camp_uuid == "" or camp_uuid == nil or camp_uuid == "nil") then
			freeswitch.consoleLog("notice","[SURVEY] :CAMP UUID is NULL\n");
		else
			if (cc_callback_extension == "" or cc_callback_extension == nil or cc_callback_extension == "nil") then
				freeswitch.consoleLog("warning","[SURVEY] : cc_callback_extension data is empty\n");
			else
				session:execute("transfer", tostring(cc_callback_extension));
			end
		end
	else
		freeswitch.consoleLog("notice","[SURVEY] : Queue Callback Disabled\n");
	end
