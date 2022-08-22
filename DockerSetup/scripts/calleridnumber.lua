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

	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end
	
	local Database = require "resources.functions.database";
	domain_name = session:getVariable("sip_h_X-context");
	domain_uuid = session:getVariable("domain_uuid");
	destination_number = session:getVariable("destination_number");
	siptrunk_uuid = session:getVariable("sip_h_X-siptrunk_uuid");

	freeswitch.consoleLog("notice", "[queuecall] siptrunk_uuid : "..tostring(siptrunk_uuid).."\n");

	dbh = Database.new('system');
	assert(dbh:connected());
	
	if (domain_uuid == nil or domain_uuid == "" or domain_uuid == "nil") then
		local sql = "SELECT domain_uuid FROM v_domains where domain_name='"..tostring(domain_name).."'";
		local params = {domain_name = domain_name};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[queuecall] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(rows)
			domain_uuid = rows["domain_uuid"];
			session:setVariable("domain_uuid", tostring(domain_uuid));
		end);
	end
	
	local sql = "SELECT siptrunk_cid_number, siptrunk_name FROM v_siptrunks where siptrunk_uuid = '"..tostring(siptrunk_uuid).."' AND domain_uuid = '"..tostring(domain_uuid).."' LIMIT 1";
	local params = {destination_number = destination_number};
	if (debug["sql"]) then
		freeswitch.consoleLog("notice", "[queuecall] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
	end
	dbh:query(sql, params, function(rows)
		siptrunk_cid_number = rows["siptrunk_cid_number"];
		session:setVariable("outbound_caller_id_number", tostring(siptrunk_cid_number));
		session:setVariable("outbound_caller_id_name", tostring(siptrunk_cid_number));
	end);
	

	
	session:setVariable("cc_pstn_siptrunk_uuid", tostring(siptrunk_uuid));
	session:setVariable("siptrunk_uuid", tostring(siptrunk_uuid));
	session:execute("export", "siptrunk_uuid="..tostring(siptrunk_uuid));
