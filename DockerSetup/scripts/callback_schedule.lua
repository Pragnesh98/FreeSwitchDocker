--[[
	The Initial Developer of the Original Code is

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):

	Progressive Dialer 
--]]
	
-- 	local cache = require "resources.functions.redisDB"
-- 	local redis = require "resources.functions.redis";
	require "resources.functions.config";
-- 	local json = require "resources.functions.lunajson"
	
-- 	dofile(scripts_dir.."/resources/functions/logger.lua");
-- 	dofile(scripts_dir.."/resources/functions/utility.lua");

	debug["info"] = true;
	debug['debug'] = true;
	debug['sql'] = true;

	api = freeswitch.API()

	freeswitch.consoleLog("NOTICE", "CALLBACK_SCHEDULE..!")
	
	callback_uuid = argv[1];
	domain_uuid = argv[2];
	queue_uuid = argv[3];
	agent_uuid = argv[4];
	siptrunk_uuid = argv[5];
	domain_name = argv[6];
	customer_number = argv[7];
	camp_uuid = argv[8];
	sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");	 

	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end
	
	local Database = require "resources.functions.database";
	dbh = Database.new('system');
	assert(dbh:connected());

	if( agent_uuid ~= nil) then
		local sql = "SELECT agent_id,agent_name FROM v_call_center_agents"
			.. " WHERE call_center_agent_uuid = :call_center_agent_uuid" ;
		local params = {call_center_agent_uuid = agent_uuid};
		if(debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIALER]: ".. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			agent_number = rows["agent_id"];
			agent_name = rows["agent_name"];
		end);
	end

        if( siptrunk_uuid ~= nil) then
                local sql = "SELECT scan_prefix,siptrunk_cid_number FROM v_siptrunks "
                        .. "WHERE siptrunk_uuid = :siptrunk_uuid AND domain_uuid = :domain_uuid";
                local params = {siptrunk_uuid = siptrunk_uuid, domain_uuid=domain_uuid};
                if(debug["sql"]) then
                        freeswitch.consoleLog("notice","[DIALER]: ".. sql .. "; params:" .. json.encode(params) .. "\n");
                end
                dbh:query(sql, params, function(rows)
                        scan_prefix = rows["scan_prefix"];
						siptrunk_cid_number = rows["siptrunk_cid_number"];
                end);
        end

	if(siptrunk_cid_number == "" or siptrunk_cid_number == nil or siptrunk_cid_number == "nil") then
		origination_caller_id_number = "923190068";
		caller_id_name = "923190068"
	else
		caller_id_name = siptrunk_cid_number;
		origination_caller_id_number = siptrunk_cid_number;
	end
	
	freeswitch.consoleLog("NOTICE", "DOMAIN UUID : ["..tostring(domain_uuid).."]")
	freeswitch.consoleLog("NOTICE", "QUEUE : ["..tostring(queue_uuid).."]")
	freeswitch.consoleLog("NOTICE", "Agent_Number : ["..tostring(agent_number).."]")

	local leg_a_session = ""
	local disposition_reason = "UNKNOWN";
	local leg_b_session = "";
	local agent = "";
	local other_loopback_leg_uuid = "";
	local cc_agent_bridged = "false"
