--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--include config.lua

function timeGreater(a, b) 
	return a > b 
end

	require "resources.functions.config";
	json = require "resources.functions.lunajson"
	debug["sql"] = false;
	--local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end
	api = freeswitch.API();

	local Database = require "resources.functions.database";
	camp_uuid = session:getVariable("sip_h_X-CAMP-UUID");
	domain_name = session:getVariable("sip_h_X-context");
	destination_type = session:getVariable("sip_h_X-DESTAPP");
	caller_id_number = session:getVariable("caller_id_number");
	queue_extension = session:getVariable("destination_number");
	destination_number = session:getVariable("sip_h_X-DID");
	uuid = session:getVariable("uuid");
	session:setVariable("sip_h_X-xml_cdr_uuid", tostring(uuid));
	

	local sql = "SELECT camp_name, camp_activity_type, camp_off_activity_type, camp_activity_uuid, camp_off_activity_uuid, camp_type, auto_answer,time_condition FROM v_campaign_master "
			.. " WHERE camp_uuid=:camp_uuid AND domain_uuid=:domain_uuid AND camp_status='t'";
	local params = {domain_uuid = domain_uuid, camp_uuid = camp_uuid};
	
	session:setVariable("sip_h_X-CAMP-UUID", tostring(camp_uuid));
	session:execute("export", "camp_uuid="..tostring(camp_uuid));
	
	dbh = Database.new('system');
	assert(dbh:connected());
	if (domain_name ~= nil) then
		local sql = "SELECT domain_uuid FROM v_domains "
			.. "WHERE domain_name = :domain_name ";
		local params = {domain_name = domain_name};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			domain_uuid = rows["domain_uuid"];
			session:setVariable("domain_uuid", tostring(domain_uuid));
		end);
	end

	if (caller_id_number ~= nil) then
		local sql = "SELECT agent_id FROM v_call_center_agents WHERE agent_id = :agent_id AND domain_uuid = :domain_uuid";
		local params = {agent_id = caller_id_number, domain_uuid=domain_uuid};

		if(debug["sql"]) then
			freeswitch.consoleLog("notice","[CALL_BLOCK] SQL: "..sql..";params:" .. json.encode(params).. "\n");
		end
		dbh:query( sql, params, function(rows)
			agent_id = rows["agent_id"];
		end);

		if (agent_id == nil) then
			--session:setVariable("avmd::start","");
			--session:execute("avmd","start");
			--freeswitch.consoleLog("notice","AVMD Started\n");
		else
	
			--local sql = "SELECT count(*) FROM v_xml_cdr WHERE start_stamp >= Now() - INTERVAL '10 MINUTE' AND caller_id_number = :caller_id_number AND domain_uuid = :domain_uuid";	

		end


	end

	if (destination_number ~= nil) then

		local sql = "SELECT agent_id  FROM v_call_center_agents WHERE agent_id = :agent_id AND domain_uuid = :domain_uuid";
		local params = {agent_id = destination_number, domain_uuid = domain_uuid};

		if(debug["sql"]) then
			freeswitch.consoleLog("notice","[CALL_BLOCK] SQL: "..sql..";params:" .. json.encode(params).. "\n");
		end
		dbh:query( sql, params, function(rows)
			agent_id = rows["agent_id"];
		end);
	
		if(agent_id ~= nil) then
				freeswitch.consoleLog("notice","destination_number =".. tostring(destination_number).. "\n");
		else	
			did_number = destination_number;

			session:setVariable("did_number", tostring(did_number));
			session:execute("export", "did_number="..tostring(did_number));
			freeswitch.consoleLog("notice","did_number =".. tostring(did_number).. "\n");
			freeswitch.consoleLog("notice","destination_number =".. tostring(destination_number).. "\n");
		end
	end

	--caller_id_number = session:getVariable("caller_id_number");
	cmd = "user_exists id "..tostring(caller_id_number).." " ..tostring(domain_name)
	freeswitch.consoleLog("notice", "[DIDLOOKUP] caller user is local api  : " .. tostring(cmd) .. "\n");
	if(api:executeString(cmd) == "true") then
		api_cmd = "user_data "..tostring(caller_id_number).."@"..tostring(domain_name).." var hold_music"
		hold_music = api:executeString(api_cmd)
		freeswitch.consoleLog("notice", "[DIDLOOKUP] :API CMD : " .. tostring(api_cmd) .. "\n");
		if(hold_music) then
			freeswitch.consoleLog("notice", "[DIDLOOKUP] Caller UserMOH  : " .. tostring(hold_music) .. "\n");
			session:setVariable("hold_music", tostring(hold_music));
		end
	end
	
