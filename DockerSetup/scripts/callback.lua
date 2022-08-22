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

	local Database = require "resources.functions.database";
	domain_name = session:getVariable("sip_h_X-context");
	caller_id_number = session:getVariable("caller_id_number");
	to_number = session:getVariable("sip_h_X-DID");
	camp_uuid = session:getVariable("sip_h_X-CAMP-UUID");
	domain_uuid = session:getVariable("domain_uuid");
	
	if (camp_uuid == "" or camp_uuid == nil or camp_uuid == "nil") then
		freeswitch.consoleLog("notice","[callback] :CAMP UUID is NULL\n");
	else
		api_cmd = "curl --insecure --location --request POST 'https://heptadial.com:10707/addCallback' --header 'Content-Type: application/json' --data-raw '{\"domain_uuid\":\""..tostring(domain_uuid).."\",\"camp_uuid\":\""..tostring(camp_uuid).."\",\"from\":\""..tostring(caller_id_number).."\",\"to\":\""..tostring(to_number).."\"}'"
		freeswitch.consoleLog("notice","[callback] : api_cmd : "..tostring(api_cmd));
		api_response = api:execute("system",api_cmd)
		freeswitch.consoleLog("notice","[callback] : api_response : "..tostring(api_response));
		session:execute("playback","/usr/local/freeswitch/sounds/callback.wav");
	end
