--[[`
	The Initial Developer of the Original Code is

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):

	Telemo Dialer 
--]]

	require "resources.functions.config";

	debug["info"] = true;
	debug['debug'] = true;
	debug['sql'] = false;

	api = freeswitch.API()

	freeswitch.consoleLog("NOTICE", "Outbound Dialer Started..!")

	JobUUID = argv[1];
	CampUUID = argv[2];
	DomainUUID = argv[3];
	SipTrunkUUID = argv[4];
	JobDetailUUID = argv[5];
	CampActivityUUID = argv[6];
	CampDialer = argv[7];
	CampAMD = argv[8];
	CampCallerID = argv[9];
	CampCallerName = argv[10];
	CampNumberMasking = argv[11];
	CampRecording = argv[12];
	CampWrapUpTime = argv[13];
	RingTimeout = argv[14];
	AnswerTimeout = argv[15];
	JobPhonenum = argv[16];
	JobPhonename = argv[17];
	FailOverTrunkUUID = argv[18];
	AgentUUID = argv[19];
	State = "PENDING"
	leg_a_session = ""
	disposition_reason = "UNKNOWN";
	leg_b_session = "";
 
	local sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");

	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end

	local Database = require "resources.functions.database";
	local dbh = Database.new('system');
	assert(dbh:connected());
	if (DomainUUID ~= nil) then
		local sql = "SELECT domain_name FROM v_domains "
			.. "WHERE domain_uuid = :domain_uuid ";
		local params = {domain_uuid = DomainUUID};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			DomainName = rows["domain_name"];
		end);
	end

	freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."]: Job UUID : ["..tostring(JobUUID).."]")
	freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."]: DOMAIN UUID : ["..tostring(DomainUUID).."]")
	freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."]: Customer Number : ["..tostring(JobPhonenum).."]")
	
	if(CampCallerID == "" or CampCallerID == nil or CampCallerID == "nil") then
		origination_caller_id_number = "Telemo";
		caller_id_name = "Telemo";
	else
		caller_id_name = CampCallerName
		origination_caller_id_number = CampCallerID
	end

	if(tostring(CampDialer) == "PREDICTIVE" or tostring(CampDialer) == "PROGRESSIVE" or tostring(CampDialer) == "auto-dialer") then
		freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] Campaign is Started")

		api_cmd = "create_uuid"
		origin_uuid_customer = api:executeString(api_cmd)

		local sofia_str = "{sip_h_X-xml_cdr_uuid="..tostring(origin_uuid_customer)..",sip_h_X-WRAPUP-TIME="..tostring(CampWrapUpTime)..
			",cc_queue_wrap_up_time="..tostring(CampWrapUpTime)..",sip_h_X-siptrunk_uuid="..tostring(SipTrunkUUID)..
			",cc_pstn_siptrunk_uuid="..tostring(SipTrunkUUID)..",domain_name="..tostring(DomainName)..",sip_h_X-context="
			..tostring(DomainName)..",domain_uuid="..tostring(DomainUUID)..",sip_h_X-CAMP-UUID='"..tostring(CampUUID)..
			"',ignore_early_media=true,sip_h_X-ucall=outbound,origination_uuid="..origin_uuid_customer.."',originate_timeout='"
			..tostring(RingTimeout).."',ccpre_answer_timeout='"..tostring(AnswerTimeout).."',effective_caller_id_name='"
			..tostring(caller_id_name).."',effective_caller_id_number="..tostring(caller_id_name)..
			",origination_caller_id_name='"..tostring(caller_id_name).."',origination_caller_id_number="
			..tostring(caller_id_name).."}sofia/external/"..tostring(JobPhonenum).."@"..tostring(DomainName)..
			";fs_path=sip:"..tostring(sipproxy).."";

		freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] A-Leg DialString : "..tostring(sofia_str))
		leg_a_session = freeswitch.Session(sofia_str);

		uuid = leg_a_session:getVariable("uuid")
		freeswitch.consoleLog("INFO","["..tostring(CampDialer).."] CallBack loopback a-leg UUID : "..tostring(uuid));
	--	leg_a_session:setVariable("park_after_bridge","true")
	
		if(not leg_a_session:ready() and domain_name ~= nil) then
			disposition_reason = "TIMEOUT"
		end

		if(leg_a_session:ready()) then
			freeswitch.consoleLog("notice","["..tostring(CampDialer).."] Leg a answered\n");
			agent_uuid = "";
			api_cmd = "create_uuid"
			origin_uuid_customer = api:executeString(api_cmd)

			local sofia_str = "{media_webrtc=true,sip_h_X-context="..tostring(DomainName)..",domain_uuid="
				..tostring(DomainUUID)..",origination_caller_id_name='"..tostring(JobPhonename)..
				"',origination_caller_id_number="..tostring(JobPhonenum).."}loopback/"
				..tostring(CampActivityUUID).."/callcenter/XML";
	
			freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] B-Leg Dialstring : "..tostring(sofia_str));
			leg_b_session = freeswitch.Session(sofia_str);
			leg_b_session:setAutoHangup(false);
			leg_a_session:setAutoHangup(false);	

			if(leg_b_session:ready()) then
				if(leg_b_session:answered()) then
					freeswitch.consoleLog("notice","["..tostring(CampDialer).."] Leg b answered\n");
					freeswitch.bridge(leg_a_session,leg_b_session);
					freeswitch.consoleLog("notice","["..tostring(CampDialer).."] After bridge\n");
					
					api_cmd = "uuid_setvar "..tostring(origin_uuid_customer).." session_in_hangup_hook true"                 		session_in_hangup_hook = api:executeString(api_cmd)
                    api_cmd = "uuid_setvar "..tostring(origin_uuid_customer).." api_hangup_hook 'lua agent_hangup_hook.lua "..tostring(agent_uuid).."'"
                    api_hangup_hook = api:executeString(api_cmd)

					if(CampRecording == true) then
						api_cmd = "eval ${strftime(%Y/%m/%d)}";
						timestamp = api:executeString(api_cmd)
						cc_record_filename = "/var/lib/freeswitch/recordings/"..tostring(domain_name).."/"..tostring(timestamp).."/"..tostring(uuid)..".wav";
						leg_b_session:setVariable("cc_record_filename",cc_record_filename);
						leg_b_session:execute("export", "execute_on_answer=record_session "..tostring(cc_record_filename));
						freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] cc_record_filename : " .. tostring(cc_record_filename) .. "\n");
					end
					disposition_reason = "SUCCESS"
				end
			else 
				local hangup_reason = leg_b_session:hangupCause();
		        freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] leg_b_session:hangupCause() = " .. hangup_reason )
				leg_b_session:hangup();
        		leg_a_session:hangup();
			end
		else
			local hangup_reason = leg_a_session:hangupCause();
   	 		freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] leg_b_session:hangupCause() = " .. hangup_reason )
			leg_a_session:hangup();
		end

	elseif(tostring(CampDialer) == "Preview") then
		freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] Campaign is Started")

		if( AgentUUID ~= nil) then
			local sql = "SELECT agent_id,agent_name FROM v_call_center_agents"
				.. " WHERE call_center_agent_uuid = :call_center_agent_uuid" ;
			local params = {call_center_agent_uuid = AgentUUID};
			if(debug["sql"]) then
				freeswitch.consoleLog("notice", "[DIALER]: ".. sql .. "; params:" .. json.encode(params) .. "\n");
			end
			dbh:query(sql, params, function(rows)
				agent_number = rows["agent_id"];
				agent_name = rows["agent_name"];
			end);
		end

		if(agent_number ~= "") then
			State = "PENDING"
			local sql = "INSERT INTO v_preview_configs(domain_uuid,camp_uuid,agent_uuid,customer_number,customer_name,"
				.."agent_extension,state) VALUES(:domain_uuid,:camp_uuid, :agent_uuid,:customer_number,:customer_name,:agent_extension,:state";
			local params = {domain_uuid = DomainUUID, camp_uuid = CampUUID, agent_uuid = AgentUUID, customer_number = JobPhonenum, customer_name = JobPhonename, agent_extension = agent_number, state = State};

			if(debug[sql]) then
				freeswitch.consoleLog("notice", "[DIALER] SQL : "..sql..";params :"..params.."\n");
			end
			dbh:query(sql, params);
		end

		while true do
			local sql = "SELECT state FROM v_preview_configs"
				.. " WHERE domain_uuid = :domain_uuid AND customer_number = :customer_number AND agent_uuid = :agent_uuid" ;
			local params = {domain_uuid = DomainUUID, customer_number = JobPhonenum, agent_uuid = AgentUUID};
			if(debug["sql"]) then
				freeswitch.consoleLog("notice", "[DIALER]: ".. sql .. "; params:" .. json.encode(params) .. "\n");
			end
			dbh:query(sql, params, function(rows)
				CallState = rows["state"];
			end);

			if(tostring(CallState) == "DIALED" or tostring(CallState) == "SKIP") then
				State = CallState
				break
			end
			session:sleep(1000)
		end

		if(tostring(State) == "DIALED") then
			freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] Agent selects DIALED")

			api_cmd = "create_uuid"
			origin_uuid_customer = api:executeString(api_cmd)

			local sofia_str = "{sip_h_X-xml_cdr_uuid="..tostring(origin_uuid_customer)..",sip_h_X-WRAPUP-TIME="..tostring(CampWrapUpTime)..
			",cc_queue_wrap_up_time="..tostring(CampWrapUpTime)..",sip_h_X-siptrunk_uuid="..tostring(SipTrunkUUID)..
			",cc_pstn_siptrunk_uuid="..tostring(SipTrunkUUID)..",domain_name="..tostring(DomainName)..",sip_h_X-context="
			..tostring(DomainName)..",domain_uuid="..tostring(DomainUUID)..",sip_h_X-CAMP-UUID='"..tostring(CampUUID)..
			"',ignore_early_media=true,sip_h_X-ucall=outbound,origination_uuid="..origin_uuid_customer.."',originate_timeout='"
			..tostring(RingTimeout).."',ccpre_answer_timeout='"..tostring(AnswerTimeout).."',effective_caller_id_name='"
			..tostring(caller_id_name).."',effective_caller_id_number="..tostring(origination_caller_id_number)..
			",origination_caller_id_name='"..tostring(caller_id_name).."',origination_caller_id_number="
			..tostring(origination_caller_id_number).."}sofia/external/"..tostring(JobPhonenum).."@"..tostring(DomainName)..
			";fs_path=sip:"..tostring(sipproxy).."";

			freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] A-Leg DialString : "..tostring(sofia_str))
			leg_a_session = freeswitch.Session(sofia_str);

			uuid = leg_a_session:getVariable("uuid")
			freeswitch.consoleLog("INFO","["..tostring(CampDialer).."] CallBack loopback a-leg UUID : "..tostring(uuid));
	
			if(not leg_a_session:ready() and domain_name ~= nil) then
				disposition_reason = "TIMEOUT"
			end

			if(leg_a_session:ready()) then
				freeswitch.consoleLog("notice","["..tostring(CampDialer).."] Leg a answered\n");
				agent_uuid = "";
				api_cmd = "create_uuid"
				origin_uuid_customer = api:executeString(api_cmd)

				sofia_str="{media_webrtc=true,sip_h_X-context="..tostring(domain_name).."effective_caller_id_name='"
				..tostring(JobPhonename).."',effective_caller_id_number="..tostring(JobPhonenum)..
				",origination_caller_id_name='"..tostring(JobPhonename).."',origination_caller_id_number="
				..tostring(JobPhonenum).."}sofia/internal/"..tostring(agent_number).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy);

				freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] B-Leg Dialstring : "..tostring(sofia_str));
				leg_b_session = freeswitch.Session(sofia_str);
				leg_b_session:setAutoHangup(false);
				leg_a_session:setAutoHangup(false);

				if(leg_b_session:ready()) then
					if(leg_b_session:answered()) then
						freeswitch.consoleLog("notice","["..tostring(CampDialer).."] Leg b answered\n");
						freeswitch.bridge(leg_a_session,leg_b_session);
						freeswitch.consoleLog("notice","["..tostring(CampDialer).."] After bridge\n");
					
						api_cmd = "uuid_setvar "..tostring(origin_uuid_customer).." session_in_hangup_hook true"                 		session_in_hangup_hook = api:executeString(api_cmd)
        	            api_cmd = "uuid_setvar "..tostring(origin_uuid_customer).." api_hangup_hook 'lua agent_hangup_hook.lua "..tostring(agent_uuid).."'"
        	            api_hangup_hook = api:executeString(api_cmd)

						if(CampRecording == true) then
							api_cmd = "eval ${strftime(%Y/%m/%d)}";
							timestamp = api:executeString(api_cmd)
							cc_record_filename = "/var/lib/freeswitch/recordings/"..tostring(domain_name).."/"..tostring(timestamp).."/"..tostring(uuid)..".wav";
							leg_b_session:setVariable("cc_record_filename",cc_record_filename);
							leg_b_session:execute("export", "execute_on_answer=record_session "..tostring(cc_record_filename));
							freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] cc_record_filename : " .. tostring(cc_record_filename) .. "\n");
						end
						disposition_reason = "SUCCESS"
					end
				else 
					local hangup_reason = leg_b_session:hangupCause();
			        freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] leg_b_session:hangupCause() = " .. hangup_reason )
					leg_b_session:hangup();
        			leg_a_session:hangup();
				end
			else
				local hangup_reason = leg_a_session:hangupCause();
   	 			freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] leg_b_session:hangupCause() = " .. hangup_reason )
				leg_a_session:hangup();
			end
		elseif(tostring(State) == "SKIP") then
			freeswitch.consoleLog("NOTICE", "["..tostring(CampDialer).."] Agent selects DIALED")
		end
	end

	if (JobUUID ~= nil and CampUUID ~= nil) then
		local sql = "UPDATE v_job_master SET job_running_calls = ( job_running_calls - 1 ) "
			.. "WHERE (job_uuid =:job_uuid AND  camp_uuid =:camp_uuid) ";
		local params = {job_uuid = JobUUID, camp_uuid = CampUUID};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params);

		local hangup_reason = leg_a_session:hangupCause();
		freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] hangup_reason : "..tostring(hangup_reason).."\n");

		if(State == "SKIP") then
			hangup_reason = State
		end

		if (hangup_reason == "SUCCESS") then
			local sql = "UPDATE  v_job_details SET job_call_status = 'COMPLETED', job_dial_status = 'NULL', job_dial_time = NOW() "
				.. "WHERE (job_detail_uuid =:job_detail_uuid) ";
			local params = {job_detail_uuid = JobDetailUUID};
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
			end
			dbh:query(sql, params);
			freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] Hangup call Successfully\n");
		else 
			local sql = "UPDATE  v_job_details SET job_call_status = '"..tostring(hangup_reason)..
				"', job_dial_status = 'NULL', job_dial_time = NOW() "
				.. "WHERE (job_detail_uuid =:job_detail_uuid) ";
			local params = {job_detail_uuid = JobDetailUUID};
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
			end
			dbh:query(sql, params);
			freeswitch.consoleLog("notice", "["..tostring(CampDialer).."] Hangup call.\n");
			leg_b_session:hangup();
			leg_a_session:hangup();
		end
	end