function routeQueue(call_center_queue_uuid, domain_uuid) 
	local sql = "SELECT call_center_queue_uuid, queue_name, queue_greeting, queue_cc_exit_keys,queue_cid_prefix FROM v_call_center_queues "
		.. " WHERE call_center_queue_uuid=:call_center_queue_uuid AND domain_uuid=:domain_uuid";
	local params = {domain_uuid = domain_uuid, call_center_queue_uuid = call_center_queue_uuid};
	if (debug["sql"]) then
		freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
	end
	dbh:query(sql, params, function(rows)
		call_center_queue_uuid = rows["call_center_queue_uuid"];
		queue_name = rows["queue_name"];
		queue_greeting = rows["queue_greeting"];
		queue_cc_exit_keys = rows["queue_cc_exit_keys"];
		queue_cid_prefix = rows["queue_cid_prefix"];
	end);
	
	if(call_center_queue_uuid == nil or call_center_queue_uuid == "" or call_center_queue_uuid == "nil") then
-- 		freeswitch.consoleLog("info", "[DIDLOOKUP] : DID LOOKUP\n")
	;
	else
		session:answer();
		
		if queue_cc_exit_keys then
			session:setVariable("cc_exit_keys", tostring(queue_cc_exit_keys));
		end
		
		if queue_cid_prefix then
			caller_id_name = session:getVariable("caller_id_name");
			session:setVariable("effective_caller_id_name", tostring(queue_cid_prefix).."#"..tostring(caller_id_name));
		end
		
		session:setVariable("cc_queue", tostring(call_center_queue_uuid));
		session:setVariable("domain_uuid", tostring(domain_uuid));
		session:execute("export", "cc_queue="..tostring(call_center_queue_uuid));
		session:execute("export", "domain_uuid="..tostring(domain_uuid));
	

                local sql = "SELECT customer_number FROM v_high_priority_numbers WHERE customer_number = :caller_id_number AND domain_uuid = :domain_uuid";
                local params = {caller_id_number = caller_id_number,domain_uuid = domain_uuid};
                if (debug["sql"]) then
                      freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                end
                dbh:query(sql , params, function(rows)
                        customer_number = rows["customer_number"];
                end);
                freeswitch.consoleLog("notice", "[DIDLOOKUP] Customer number : " .. tostring(customer_number) .."\n");
                if( customer_number == caller_id_number) then
                        local sql = "SELECT base_score FROM members ORDER by base_score DESC LIMIT 1";
                        params = {base_score = base_score};
                        if (debug["sql"]) then
                                freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                        end
                        dbh:query(sql, params, function(rows)
                                base_score = rows["base_score"];
                        end);
        
                        --if(base_score != NULL) then
                                base_score = base_score + 4;
        
                                session:setVariable("cc_base_score", tostring(base_score));
                                session:execute("export", "cc_base_score="..tostring(base_score));
                        --end
                end



		session:setVariable("cc_export_vars","sip_auto_answer,domain_uuid,domain_name");
		freeswitch.consoleLog("info", "[DIDLOOKUP] : DID mapped with QUEUE ["..tostring(call_center_queue_uuid).."]\n")
		session:execute("transfer", call_center_queue_uuid.." XML callcenter");
	end	
