--
--	FusionPBX
--	Version: MPL 1.1
--
--	The contents of this file are subject to the Mozilla Public License Version
--	1.1 (the "License"); you may not use this file except in compliance with
--	the License. You may obtain a copy of the License at
--	http://www.mozilla.org/MPL/
--
--	Software distributed under the License is distributed on an "AS IS" basis,
--	WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
--	for the specific language governing rights and limitations under the
--	License.
--
--	The Original Code is FusionPBX
--
--	The Initial Developer of the Original Code is
--	Mark J Crane <markjcrane@fusionpbx.com>
--	Copyright (C) 2019
--	the Initial Developer. All Rights Reserved.
--
--	Contributor(s):
--	Mark J Crane <markjcrane@fusionpbx.com>

--set the debug level
	debug["sql"] = false;

--includes
	local cache = require"resources.functions.cache";
	local log = require"resources.functions.log"["call_block"];

--connect to the database
	local Database = require "resources.functions.database";
	dbh = Database.new('system');

--include json library
	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson";
	end

--include functions
	require "resources.functions.trim";
	require "resources.functions.explode";
	require "resources.functions.file_exists";

--get the variables
	if (session:ready()) then
		session:setAutoHangup(false);
		domain_uuid = session:getVariable("domain_uuid");
		call_direction = session:getVariable("call_direction");
		caller_id_name = session:getVariable("caller_id_name");
		caller_id_number = session:getVariable("caller_id_number");
		destination_number = session:getVariable("destination_number");
		context = session:getVariable("context");
		call_block = session:getVariable("call_block");
		extension_uuid = session:getVariable("extension_uuid");
	end

	freeswitch.consoleLog("notice","caller_id_number =".. tostring(caller_id_number).. "\n");
	freeswitch.consoleLog("notice","destination_number =".. tostring(destination_number).. "\n");
--[[
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
]]--
--set default variables
	api = freeswitch.API();

--set the dialplan cache key
	local call_block_cache_key = "call_block:" .. caller_id_number;

--get the cache
	cached_value, err = cache.get(call_block_cache_key);
	if (debug['cache']) then
		if cached_value then
			log.notice(call_block_cache_key.." source: cache");
		elseif err ~= 'NOT FOUND' then
			log.notice("error cache: " .. err);
		end
	end

--disable the cache
	cached_value = nil;

--run call block one time
	if (call_block == nil and call_block ~= 'true') then

		--set the cache
		if (not cached_value) then

			--connect to the database
				--local Database = require "resources.functions.database";
				--dbh = Database.new('system');

			--include json library
				local json
				if (debug["sql"]) then
					json = require "resources.functions.lunajson";
				end

			--exits the script if we didn't connect properly
				assert(dbh:connected());

			--check to see if the call should be blocked
			if(caller_id_number ~= nil) then

				local sql =  "SELECT * FROM v_call_blocks WHERE call_block_number = '"  ..caller_id_number;
				sql = sql .. "' AND domain_uuid=:domain_uuid AND call_block_enabled = 'true' ";
				local params = {call_block_number = call_number, domain_uuid = domain_uuid };
				if(debug["sql"]) then
					freeswitch.consoleLog("notice","[CALL_BLOCK] SQL: "..sql..";params:" .. json.encode(params).. "\n");
				end

				dbh:query(sql, params, function(rows)
					call_block_uuid = rows["call_block_uuid"]
					call_block_app = rows["call_block_app"];
					call_block_data = rows["call_block_data"];
					call_block_count = rows["call_block_count"];
				end);


			--set call block default to false
				call_block = false;
				if (call_block_app ~= nil) then
					call_block = true;
					if (session:ready()) then
						session:execute('set', 'call_block=true');
					end
				end

			--call block action
				if (call_block_app ~= nil and call_block_app == 'busy') then
					if (session:ready()) then
						session:execute("respond", '486');
						session:execute('set', 'call_block_uuid='..call_block_uuid);
						session:execute('set', 'call_block_app=busy');
						freeswitch.consoleLog("notice", "[call_block] caller id number " .. caller_id_number .. " action: Busy\n");
					end
				end

			--update the call block count
				if (call_block) then
					sql = "update v_call_blocks ";
					sql = sql .. "set call_block_count = :call_block_count ";
					sql = sql .. "where call_block_uuid = :call_block_uuid ";
					local params = {call_block_uuid = call_block_uuid, call_block_count = call_block_count + 1};
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[dialplan] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
					end
					dbh:query(sql, params);
				end
			end
--[[
			if(destination_number ~= nil) then

                                local sql =  "SELECT * FROM v_dnc_master WHERE dnc_number = '"  .. destination_number;
                                      sql = sql .. "' AND domain_uuid = :domain_uuid";

                                local params = {dnc_number = destination_number };
                                if(debug["sql"]) then
                                        freeswitch.consoleLog("notice","[CALL_BLOCK] SQL: "..sql..";params:" .. json.encode(params).. "\n");
                                end

                                dbh:query(sql, params, function(rows)
                                        dnc_uuid = rows["dnc_uuid"];
                                end);


                        --set call block default to false
                                call_block = false;
                                if (session:ready()) then
                                        session:execute('set', 'call_block=true');
                                end
				if(dnc_uuid ~= nil) then
                               		if (session:ready()) then
                                        	session:execute("respond", '486');
                               	        	session:execute('set', 'dnc_uuid='..dnc_uuid);
                               	        	--session:execute('set', 'dnc_app=busy');
                                	        freeswitch.consoleLog("notice", "[call_block] DNC number " .. destination_number .. " action: Busy\n");
                                end
                        end
]]--
			--close the database connection
				dbh:release();

			--set the cache
				if (cached_value ~= nil) then
					local ok, err = cache.set(call_block_cache_key, cached_value, '3600');
				end
				if debug["cache"] then
					if ok then
						freeswitch.consoleLog("notice", "[call_block] " .. call_block_cache_key .. " stored in the cache\n");
					else
						freeswitch.consoleLog("warning", "[call_block] " .. call_block_cache_key .. " can not be stored in the cache: " .. tostring(err) .. "\n");
					end
				end

			--send to the console
				if (debug["cache"]) then
					freeswitch.consoleLog("notice", "[call_block] " .. call_block_cache_key .. " source: database\n");
				end
		else
			--send to the console
				if (debug["cache"]) then
					freeswitch.consoleLog("notice", "[call_block] " .. call_block_cache_key .. " source: cache\n");
				end
		end
	end
