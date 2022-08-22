
	-- Include file
	require "resources.functions.config";
	require "resources.functions.trim";

	debug["info"] = true;
	
	api = freeswitch.API();
	uuid = argv[1];

	cmd = "uuid_exists ".. uuid
	uuid_exists = api:executeString(cmd);

	freeswitch.consoleLog("notice", "Ringing Event : " .. tostring(uuid) .. "\n");
	
	if uuid_exists == "true" then
		
		cmd = "callcenter_config timestamp now"
		cc_bridge_start_epoch = api:executeString(cmd);

		session = freeswitch.Session(uuid);
		cmd = "uuid_setvar ".. tostring(uuid) .. " cc_bridge_start_epoch "..cc_bridge_start_epoch
		api_res = api:executeString(cmd);
		freeswitch.consoleLog("notice", "API : " .. tostring(cmd) .. "\n");
	--	cmd = "uuid_setvar ".. tostring(uuid) .. " cc_bridge_start_epoch "..recording_file
	--	uid_exists = api:executeString(cmd);
	end