end

	if(destination_type == "" or destination_type == "nil" or destination_type == nil) then
		destination_type = "fromext";
	end
	
	if(string.lower(destination_type) == "queue") then
		freeswitch.consoleLog("notice", "[DIDLOOKUP] Destination Type: " .. destination_type .."\n");

		mapped_with = "queue";
		
		local sql = "SELECT queue_warp_up_time, call_center_queue_uuid, queue_name, queue_greeting, queue_cc_exit_keys,queue_cid_prefix FROM v_call_center_queues "
			.. " WHERE queue_extension=:queue_extension AND domain_uuid=:domain_uuid";
		local params = {domain_uuid = domain_uuid, queue_extension = queue_extension};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			call_center_queue_uuid = rows["call_center_queue_uuid"];
			queue_name = rows["queue_name"];
			queue_greeting = rows["queue_greeting"];
			queue_cc_exit_keys = rows["queue_cc_exit_keys"];
			queue_cid_prefix = rows["queue_cid_prefix"];
		end);
		
		freeswitch.consoleLog("notice", "[DIDLOOKUP] : DID mapped with QUEUE ["..tostring(call_center_queue_uuid).."]\n")
		if(call_center_queue_uuid == nil or call_center_queue_uuid == "" or call_center_queue_uuid == "nil") then
 			freeswitch.consoleLog("info", "[DIDLOOKUP] : DID LOOKUP\n");
		else
			session:answer();
			
			if queue_cc_exit_keys then
				session:setVariable("cc_exit_keys", tostring(queue_cc_exit_keys));
			end
			
			if queue_cid_prefix then
				caller_id_name = session:getVariable("caller_id_name");
				session:setVariable("effective_caller_id_name", tostring(queue_cid_prefix).."#"..tostring(caller_id_name));
			end
			
			session:setVariable("cc_queue", tostring(call_center_queue_uuid));
			session:setVariable("domain_uuid", tostring(domain_uuid));
			session:setVariable("mapped_with", tostring(mapped_with));
			session:execute("export", "mapped_with="..tostring(mapped_with));
			session:execute("export", "cc_queue="..tostring(call_center_queue_uuid));
			session:execute("export", "domain_uuid="..tostring(domain_uuid));
			

	                local sql = "SELECT customer_number FROM v_high_priority_numbers WHERE customer_number = :caller_id_number AND domain_uuid = :domain_uuid";
	                local params = {caller_id_number = caller_id_number,domain_uuid = domain_uuid};
	                if (debug["sql"]) then
	                        freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
	                end
	                dbh:query(sql , params, function(rows)
	                        customer_number = rows["customer_number"];
	                end);
	                freeswitch.consoleLog("notice", "[DIDLOOKUP] Customer number : " .. tostring(customer_number) .."\n");
	                if( customer_number == caller_id_number) then
                     --[[   local sql = "SELECT base_score FROM members ORDER by base_score DESC LIMIT 1";
                        params = {base_score = base_score};
                        if (debug["sql"]) then
                                freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                        end
                        dbh:query(sql, params, function(rows)
                                base_score = rows["base_score"];
                        end);
		        ]]--
                        --if(base_score != NULL) then
                          --      base_score = 5;
        
                            --    session:setVariable("cc_base_score", tostring(base_score));
                              --  session:execute("export", "cc_base_score="..tostring(base_score));
                        --end
	                end



-- 			session:setVariable("sip_auto_answer", "true");
			session:setVariable("cc_export_vars","sip_auto_answer,domain_uuid,domain_name");
			freeswitch.consoleLog("notice", "[DIDLOOKUP] : DID mapped with QUEUE ["..tostring(call_center_queue_uuid).."]\n")
		
			session:execute("transfer", call_center_queue_uuid.." XML callcenter");
		end
	elseif (string.lower(destination_type) == "ivr")  then
		
		mapped_with = "ivr";
		
		ivr_menu_extension = session:getVariable("destination_number");

		local sql = "SELECT ivr_menu_uuid FROM v_ivr_menus "
			.. " WHERE ivr_menu_extension=:ivr_menu_extension AND domain_uuid=:domain_uuid";
		local params = {domain_uuid = domain_uuid, ivr_menu_extension = ivr_menu_extension};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		
		dbh:query(sql, params, function(rows)
			ivr_menu_uuid = rows["ivr_menu_uuid"];
		end);
		
		if(ivr_menu_uuid == nil or ivr_menu_uuid == "" or ivr_menu_uuid == "nil") then
