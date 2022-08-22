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

	local Database = require "resources.functions.database";
	dbh = Database.new('system');
	assert(dbh:connected());

	dest_queue_uuid = "";
	api = freeswitch.API();
	local event_name = event:getHeader("Event-Name");

	if event_name == "CHANNEL_HOLD" then
		freeswitch.consoleLog("notice", "[events] event_name : ["..event_name.."]\n");
		uuid = event:getHeader("Channel-Call-UUID")
-- 		freeswitch.consoleLog("notice", "[events] Channel-Call-UUID : ["..uuid.."]\n");
		
		serialized = event:serialize('json')
-- 		freeswitch.consoleLog("notice", "[events] Event : ["..serialized.."]\n");
		local json
		json = require "resources.functions.lunajson"
		local encode = json.decode (serialized)
	
-- 		freeswitch.consoleLog("notice", "[events] Event-Date-Timestamp  : ["..encode["Event-Date-Timestamp"].."]\n");
	end

	if event_name == "CHANNEL_PROGRESS_MEDIA" then
                freeswitch.consoleLog("notice", "[events] event_name : ["..event_name.."]\n");
                uuid = event:getHeader("Channel-Call-UUID")
             --   freeswitch.consoleLog("notice", "[events] Channel-Call-UUID : ["..uuid.."]\n");

                domainUUID = event:getHeader("variable_domain_uuid");
             --   freeswitch.consoleLog("notice", "[events] domainUUID : ["..domainUUID.."]\n");

                createdEpoch = event:getHeader("Event-Date-Timestamp");
             --   freeswitch.consoleLog("notice", "[events] createdEpoch : ["..createdEpoch.."]\n");
                
		callerDirection = event:getHeader("Caller-Direction")
             --   freeswitch.consoleLog("notice", "[events] caller-direction : ["..callerDirection.."]\n");
               
                callerUserName = event:getHeader("Caller-Username")
             --   freeswitch.consoleLog("notice", "[events] caller-username : ["..callerUserName.."]\n");
 
                callerDestinationNumber = event:getHeader("Caller-Destination-Number")
             --   freeswitch.consoleLog("notice", "[events] caller-destination-number : ["..callerDestinationNumber.."]\n");
	
                campUUID = event:getHeader("variable_sip_h_X-CAMP-UUID")
             --   freeswitch.consoleLog("notice", "[events] campUUID : ["..campUUID.."]\n");

                sipTrunkUUID = event:getHeader("variable_sip_h_X-siptrunk_uuid")
             --   freeswitch.consoleLog("notice", "[events] sipTrunkUUID : ["..sipTrunkUUID.."]\n");

                agentUUID = event:getHeader("variable_sip_h_X-AGENT-USER-NAME")
           --     freeswitch.consoleLog("notice", "[events] agentUUID : ["..agentUUID.."]\n");

		status = "RINGING";
         --       freeswitch.consoleLog("notice", "[events] status : ["..status.."]\n");
	
		local sql = "INSERT INTO active_calls(uuid, camp_uuid, domain_uuid,  username,  name,  customer_number,  created_epoch,call_direction,agent_uuid, siptrunk_uuid, status) VALUES( :uuid, :camp_uuid, :domain_uuid, :username, :name, :customer_number, :created_epoch, :call_direction, :agent_uuid, :siptrunk_uuid, :status)";
		local params = {uuid = uuid, camp_uuid = campUUID, domain_uuid = domainUUID, username = callerUserName, name = callerUserName, customer_number = callerDestinationNumber, created_epoch = createdEpoch ,call_direction = callerDirection, agent_uuid = agentUUID, siptrunk_uuid = sipTrunkUUID, status = status};

		if(debug[sql]) then 
			freeswitch.consoleLog("notice", "[Events] SQL : "..sql..";params :"..params.."\n");
		end
		dbh:query(sql, params);
		
		serialized = event:serialize('json')
       --         freeswitch.consoleLog("notice", "[events] Event : ["..serialized.."]\n");
        end

	if event_name == "CHANNEL_UNHOLD" then
		freeswitch.consoleLog("notice", "[events] event_name : ["..event_name.."]\n");
		uuid = event:getHeader("Channel-Call-UUID")
		direction = event:getHeader("variable_direction")

 		freeswitch.consoleLog("notice", "[events] direction : ["..tostring(direction).."]\n");
		if(direction == "outbound") then
			a_uuid = event:getHeader("variable_sip_h_X-xml_cdr_uuid");
			hold_accum_time = event:getHeader("Caller-Channel-Hold-Accum");
