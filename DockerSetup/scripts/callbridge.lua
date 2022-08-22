--[[
--]]
--@BEGIN
	require "resources.functions.config";

	api = freeswitch.API();
	uuid = argv[1]
	leg1uuid = argv[1]
	session = freeswitch.Session(uuid)
	destination_number = session:getVariable("destination_number");


--NOTE -waiting from moxtra for callerID Name & CallerID Number
	callerIDNum = "923119192";
	domain_name = "ucall.co.ao"
	sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");
	
	sofia_str = "{ignore_early_media=true,sip_h_X-ucall=outbound,effective_caller_id_name='"..tostring(callerIDNum).."',effective_caller_id_number="..tostring(callerIDNum)..",origination_caller_id_name='"..tostring(callerIDNum).."',origination_caller_id_number="..tostring(callerIDNum).."}sofia/external/"..tostring(destination_number).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy).."";

	--create a Leg2Session
	new_session = freeswitch.Session(sofia_str);
	dispo = "None";
	
	while (new_session:ready() and dispo ~= "ANSWER") do
		dispo = new_session:getVariable("endpoint_disposition")
		freeswitch.consoleLog("notice", "[CallBridge] : call disposition is [" .. dispo .. "]")
		os.execute("sleep 1")
	end -- while
	
 	if new_session:ready() then
		leg2uuid = new_session:get_uuid();
		logline = "leg2uuid [" .. leg2uuid .. "]";
		freeswitch.consoleLog("notice", "[CallBridge] : "..tostring(logline));
		
		new_session:setAutoHangup(false);
		exestr_cmd = "uuid_bridge " .. leg1uuid .. " " .. leg2uuid;
		logline = "calling api:executeString[" .. exestr_cmd .. "]";
		freeswitch.consoleLog("notice", "[CallBridge] : "..tostring(logline));
		api:executeString(exestr_cmd);
		freeswitch.consoleLog("notice", "[CallBridge] : Lua after api:executeString(...)");

		exestr_cmd = "uuid_exists " .. leg2uuid;
		logline = "calling api:executeString[" .. exestr_cmd .. "]";
		freeswitch.consoleLog("notice", "[CallBridge] : "..tostring(logline));
		if (api:executeString(exestr_cmd) == "false") then
			session:hangup();
		end
		freeswitch.consoleLog("notice", "[CallBridge] : Lua after api:executeString(...)");
	else    -- This means the call was not answered ... Check for the reason
		local obCause = new_session:hangupCause()
		freeswitch.consoleLog("info", "new_session:hangupCause() = " .. obCause )
		if ( obCause == "USER_BUSY" ) then              -- SIP 486
		-- For BUSY you may reschedule the call for later
		elseif ( obCause == "NO_ANSWER" ) then
		-- Call them back in an hour
		elseif ( obCause == "ORIGINATOR_CANCEL" ) then   -- SIP 487
	-- May need to check for network congestion or problems
		else
		-- Log these issues
		end
	end
	
--@END
