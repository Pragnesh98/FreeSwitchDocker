
	-- Include file
	require "resources.functions.config";
	require "resources.functions.trim";

	debug["info"] = true;
	
	api = freeswitch.API();
	uuid = argv[1];

	cmd = "uuid_exists ".. uuid
	uuid_exists = api:executeString(cmd);

	if uuid_exists == "true" then
		session = freeswitch.Session(uuid);
		
		session:execute("sleep", "2000");
		domain_name = session:getVariable("sip_h_X-context");
		caller_id_number = session:getVariable("caller_id_number");

		api_cmd = "user_data "..tostring(caller_id_number).."@"..tostring(domain_name).." var user_record"
		user_record = api:executeString(api_cmd)
		freeswitch.consoleLog("notice", "user_record : " .. tostring(user_record) .. "\n");

 		if (user_record == "enabled") then
			currentdate = os.date("%Y/%b/%d/")
			recording_file = "/usr/local/freeswitch/recordings/"..tostring(domain_name).."/archive/"..tostring(currentdate)..tostring(uuid)..".wav"

			freeswitch.consoleLog("notice"," : cc_record_filename : "..tostring(recording_file));
			session:execute("record_session", recording_file);
			bridge_uuid = session:getVariable("bridge_uuid");
			if (tostring(bridge_uuid) == nil or bridge_uuid == "_undef_") then
				session:execute("sleep", "2000");
				cmd = "uuid_getvar ".. uuid .. " bridge_uuid"
				bridge_uuid = api:executeString(cmd);
			end
			cmd = "uuid_setvar ".. tostring(uuid) .. " cc_record_filename "..recording_file
			uuid_exists = api:executeString(cmd);
 
			cmd = "uuid_setvar ".. tostring(bridge_uuid) .. " cc_record_filename "..recording_file
			uuid_exists = api:executeString(cmd);
 		end
	end