-- 			freeswitch.consoleLog("info", "[DIDLOOKUP] : DID LOOKUP\n")
			;
		else
			session:setVariable("ivr_name", tostring(ivr_menu_uuid));
			session:setVariable("domain_uuid", tostring(domain_uuid));
			session:setVariable("mapped_with", tostring(mapped_with));
			session:execute("export", "mapped_with="..tostring(mapped_with));
			session:execute("export", "ivr_name="..tostring(ivr_menu_uuid));
			session:execute("export", "domain_uuid="..tostring(domain_uuid));
			
			freeswitch.consoleLog("info", "[DIDLOOKUP] : DID mapped with IVR ["..tostring(ivr_menu_uuid).."]\n")
			session:execute("transfer", ivr_menu_uuid.." XML IVR");
		end
		
	elseif (string.lower(destination_type) == "voicemail")  then
		
		mapped_with = "voicemail";
		
		voicemail_ext = session:getVariable("destination_number");
		
		freeswitch.consoleLog("info", "[DIDLOOKUP] : DID mapped with VM EXT ["..tostring(voicemail_ext).."]\n")
		
		session:setVariable("voicemail_id", tostring(voicemail_ext));
		session:setVariable("domain_uuid", tostring(domain_uuid));
		session:setVariable("mapped_with", tostring(mapped_with));
		session:execute("export", "mapped_with="..tostring(mapped_with));
		session:execute("export", "voicemail_id="..tostring(voicemail_ext));
		session:execute("export", "domain_uuid="..tostring(domain_uuid));
		
		session:execute("transfer", voicemail_ext.." XML VOICEMAIL");
	elseif (string.lower(destination_type) == "campaign")  then
		
		mapped_with = "campaign";
		
		camp_uuid = session:getVariable("sip_h_X-CAMPAIGN");
		freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN UUID : "..tostring(camp_uuid).."\n")
		
		freeswitch.consoleLog("info", "[DIDLOOKUP] : Lookup Campaign Detail For Inbound Call.\n")
		
		local sql = "SELECT camp_name, camp_activity_type, camp_off_activity_type, camp_activity_uuid, camp_off_activity_uuid, camp_type, auto_answer,time_condition FROM v_campaign_master "
			.. " WHERE camp_uuid=:camp_uuid AND domain_uuid=:domain_uuid AND camp_status='t'";
		local params = {domain_uuid = domain_uuid, camp_uuid = camp_uuid};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			camp_name = rows["camp_name"];
			camp_type = rows["camp_type"];
			auto_answer = rows["auto_answer"];
			time_condition = rows["time_condition"];
			camp_activity_type = rows["camp_activity_type"];
			camp_off_activity_type = rows["camp_off_activity_type"];
			camp_activity_uuid = rows["camp_activity_uuid"];
			camp_off_activity_uuid = rows["camp_off_activity_uuid"];
			
			freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN UUID : "..tostring(camp_uuid).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN NAME : "..tostring(camp_name).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] : TIME CONDITION : "..tostring(time_condition).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN ON ACTIVITY TYPE : "..tostring(camp_activity_type).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN OFF ACTIVITY TYPE : "..tostring(camp_off_activity_type).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN ON ACTIVITY UUID : "..tostring(camp_activity_uuid).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN OFF ACTIVITY UUID : "..tostring(camp_off_activity_uuid).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] : CAMPAIGN AUTO ANSWER : "..tostring(auto_answer).."\n")
			
			session:setVariable("sip_auto_answer", tostring(auto_answer));
			session:setVariable("cc_export_vars","sip_auto_answer,domain_uuid,domain_name");
			session:setVariable("time_condition", tostring(time_condition));
			session:execute("export","time_condition="..tostring(time_condition));
			session:setVariable("sip_h_X-CAMP-UUID", tostring(camp_uuid));
			session:setVariable("camp_name", tostring(camp_name));
			session:setVariable("domain_uuid", tostring(domain_uuid));
			session:setVariable("mapped_with", tostring(mapped_with));
			session:execute("export", "mapped_with="..tostring(mapped_with));
			session:execute("export", "camp_uuid="..tostring(camp_uuid));
			session:execute("export", "sip_h_X-CAMP-UUID="..tostring(camp_uuid));
			session:execute("export", "camp_name="..tostring(camp_name));
			session:execute("export", "domain_uuid="..tostring(domain_uuid));

			session:setVariable("camp_type", tostring(camp_type));
			session:execute("export", "camp_type="..tostring(camp_type));
			
			session:setVariable("camp_activity_type", tostring(camp_activity_type));
			session:setVariable("camp_off_activity_type", tostring(camp_off_activity_type));
			session:setVariable("camp_activity_uuid", tostring(camp_activity_uuid));
			session:setVariable("camp_off_activity_uuid", tostring(camp_off_activity_uuid));
			session:execute("export", "camp_activity_type="..tostring(camp_activity_type));
			session:execute("export", "camp_off_activity_type="..tostring(camp_off_activity_type));
			session:execute("export", "camp_activity_uuid="..tostring(camp_activity_uuid));
			session:execute("export", "camp_off_activity_uuid="..tostring(camp_off_activity_uuid));
		

			local sql = "SELECT name, status, holiday_name, work_day, repeat FROM time_conditions "
				.. " WHERE time_condition_uuid=:time_condition_uuid AND domain_uuid=:domain_uuid";
			local params = {domain_uuid = domain_uuid, time_condition_uuid = time_condition};
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
			end
			dbh:query(sql, params, function(rows)
				name = rows["name"];
				status = rows["status"];
				holiday_name = rows["holiday_name"];
				work_day = rows["work_day"];
				Repeat = rows["repeat"];
			end);
			freeswitch.consoleLog("info", "[DIDLOOKUP] :TIME CONDITION NAME : "..tostring(name).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] :TIME CONDITION STATUS : "..tostring(status).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] :TIME CONDITION HOLIDAY : "..tostring(holiday_name).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] :TIME CONDITION WORKING DAYS : "..tostring(work_day).."\n")
			freeswitch.consoleLog("info", "[DIDLOOKUP] :TIME CONDITION REPEAT : "..tostring(Repeat).."\n")
			
			local tab = json.decode(work_day)
			json_string = json.encode(tab)
			--freeswitch.consoleLog("info", "[DIDLOOKUP] :TIME CONDITION JSON : "..tostring(json_string).."\n")
			if status == "t" then
				for i,j in pairs(tab) do
					local daysoftheweek={"Sunday","Monday","Tuesday","Wednesday","Thrusday","Friday","Saturday"}
					local day=daysoftheweek[os.date("*t").wday]
					--freeswitch.consoleLog("info", "[DIDLOOKUP] Current Day: "..day .."\n")
					if day == j.work_day then
						freeswitch.consoleLog("info", "[DIDLOOKUP] :TIME CONDITION : "..i..":".. j.work_day .."\n")
						if j.status == "true" then 
							CTime = os.date("%H:%M")
							StartTime = j.start_time
							EndTime = j.end_time
							StartTimeTrue = timeGreater(CTime, StartTime);
							freeswitch.consoleLog("notice","[DIDLOOKUP] : CTIME : "..tostring(CTime));
							EndTimeTrue = timeGreater(EndTime, CTime);
							daymatch = true;
						end
					end
				end

				freeswitch.consoleLog("notice","[DIDLOOKUP] : System StartTime : "..tostring(StartTime));
				freeswitch.consoleLog("notice","[DIDLOOKUP] : StartTimeTrue Match : "..tostring(StartTimeTrue));
				freeswitch.consoleLog("notice","[DIDLOOKUP] : EndTimeTrue Match : "..tostring(EndTimeTrue));
				freeswitch.consoleLog("notice","[DIDLOOKUP] : System Day : "..tostring(Day));
				freeswitch.consoleLog("notice","[DIDLOOKUP] : DayofWeek : "..tostring(DayofWeek));
	
				if StartTimeTrue == true and EndTimeTrue == true and daymatch == true then										freeswitch.consoleLog("notice","[DIDLOOKUP] : Lookup for ON ACTIVITY");
					freeswitch.consoleLog("notice","[DIDLOOKUP] : Scheduled Time Matched.");
				
					session:setVariable("inbound_camp_sched_match", "true");
					session:execute("export", "inbound_camp_sched_match=true");
					
					if(camp_activity_type == "QUEUE") then
						routeQueue(camp_activity_uuid, domain_uuid);
					elseif (camp_activity_type == "IVR") then
						session:setVariable("ivr_name", tostring(camp_activity_uuid));
						session:setVariable("domain_uuid", tostring(domain_uuid));
						session:execute("export", "ivr_name="..tostring(camp_activity_uuid));
						session:execute("export", "domain_uuid="..tostring(domain_uuid));
			
						session:execute("transfer", camp_activity_uuid.." XML IVR");
					elseif (camp_activity_type == "PLAYBACK") then
						local sql = "SELECT file_location FROM v_prompts "
							.. " WHERE pmt_uuid=:camp_activity_uuid AND domain_uuid=:domain_uuid";
						local params = {camp_activity_uuid = camp_activity_uuid, domain_uuid = domain_uuid};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						
						dbh:query(sql, params, function(rows)
							file_location = rows["file_location"];
							
							session:setVariable("playback_name", tostring(camp_activity_uuid));
							session:setVariable("domain_uuid", tostring(domain_uuid));
							session:execute("export", "playback_name="..tostring(camp_activity_uuid));
							session:execute("export", "domain_uuid="..tostring(domain_uuid));
							
							session:answer();
							session:execute("sleep", "500");
							session:execute("playback", file_location);
							session:execute("sleep", "500");
						end);
						session:hangup();
					
					elseif (camp_activity_type == "VOICEMAIL") then
						local sql = "SELECT voicemail_uuid, voicemail_id, voicemail_id FROM v_voicemails "
							.. " WHERE voicemail_uuid=:camp_off_activity_uuid AND domain_uuid=:domain_uuid";
						local params = {camp_off_activity_uuid = camp_off_activity_uuid, domain_uuid = domain_uuid};
						if (debug["sql"]) then
								freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params, function(rows)
							voicemail_id = rows["voicemail_id"];
							session:setVariable("voicemail_id", tostring(voicemail_id));
							session:setVariable("domain_uuid", tostring(domain_uuid));
							session:execute("export", "voicemail_id="..tostring(voicemail_id));
							session:execute("export", "domain_uuid="..tostring(domain_uuid));
						
							session:execute("transfer", voicemail_id.." XML VOICEMAIL");
						end);
