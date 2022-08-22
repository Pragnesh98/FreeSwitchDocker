--[[
	The Initial Developer of the Original Code is

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):

	click2call.lua : Click2call 
--]]
	
	require "resources.functions.config";
	local json = require "resources.functions.lunajson"
	
	debug["info"] = false;
	debug['debug'] = false;

	api = freeswitch.API()
	freeswitch.consoleLog("notice", "[CallBridge] : Click2Call Execution Started.");

	local caller_id_number = argv[1];
	local agent_mobile_number = argv[2];
	local caller_destination_number = argv[3];
	
	callerIDNum = "923119192";
	
	freeswitch.consoleLog("notice", "[CallBridge] : caller_id_number : "..tostring(caller_id_number));
	freeswitch.consoleLog("notice", "[CallBridge] : Agent Mobile Number : "..tostring(agent_mobile_number));
	freeswitch.consoleLog("notice", "[CallBridge] : caller_destination_number : "..tostring(caller_destination_number));

	domain_name = "ucall.co.ao"
	sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");
	
	sofia_str = "{ignore_early_media=true,sip_h_X-ucall=outbound,effective_caller_id_name='"..tostring(callerIDNum).."',effective_caller_id_number="..tostring(callerIDNum)..",origination_caller_id_name='"..tostring(callerIDNum).."',origination_caller_id_number="..tostring(callerIDNum).."}sofia/external/"..tostring(caller_destination_number).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy).."";
	
	freeswitch.consoleLog("notice", "[CallBridge] : leg_a_session sofia_str : "..tostring(sofia_str));
	leg_a_session = freeswitch.Session(sofia_str);
 
	dispo = "None";
	while (leg_a_session:ready() and dispo ~= "ANSWER") do
		dispo = leg_a_session:getVariable("endpoint_disposition")
		freeswitch.consoleLog("notice", "[CallBridge] : call disposition is [" .. dispo .. "]")
		os.execute("sleep 1")
	end -- while
	
 	if leg_a_session:ready() then
 		uuid = leg_a_session:getVariable("uuid")
 		freeswitch.consoleLog("notice", "[CallBridge] : CallBack UUID : "..tostring(uuid));
 
		leg_a_session:setAutoHangup(false);
		
 		leg_a_session:execute("transfer", agent_mobile_number.. " XML callpark");
 -- 		-- Do something good here
	else    -- This means the call was not answered ... Check for the reason
		local obCause = leg_a_session:hangupCause()
		freeswitch.consoleLog("info", "leg_a_session:hangupCause() = " .. obCause )
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
	