-- 			freeswitch.consoleLog("notice", "[events] : a_uuid : ["..tostring(a_uuid).."]\n");
			cmd = "uuid_setvar ".. tostring(a_uuid) .. " callee_hold_accum_time "..hold_accum_time
			api_res = api:executeString(cmd);
 			freeswitch.consoleLog("notice", "[events] callee_hold_accum_time : ["..tostring(hold_accum_time).."]\n");
		end
		
-- 		freeswitch.consoleLog("notice", "[events] Channel-Call-UUID : ["..uuid.."]\n");
		
		serialized = event:serialize('json')
 		freeswitch.consoleLog("notice", "[events] Event : ["..serialized.."]\n");
		
		local json
		json = require "resources.functions.lunajson"
		local encode = json.decode (serialized)
-- 		freeswitch.consoleLog("notice", "[events] Event-Date-Timestamp  : ["..encode["Event-Date-Timestamp"].."]\n");
	end

	if event_name == "CHANNEL_ANSWER" then
		freeswitch.consoleLog("notice","[events] event_name : ["..event_name.."]\n");

		uuid = event:getHeader("Channel-Call-UUID");
		
		call_type = event:getHeader("variable_call_type");
		if (call_type == "SCHEDULED") then
			caller_id_number = event:getHeader("variable_agent_number");
			caller_id_name = event:getHeader("variable_agent_name");
		else
         	        caller_id_number = event:getHeader("Caller-Caller-ID-Number");
                	caller_id_name  = event:getHeader("Caller-Caller-ID-Name");
	       end
                
                destination_number = event:getHeader("Caller-Destination-Number");
	       
		domain_uuid = event:getHeader("variable_domain_uuid");

		if(domain_uuid ~= nil) then
			local sql = "SELECT agent_name,agent_id FROM v_call_center_agents WHERE agent_id = :agent_id AND domain_uuid = :domain_uuid";
			local params = {agent_id = caller_id_number, domain_uuid = domain_uuid};
			dbh:query(sql, params, function(rows)
				agent_name = rows.agent_name;
				agent_number = rows.agent_id;
			end);
	
			if (agent_number ~= nil) then
				username = agent_number;
				name = agent_name;
				customer_number = destination_number;
				call_direction = "outbound";
			else
				local sql = "SELECT agent_name,agent_id FROM v_call_center_agents WHERE agent_id = :agent_id AND domain_uuid = :domain_uuid";
				local params = {agent_id = destination_number, domain_uuid = domain_uuid};
				dbh:query(sql, params, function(rows)
					agent_name = rows.agent_name;
					agent_number = rows.agent_id;
				end);
				if (agent_number ~= nil) then
					username = agent_number;
					name = agent_name;
					customer_number = caller_id_number;
					call_direction = "inbound";
				else
					username = caller_id_number;
					name = caller_id_name;
					customer_number = destination_number;
					call_direction = "outbound";
				end
			end
		else
			username = caller_id_number;
			name = caller_id_name;
			customer_number = destination_number;
		end

		a_uuid = event:getHeader("variable_sip_h_X-xml_cdr_uuid");
		if (a_uuid ~= nil) then
			cmd = "uuid_setvar ".. tostring(a_uuid) .. " direction "..call_direction
			api_res = api:executeString(cmd);
		end

		agent_uuid = event:getHeader("variable_sip_h_X-AGENT-USER-NAME");
		if( agent_uuid == nil) then
			agent_uuid = 0;
		end
		
		siptrunk_uuid = event:getHeader("variable_cc_pstn_siptrunk_uuid");
		if (a_uuid ~= nil) then
			if (siptrunk_uuid ~= nil) then
				cmd = "uuid_setvar "..tostring(a_uuid).." siptrunk_uuid "..tostring(siptrunk_uuid)
				api_res = api:executeString(cmd);
			else
				siptrunk_uuid = 0;
			end
		end

                created_epoch = event:getHeader("Caller-Channel-Answered-Time");

                ivr_uuid = event:getHeader("variable_ivr_name");
       		if ivr_uuid == nil then
			ivr_uuid = 0;
		end

		campaign_uuid = event:getHeader("variable_sip_h_X-CAMP-UUID");
		
		Destapp = event:getHeader("variable_sip_h_X-DESTAPP");

               	queue_uuid = event:getHeader("variable_sip_h_X-QUEUE-UUID");

		if(queue_uuid ~= nil ) then
                	freeswitch.consoleLog("notice", "[events] queue_uuid : ["..tostring(queue_uuid).."]\n");
		else
			queue_uuid  = event:getHeader("variable_cc_queue");
		end

		if tostring(queue_uuid) == "nil" then
			queue_uuid = 0;

		end
               	freeswitch.consoleLog("notice", "[events] queue_uuid : ["..tostring(queue_uuid).."]\n");

		status = "INCALL";
                freeswitch.consoleLog("notice", "[events] status : ["..status.."]\n");

		local sql = "SELECT uuid FROM active_calls WHERE uuid = :uuid";
		local params = {uuid = uuid};
		dbh:query(sql, params, function(row)
			new_uuid = row.uuid;
		end);

		if (new_uuid == uuid and Destapp == 'queue') then 
			goto ahead;
		else
			--if queue_uuid ~= "nil" then
			local sql = "UPDATE active_calls SET uuid=:uuid, camp_uuid=:camp_uuid, queue_uuid=:queue_uuid, domain_uuid=:domain_uuid,  username=:username,  name=:name,  customer_number=:customer_number,  created_epoch=:created_epoch,call_direction=:call_direction,agent_uuid=:agent_uuid, siptrunk_uuid=:siptrunk_uuid, ivr_uuid=:ivr_uuid, status=:status";
			local params = {uuid = uuid, camp_uuid = campaign_uuid, queue_uuid = queue_uuid, domain_uuid = domain_uuid, username = username, name = name, customer_number = customer_number, created_epoch = created_epoch ,call_direction = call_direction, agent_uuid = agent_uuid, siptrunk_uuid = siptrunk_uuid, ivr_uuid = ivr_uuid, status = status};

			if(debug[sql]) then 
				freeswitch.consoleLog("notice", "[Events] SQL : "..sql..";params :"..params.."\n");
			end
				dbh:query(sql, params);
		--	end
		end

		serialized = event:serialize('json');
		freeswitch.consoleLog("notice", "[events] Event : ["..serialized.."]\n");