-- 						session:hangup();
					end
				else
					freeswitch.consoleLog("notice","[DIDLOOKUP] : Scheduled Time Not Matched.");
					freeswitch.consoleLog("notice","[DIDLOOKUP] : Lookup for OFF ACTIVITY");
					session:setVariable("inbound_camp_sched_match", "false");
					session:execute("export", "inbound_camp_sched_match=false");
				
					to_number = session:getVariable("sip_h_X-DID");
			
					api_cmd = "curl --insecure --location --request POST 'https://heptadial.com:10707/addCallback' --header 'Content-Type: application/json' --data-raw '{\"domain_uuid\":\""..tostring(domain_uuid).."\",\"camp_uuid\":\""..tostring(camp_uuid).."\",\"from\":\""..tostring(caller_id_number).."\",\"to\":\""..tostring(to_number).."\"}'"
					freeswitch.consoleLog("notice","[DIDLOOKUP] : api_cmd : "..tostring(api_cmd));
				
					api_response = api:execute("system",api_cmd)
				
					freeswitch.consoleLog("notice","[DIDLOOKUP] : api_response : "..tostring(api_response));
					
					if(camp_off_activity_type == "QUEUE") then
						routeQueue(camp_off_activity_uuid, domain_uuid);
					elseif (camp_off_activity_type == "IVR") then
						session:setVariable("ivr_name", tostring(camp_off_activity_uuid));
						session:setVariable("domain_uuid", tostring(domain_uuid));
						session:execute("export", "ivr_name="..tostring(camp_off_activity_uuid));
						session:execute("export", "domain_uuid="..tostring(domain_uuid));
					
						session:execute("transfer", camp_off_activity_uuid.." XML IVR");
				
					elseif (camp_off_activity_type == "PLAYBACK") then
						local sql = "SELECT file_location FROM v_prompts "
							.. " WHERE pmt_uuid=:camp_off_activity_uuid AND domain_uuid=:domain_uuid";
						local params = {camp_off_activity_uuid = camp_off_activity_uuid, domain_uuid = domain_uuid};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
					
						dbh:query(sql, params, function(rows)
							file_location = rows["file_location"];
							session:setVariable("playback_name", tostring(camp_off_activity_uuid));
							session:setVariable("domain_uuid", tostring(domain_uuid));
							session:execute("export", "playback_name="..tostring(camp_off_activity_uuid));
							session:execute("export", "domain_uuid="..tostring(domain_uuid));
					
							session:answer();
							session:execute("sleep", "500");
							session:execute("playback", file_location);
							session:execute("sleep", "500");
						end);
							session:hangup();
					
					elseif (camp_off_activity_type == "VOICEMAIL") then
						local sql = "SELECT voicemail_uuid, voicemail_id, voicemail_id FROM v_voicemails "
							.. " WHERE voicemail_uuid=:camp_off_activity_uuid AND domain_uuid=:domain_uuid";
						local params = {camp_off_activity_uuid = camp_off_activity_uuid, domain_uuid = domain_uuid};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params, function(rows)
							voicemail_id = rows["voicemail_id"];
							session:setVariable("voicemail_id", tostring(voicemail_id));
							session:setVariable("domain_uuid", tostring(domain_uuid));
							session:execute("export", "voicemail_id="..tostring(camp_off_activity_uuid));
							session:execute("export", "domain_uuid="..tostring(domain_uuid));
								
							session:execute("transfer", voicemail_id.." XML VOICEMAIL");
						end);
