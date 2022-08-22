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

	freeswitch.consoleLog("NOTICE", "GROUP_CALL_TRANSFER..!")
	
	extension = argv[1];
	domain_uuid = session:getVariable("domain_uuid");
	--sipproxy = freeswitch.getGlobalVariable("SIPPROXYIP");	 

	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end
	
	local Database = require "resources.functions.database";
	dbh = Database.new('system');
	assert(dbh:connected());
--[[
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
]]--
	if (extension ~= nil) then
		local sql = "SELECT ring_group_uuid FROM v_ring_groups WHERE ring_group_extension = :ring_group_extension AND domain_uuid = :domain_uuid";
		local params = {ring_group_extension = extension, domain_uuid = domain_uuid};
		if(debug["sql"]) then
			freeswitch.consoleLog("notice", "[DIALER]: ".. sql .. "; params:" .. json.encode(params) .. "\n");
		end
	
		dbh:query(sql, params, function(rows)
			ring_group_uuid = rows["ring_group_uuid"];
		end);

		session:setVariable("ring_group_uuid", tostring(ring_group_uuid));
		session:setVariable("ring_ready()", "");
	end

	