::ahead::
		--freeswitch.consoleLog("notice", "[Events] Same Event\n");
	end

	if event_name == "CHANNEL_HANGUP" then
		freeswitch.consoleLog("notice","[events] event_name : ["..event_name.."]\n");

		--uuid = event:getHeader("Unique-ID");
		uuid = event:getHeader("Channel-Call-UUID");
                --freeswitch.consoleLog("notice", "[events] uuid : ["..tostring(uuid).."]\n");

		dbh:query( "DELETE FROM active_calls WHERE uuid = '"..tostring(uuid).."'");

		hangup_cause = event:getHeader("Hangup-Cause");
		if hangup_cause == "NORMAL_CLEARING" then
			freeswitch.consoleLog("notice", "[events] Hangup_cause : ["..tostring(hangup_cause).."]\n");
			domain_uuid = event:getHeader("variable_domain_uuid");
			if domain_uuid ~= nil then
				
			end
			
		end
		serialized = event:serialize('json');
		--freeswitch.consoleLog("notice", "[events] Event : ["..serialized.."]\n");
	end

	if event_name ==  "CUSTOM" then
	--		freeswitch.consoleLog("notice", "Custom EVENT on\n");
	--		serialized = event:serialize('json');
	--		freeswitch.consoleLog("notice", "[events] Event : ["..serialized.."]\n");
			event_type = event:getHeader("Event-Subclass");
			 --freeswitch.consoleLog("notice", "[events] event_type : ["..tostring(event_type).."]\n");
			if event_type == "amd::machine" then
				freeswitch.consoleLog("notice", " BEEP EVENT detected\n");
				beep_detected = 'true';
				a_uuid = event:getHeader("Unique-ID");
				if (a_uuid ~= nil) then
					cmd = "uuid_setvar ".. tostring(a_uuid) .. " beep_detected "..beep_detected
					api_res = api:executeString(cmd);
			 		freeswitch.consoleLog("notice", "[events] beep_detected : ["..tostring(beep_detected).."]\n");
				end

					uuid = event:getHeader("Unique-ID");
					cmd = "uuid_kill ".. tostring(uuid)
					api_res = api:executeString(cmd);
			 		freeswitch.consoleLog("notice", "[events] Call Hangup because beep detected\n");
			end
	end

	if event_name == "DTMF" then
		freeswitch.consoleLog("notice","[events] event_name : ["..event_name.."]\n");

		unique_id = event:getHeader("Unique-ID");
		--freeswitch.consoleLog("notice","[events] Unique_ID : ["..tostring(unique_id).."]\n");

                caller_context = event:getHeader("Caller-Context");
                --freeswitch.consoleLog("notice","[events] Caller-Context : ["..tostring(caller_context).."]\n");

                if (caller_context ~= nil) then
                        local sql = "SELECT domain_uuid FROM v_domains WHERE domain_name = :domain_name";
                        params =  {domain_name = caller_context};

                        dbh:query( sql, params , function(rows)
                                domain_uuid = rows["domain_uuid"];
                        end);
                end
                --freeswitch.consoleLog("notice", "[events] Domain_UUID : "..tostring(domain_uuid).."\n");

                event_date_gmt = event:getHeader("Event-Date-GMT");
                --freeswitch.consoleLog("notice","[events] Event-date-GMT : ["..tostring(event_date_gmt).."]\n");

                event_date_timestamp = event:getHeader("Event-Date-Timestamp");
                --freeswitch.consoleLog("notice","[events] Event-date-timestamp : ["..tostring(event_date_timestamp).."]\n");

                channel_presence_id = event:getHeader("Channel-Presence-ID");
                --freeswitch.consoleLog("notice","[events] Channel_Presence_ID : ["..tostring(channel_presence_id).."]\n");

                caller_caller_id_name = event:getHeader("Caller-Caller-ID-Name");
                --freeswitch.consoleLog("notice","[events] Caller_Caller_ID_Name : ["..tostring(caller_caller_id_name).."]\n");

                caller_caller_id_number = event:getHeader("Caller-Caller-ID-Name");
                --freeswitch.consoleLog("notice", "[events] Caller_Caller_ID_Name : ["..tostring(caller_caller_id_number).."]\n");

                caller_destination_number = event:getHeader("Caller-Destination-Number");
                --freeswitch.consoleLog("notice","[events] Caller_Destination_Number : ["..tostring(caller_destination_number).."]\n");
		
		if (caller_destination_number ~= nil) then
                        local sql = "SELECT ivr_menu_uuid,ivr_menu_name FROM v_ivr_menus WHERE ivr_menu_extension = :ivr_menu_extension AND domain_uuid = :domain_uuid";
                        params = {ivr_menu_extension = caller_destination_number, domain_uuid =  domain_uuid};

                        dbh:query( sql, params, function(rows)
				ivr_menu_uuid = rows["ivr_menu_uuid"];
                                ivr_menu_name = rows["ivr_menu_name"];
                        end);
                end
                --freeswitch.consoleLog("notice", "[events] IVR_Menu_UUID : "..tostring(ivr_menu_uuid).."\n");
                --freeswitch.consoleLog("notice", "[events] IVR_Menu_Name : "..tostring(ivr_menu_name).."\n");

		caller_context = event:getHeader("Caller-Context");
                --freeswitch.consoleLog("notice","[events] Caller-Context : ["..tostring(caller_context).."]\n");

                dtmf_digit = event:getHeader("DTMF-Digit");
                --freeswitch.consoleLog("notice","[events] DTMF_Digit : ["..tostring(dtmf_digit).."]\n");

                dtmf_duration = event:getHeader("DTMF-Duration");
                --freeswitch.consoleLog("notice","[events] DTMF_Duration : ["..tostring(dtmf_duration).."]\n");

                dtmf_source = event:getHeader("DTMF-Source");
               -- freeswitch.consoleLog("notice","[events] DTMF_Source : ["..tostring(dtmf_source).."]\n");

		if (unique_id ~= nil and domain_uuid ~= nil and ivr_menu_name ~= nil ) then
                local sql = "INSERT INTO v_ivr_reports(unique_id, domain_uuid, ivr_menu_uuid, event_date_gmt, event_date_timestamp, channel_presence_id, caller_caller_id_name, caller_caller_id_number, caller_destination_number, ivr_menu_name, caller_context, dtmf_digit, dtmf_duration, dtmf_source) VALUES(:unique_id, :domain_uuid, :ivr_menu_uuid, :event_date_gmt, :event_date_timestamp, :channel_presence_id, :caller_caller_id_name, :caller_caller_id_number, :caller_destination_number, :ivr_menu_name, :caller_context, :dtmf_digit, :dtmf_duration, :dtmf_source)";
                local params = {unique_id = unique_id, domain_uuid = domain_uuid, ivr_menu_uuid = ivr_menu_uuid, event_date_gmt = event_date_gmt, event_date_timestamp = event_date_timestamp, channel_presence_id = channel_presence_id, caller_caller_id_name = caller_caller_id_name, caller_caller_id_number = caller_caller_id_number, caller_destination_number = caller_destination_number, ivr_menu_name = ivr_menu_name, caller_context = caller_context, dtmf_digit = dtmf_digit, dtmf_duration = dtmf_duration, dtmf_source = dtmf_source};

                if (debug["sql"]) then
                        freeswitch.consoleLog("notice", "[cidlookup] SQL: "..sql.."; params:" .. json.encode(params) .. "\n");
                end

                dbh:query( sql, params);
		end
		serialized = event:serialize('json');
		--freeswitch.consoleLog("notice", "[events] Event : ["..serialized.."]\n" );
	end