-- 						session:hangup();
					end
				end
			end
		end);

	elseif (string.lower(destination_type) == "extension")  then
		
		mapped_with = "extension";
		
		destination_number = session:getVariable("destination_number");
		call_center_queue_uuid = session:getVariable("sip_h_X-QUEUE-UUID");
		cc_agent = session:getVariable("sip_h_X-AGENT-USER-NAME");
	
		session:setVariable("cc_queue", tostring(call_center_queue_uuid));
		session:setVariable("domain_uuid", tostring(domain_uuid));
		session:setVariable("cc_agent", tostring(cc_agent));
		session:setVariable("mapped_with", tostring(mapped_with));
		
		session:execute("export", "mapped_with="..tostring(mapped_with));
		session:execute("export", "cc_queue="..tostring(call_center_queue_uuid));
		session:execute("export", "domain_uuid="..tostring(domain_uuid));
		session:execute("export", "cc_agent="..tostring(cc_agent));
		
		session:execute("transfer", destination_number.." XML "..domain_name);
	       --session:execute("transfer","callback XML CALLBACK");


	else 
 		freeswitch.consoleLog("info", "[DIDLOOKUP] : DID LOOKUP\n")
		
		local sql = "SELECT call_center_queue_uuid, queue_name, queue_greeting, queue_cc_exit_keys,queue_cid_prefix FROM v_call_center_queues "
			.. " WHERE queue_extension=:queue_extension AND domain_uuid=:domain_uuid";
		local params = {domain_uuid = domain_uuid, queue_extension = queue_extension};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			call_center_queue_uuid = rows["call_center_queue_uuid"];
			queue_name = rows["queue_name"];
			queue_greeting = rows["queue_greeting"];
			queue_cc_exit_keys = rows["queue_cc_exit_keys"];
			queue_cid_prefix = rows["queue_cid_prefix"];
		end);
		
		if(call_center_queue_uuid == nil or call_center_queue_uuid == "" or call_center_queue_uuid == "nil") then
