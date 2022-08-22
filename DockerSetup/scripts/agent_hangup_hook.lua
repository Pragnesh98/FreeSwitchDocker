--[[
	The Initial Developer of the Original Code is

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	agent_hangup_hook.lua : DIALER Hangup Hook
--]]

	api = freeswitch.API()
	require "resources.functions.config";

	local uuid = tostring(argv[1])
	api_cmd = "uuid_exists "..tostring(uuid);
	
	uuid_exists = api:executeString(api_cmd);
	if(uuid_exists == "true") then
		api_cmd = "uuid_kill "..tostring(uuid);
		result = api:executeString(api_cmd);
		freeswitch.consoleLog("INFO"," DIALER Kill API : "..tostring(api_cmd).."\t Status : "..tostring(result).."")
	end
