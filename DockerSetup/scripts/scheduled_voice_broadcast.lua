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
        local json = require "resources.functions.lunajson"
        debug["sql"] = true;
        --local json
        if (debug["sql"]) then
               local json = require "resources.functions.lunajson"
        end
        api = freeswitch.API();
	local Database = require "resources.functions.database";

        VoiceBroadcastUUID = argv[1]
        DomainUUID = argv[2]
        CallerName = argv[3]
        CallerID = argv[4]
        AMD = argv[5]
        GrpdPhonenum = argv[6]
        GrpdName = argv[7]
        BroadcastType = argv[8]
        if tostring(BroadcastType) == "IVR" then
                IVR = argv[9]
        elseif tostring(BroadcastType) == "Prompts" then
                Prompts = argv[9]
        end
        NoAnswerTimeout = argv[10]
        Prefix = argv[11]
        SipTrunkUUID = argv[12]
	DomainName = argv[13]

        local sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");

        freeswitch.consoleLog("notice", "[VoiceBroadcast] Domain UUID: " .. DomainUUID..", Voice_Broadcast_UUID : "..VoiceBroadcastUUID.."\n");

	dbh = Database.new('system');
        assert(dbh:connected());
       --[[ if (DomainUUID ~= nil) then
		local sql = "SELECT domain_name FROM v_domains "
			.. "WHERE domain_uuid = :domain_uuid ";
		local params = {domain_uuid = DomainUUID};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[VoiceBroadcast] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			domainName = rows["domain_name"];
		end);
	end]]--
        freeswitch.consoleLog("notice", "[VoiceBroadcast] Domain Name: " ..DomainName.."\n");

        api_cmd = "create_uuid"
	origin_uuid_customer = api:executeString(api_cmd)

	local sofia_str = "{sip_h_X-xml_cdr_uuid="..tostring(origin_uuid_customer)..",sip_h_X-siptrunk_uuid="..tostring(SipTrunkUUID)..
		",cc_pstn_siptrunk_uuid="..tostring(SipTrunkUUID)..",domain_name="..tostring(DomainName)..",sip_h_X-context="
		..tostring(DomainName)..",domain_uuid="..tostring(DomainUUID)..",ignore_early_media=true,sip_h_X-ucall=outbound,"..
                "origination_uuid="..origin_uuid_customer.."',originate_timeout='"..tostring(NoAnswerTimeout).."',effective_caller_id_name='"
		..tostring(CallerName).."',effective_caller_id_number="..tostring(CallerID)..
		",origination_caller_id_name='"..tostring(CallerName).."',origination_caller_id_number="
		..tostring(CallerID).."}sofia/external/"..tostring(GrpdPhonenum).."@"..tostring(DomainName)..
		";fs_path=sip:"..tostring(sipproxy).."";

	freeswitch.consoleLog("NOTICE", "[VoiceBroadcast] A-Leg DialString : "..tostring(sofia_str))
	session = freeswitch.Session(sofia_str);

        if(session:ready()) then
	        if tostring(BroadcastType) == "Prompts" then
	        	local sql = "SELECT file_location FROM v_prompts "
	                         .. " WHERE pmt_uuid=:prompts AND domain_uuid=:domain_uuid";
	                local params = {prompts = Prompts, domain_uuid = DomainUUID};
	                if (debug["sql"]) then
	                     freeswitch.consoleLog("notice", "[VoiceBroadcast] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
	                end

	                dbh:query(sql, params, function(rows)
	                         file_location = rows["file_location"];
                                 session:setVariable("voice_broadcast_uuid", tostring(VoiceBroadcastUUID));
	                         session:setVariable("domain_uuid", tostring(DomainUUID));
	                         session:execute("export", "voice_broadcast_uuid="..tostring(VoiceBroadcastUUID));
	                         session:execute("export", "domain_uuid="..tostring(domain_uuid));

	                         session:answer();
	                         session:execute("sleep", "500");
	                         session:execute("playback", "http_cache://http://heptadial.com/"..file_location);
	                         session:execute("sleep", "500");
	                end);
	                session:hangup();
	        elseif tostring(BroadcastType) == "IVR" then
			session:setVariable("ivr_name", tostring(IVR));
                        session:setVariable("domain_uuid", tostring(DomainUUID));
                        session:execute("export", "ivr_name="..tostring(IVR));
                        session:execute("export", "domain_uuid="..tostring(DomainUUID));

                        freeswitch.consoleLog("info", "[DIDLOOKUP] : DID mapped with IVR ["..tostring(IVR).."]")
                        session:execute("transfer", IVR.." XML IVR");
		end
        else
                local hangup_reason = session:hangupCause();
                freeswitch.consoleLog("NOTICE", "[VoiceBroadcast] session:hangupCause() = " .. hangup_reason )
                session:hangup();
        end