-- 			freeswitch.consoleLog("info", "[DIDLOOKUP] : DID LOOKUP\n")
		;
		else
			session:answer();
			if queue_cc_exit_keys then
				session:setVariable("cc_exit_keys", tostring(queue_cc_exit_keys));
			end
			
			if queue_cid_prefix then
				caller_id_name = session:getVariable("caller_id_name");
				session:setVariable("effective_caller_id_name", tostring(queue_cid_prefix).."#"..tostring(caller_id_name));
			end
			
			session:setVariable("cc_queue", tostring(call_center_queue_uuid));
			session:setVariable("domain_uuid", tostring(domain_uuid));
			session:execute("export", "cc_queue="..tostring(call_center_queue_uuid));
			session:execute("export", "domain_uuid="..tostring(domain_uuid));
			
-- 			session:setVariable("sip_auto_answer", "true");
			session:setVariable("cc_export_vars","sip_auto_answer,domain_uuid,domain_name");
		
			freeswitch.consoleLog("info", "[DIDLOOKUP] : DID mapped with QUEUE ["..tostring(call_center_queue_uuid).."]\n")
			session:execute("transfer", call_center_queue_uuid.." XML callcenter");
		end
		
		ivr_menu_extension = session:getVariable("destination_number");

		local sql = "SELECT ivr_menu_uuid FROM v_ivr_menus "
			.. " WHERE ivr_menu_extension=:ivr_menu_extension AND domain_uuid=:domain_uuid";
		local params = {domain_uuid = domain_uuid, ivr_menu_extension = ivr_menu_extension};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		
		dbh:query(sql, params, function(rows)
			ivr_menu_uuid = rows["ivr_menu_uuid"];
		end);
		
		if(ivr_menu_uuid == nil or ivr_menu_uuid == "" or ivr_menu_uuid == "nil") then