-- 	local callStartTime = os.date("%Y-%m-%d %H:%M:%S");
	local proxy = "";
	local direction = "";

	freeswitch.consoleLog("NOTICE", " DESTINATION QUEUE")
	

	api_cmd = "user_data "..tostring(agent_number).."@"..tostring(domain_name).." var hold_music"
        hold_music = api:executeString(api_cmd)
        freeswitch.consoleLog("notice", "API CMD : " .. tostring(api_cmd) .. "\n");
	
	sofia_str="{media_webrtc=true,sip_h_X-context="..tostring(domain_name).."}sofia/internal/"..tostring(agent_number).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy);
	
	freeswitch.consoleLog("NOTICE", " DialString : "..tostring(sofia_str));
	leg_a_session = freeswitch.Session(sofia_str);
	
	uuid = leg_a_session:getVariable("uuid");
	freeswitch.consoleLog("INFO"," CallBack loopback a-leg UUID : "..tostring(uuid));
	--leg_a_session:setVariable("park_after_bridge","true")


        if(hold_music) then
                freeswitch.consoleLog("notice", "Caller Destination MOH  : " .. tostring(hold_music) .. "\n");
                leg_a_session:setVariable("dst_hold_music", tostring(hold_music));
        end

	api_cmd = "user_data "..tostring(agent_number).."@"..tostring(domain_name).." var user_record"
        user_record = api:executeString(api_cmd)
        freeswitch.consoleLog("notice", "user_record : " .. tostring(user_record) .. "\n");
      
    if(user_record == "enabled") then
                api_cmd = "eval ${strftime(%Y/%m/%d)}";
                timestamp = api:executeString(api_cmd)
                cc_record_filename = "/var/lib/freeswitch/recordings/"..tostring(domain_name).."/"..tostring(timestamp).."/"..tostring(uuid)..".wav";
                leg_a_session:setVariable("cc_record_filename",cc_record_filename);
                leg_a_session:execute("export", "execute_on_answer=record_session "..tostring(cc_record_filename));
                freeswitch.consoleLog("notice", "cc_record_filename : " .. tostring(cc_record_filename) .. "\n");
    end


	if(not leg_a_session:ready()  and domain_name ~= nil) then
		disposition_reason = "TIMEOUT"
	end 

	if(leg_a_session:ready()) then
		freeswitch.consoleLog("notice","Leg a answered\n");
		agent_uuid = uuid;
		api_cmd = "create_uuid"
		origin_uuid_customer = api:executeString(api_cmd)

		local sql = "SELECT agent_id FROM v_call_center_agents"
			.. " WHERE agent_id = :agent_id AND domain_uuid = :domain_uuid" ;
		local params = {agent_id =customer_number, domain_uuid = domain_uuid};
		if(debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIALER]: ".. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			agent_no = rows["agent_id"];
		end);
		freeswitch.consoleLog("notice","[CALLBACK] agent_number = "..tostring(agent_no).."\n");		
		if(agent_no ~= nil) then

			sofia_str="{media_webrtc=true,domain_uuid="..tostring(domain_uuid)..",sip_h_X-CAMP-UUID="..tostring(camp_uuid)..",sip_h_X-QUEUE-UUID="..tostring(queue_uuid)..",agent_number="..tostring(agent_number)..",sip_h_X-context="..tostring(domain_name).."}sofia/internal/"..tostring(agent_no).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy);
	
			freeswitch.consoleLog("NOTICE", " CallBack Dialstring : "..tostring(sofia_str));
			
		else 

			sofia_str = "{domain_name="..tostring(domain_name)..",sip_h_X-context="..tostring(domain_name)..",sip_h_X-siptrunk_uuid="..tostring(siptrunk_uuid)..",cc_pstn_siptrunk_uuid="..tostring(siptrunk_uuid)..",sip_h_X-CAMP-UUID="..tostring(camp_uuid)..",sip_h_X-QUEUE-UUID="..tostring(queue_uuid)..",agent_number="..tostring(agent_number)..",agent_name="..tostring(agent_name)..",domain_uuid="..tostring(domain_uuid)..",ignore_early_media=true,sip_h_X-ucall=outbound,call_type=SCHEDULED,origination_caller_id_name='"..tostring(origination_caller_id_number).."',origination_caller_id_number="..tostring(origination_caller_id_number).."}sofia/external/"..tostring(customer_number).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy).."";
			freeswitch.consoleLog("INFO"," CallBack Customer Call DialString : "..tostring(sofia_str));
		end
			
			leg_b_session = freeswitch.Session(sofia_str,leg_a_session);
			leg_b_session:setAutoHangup(false);
			leg_a_session:setAutoHangup(false);
		
			--cmd = "uuid_transfer ".. agent_uuid .." -both customeragent XML customeragent"
			--result = api:executeString(cmd);

			if(leg_b_session:ready()) then
				if(leg_b_session:answered()) then
					freeswitch.consoleLog("notice","Leg b answered\n");
                
					freeswitch.bridge(leg_a_session,leg_b_session);
					freeswitch.consoleLog("notice","After bridge\n");
					api_cmd = "uuid_setvar "..tostring(origin_uuid_customer).." session_in_hangup_hook true"
					session_in_hangup_hook = api:executeString(api_cmd)
					api_cmd = "uuid_setvar "..tostring(origin_uuid_customer).." api_hangup_hook 'lua agent_hangup_hook.lua "..tostring(agent_uuid).."'"
					api_hangup_hook = api:executeString(api_cmd)
				
					--leg_b_session:setVariable("park_after_bridge","true")
					leg_b_session:setVariable("hangup_after_conference","false")
					cmd = "uuid_bridge "..origin_uuid_customer.." "..agent_uuid;
					result = api:executeString(cmd);
					freeswitch.consoleLog("INFO"," CallBack Call bridge API : "..cmd.."\t Status : "..result.."")

					disposition_reason = "SUCCESS"
					--if (leg_b_session:hangup()) then
						leg_a_session:hangup();
					--end
				end
			else
				local hangup_reason = leg_b_session:hangupCause();
				freeswitch.consoleLog("NOTICE", "leg_b_session:hangupCause() = " .. hangup_reason )

				leg_b_session:hangup();
				leg_a_session:hangup();
			end

	end

	
	
	
