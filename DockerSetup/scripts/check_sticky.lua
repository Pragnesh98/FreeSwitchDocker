
	require "resources.functions.config";
	debug["sql"] = false;
	local json
        if (debug["sql"]) then
                json = require "resources.functions.lunajson"
        end
        api = freeswitch.API();

        local Database = require "resources.functions.database";
        domain_name = session:getVariable("sip_h_X-context");
        destination_type = session:getVariable("sip_h_X-DESTAPP");
        caller_id_number = session:getVariable("caller_id_number");
        queue_extension = session:getVariable("destination_number");
	sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");

	freeswitch.consoleLog("notice","Domain_name : "..tostring(domain_name).."\n");
	dbh = Database.new('system');
	assert(dbh:connected());
	if domain_name ~= nil then
		local sql = "SELECT domain_uuid FROM v_domains"
			.. " WHERE domain_name = :domain_name";

		local params = {domain_name = domain_name};
                if (debug["sql"]) then
                        freeswitch.consoleLog("notice", "[CHECK_STICKY] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                end
                dbh:query(sql, params, function(rows)
                        domain_uuid = rows["domain_uuid"];
                        session:setVariable("domain_uuid", tostring(domain_uuid));
                end);
        end

        if caller_id_number ~= nil then
                local sql= "SELECT destination_number FROM v_xml_cdr "
                        .. "WHERE caller_id_number = :caller_id_number AND domain_uuid = :domain_uuid" 
			.. " ORDER BY start_stamp DESC LIMIT 1";
                        
                local params = {caller_id_number = caller_id_number, domain_uuid = domain_uuid};
                if (debug["sql"]) then
                        freeswitch.consoleLog("notice", "[CHECK_STICKY] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                end
                dbh:query(sql, params, function(rows)
                        destination_number = rows["destination_number"];
                end);
        end
		session:consoleLog("info", "destination_number: ".. tostring(destination_number) .."\n")

        if destination_number ~= nil then
		local sql  = "SELECT call_center_agent_uuid FROM v_call_center_agents "
			.. "WHERE agent_id = :agent_id AND domain_uuid = :domain_uuid";
		local params = {agent_id = destination_number, domain_uuid = domain_uuid};
                if (debug["sql"]) then
                        freeswitch.consoleLog("notice", "[CHECK_STICKY] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                end
                dbh:query(sql, params, function(rows)
                        call_center_agent_uuid = rows["call_center_agent_uuid"];
                end);
	end

--sticky_profile = 'true';
	if sticky_profile == 'true' then
		digits = session:playAndGetDigits(1, 2, 2, 3000, "#", "/usr/local/freeswitch/sounds/select_agent.mp3", "/usr/local/freeswitch/sounds/wrong_pressed.mp3", "\\d+")
		session:consoleLog("info", "Got DTMF digits: ".. digits .."\n")

		if digits == 1 then
			freeswitch.consoleLog("notice","Check  agent is available or not\n");

        		local sql = "SELECT name,last_bridge_end,wrap_up_time FROM agents A, tiers B where (A.name='"..tostring(call_center_agent_uuid).."') AND (A.status='Available' OR A.status='Available (On Demand)') AND (B.state='Ready' OR B.state='No Answer') AND A.state='Waiting'";
			dbh:query(sql, params, function(rows)
				agent_uuid = rows["name"];
				last_bridge_end = rows["last_bridge_end"];
				wrap_up_time = rows["wrap_up_time"];
			end);

			if (last_bridge_end ~= nil) then
				number = os.time();
				check_number = tonumber(number) - tonumber(last_bridge_end);
				if (check_number >= tonumber(wrap_up_time)) then
						agent_available = 'true';
				else
						agent_available = 'false';
				end
				session:consoleLog("info", "Agent_uuid : ".. tostring(agent_uuid) .."\n")
			end

			if (agent_uuid ~= nil and agent_available == 'true')  then
				api_cmd = "user_data "..tostring(destination_number).."@"..tostring(domain_name).." var hold_music"
				hold_music = api:executeString(api_cmd)
				freeswitch.consoleLog("notice", "API CMD : " .. tostring(api_cmd) .. "\n");
				if(hold_music) then
					freeswitch.consoleLog("notice", "Caller Destination MOH  : " .. tostring(hold_music) .. "\n");
					session:setVariable("dst_hold_music", tostring(hold_music));
				end
				sofia_str = "{ignore_early_media=true}[api_on_answer='luarun callrecord.lua ${uuid}',hold_music='"..tostring(hold_music).."',media_webrtc=true]sofia/internal/"..tostring(destination_number).."@"..tostring(domain_name)..";fs_path=sip:"..tostring(sipproxy).."";
				session:execute("bridge", '"'..tostring(sofia_str)..'"');
			else
				--session:set_tts_params("flite", "kal");
				--session:speak("sorry your agent is now busy do you want  to wait otherwise you will drop here");
				freeswitch.consoleLog("notice","agent is not available");
				digits = session:playAndGetDigits(1, 2, 2, 3000, "#", "/usr/local/freeswitch/sounds/agent_busy.mp3", "/usr/local/freeswitch/sounds/wrong_pressed.mp3", "\\d+")
				session:hangup();
				if digits == 1 then
					session:sleep(3000);
					goto start;
				else
              				  local sql= "SELECT cc_queue FROM v_xml_cdr "
              				          .. "WHERE caller_id_number = :caller_id_number AND domain_uuid = :domain_uuid" 
						  .. " ORDER BY start_stamp DESC LIMIT 1";
                        
         				  local params = {caller_id_number = caller_id_number, domain_uuid = domain_uuid};
			                  if (debug["sql"]) then
             				           freeswitch.consoleLog("notice", "[CHECK_STICKY] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
       				          end
       				          dbh:query(sql, params, function(rows)
						  queue = rows["cc_queue"];
					  end);

					  if queue ~= nil then
					--	sofia_str = "{media_webrtc=true,sip_h_X-context="..tostring(domain_name)..",domain_uuid="..tostring(domain_uuid)..",origination_caller_id_name='"..tostring(caller_id_name).."',origination_caller_id_number="..tostring(caller_id_number).."}user/"..tostring(queue).."/callcenter/XML";

					--	freeswitch.consoleLog("NOTICE", " DialString : "..tostring(sofia_str))
					--	session:execute("bridge",'"'..tostring(sofia_str)..'"')
						session:execute("transfer", tostring(queue).." XML callcenter");
					  end
				  end
			  end
		  end
	end