-- 			freeswitch.consoleLog("info", "[DIDLOOKUP] : DID LOOKUP\n")
			;
		else
			session:setVariable("ivr_name", tostring(ivr_menu_uuid));
			session:setVariable("domain_uuid", tostring(domain_uuid));
			session:execute("export", "ivr_name="..tostring(ivr_menu_uuid));
			session:execute("export", "domain_uuid="..tostring(domain_uuid));
			
			freeswitch.consoleLog("info", "[DIDLOOKUP] : DID mapped with IVR ["..tostring(ivr_menu_uuid).."]\n")
			session:execute("transfer", ivr_menu_uuid.." XML IVR");
		end
		
		call_center_queue_uuid = session:getVariable("sip_h_X-QUEUE-UUID");
		cc_agent = session:getVariable("sip_h_X-AGENT-USER-NAME");
	
		session:setVariable("cc_queue", tostring(call_center_queue_uuid));
		session:setVariable("domain_uuid", tostring(domain_uuid));
		session:setVariable("cc_agent", tostring(cc_agent));
		
		session:execute("export", "cc_queue="..tostring(call_center_queue_uuid));
		session:execute("export", "domain_uuid="..tostring(domain_uuid));
		session:execute("export", "cc_agent="..tostring(cc_agent));
		
	end
	
