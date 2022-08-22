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
        json = require "resources.functions.lunajson"
        debug["sql"] = false;
        --local json
        if (debug["sql"]) then
                json = require "resources.functions.lunajson"
        end
        api = freeswitch.API();
	local Database = require "resources.functions.database";
	dbh = Database.new('system');
        assert(dbh:connected());

	domain_name = session:getVariable("sip_h_X-context");
	voice_broadcast_uuid = session:getVariable("sip_h_X-voice_broadcast_uuid");

	if (domain_name ~= nil) then
                local sql = "SELECT domain_uuid FROM v_domains "
                        .. "WHERE domain_name = :domain_name ";
                local params = {domain_name = domain_name};
                --if (debug["sql"]) then
                        freeswitch.consoleLog("notice", "[DIALER] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
                --end
                dbh:query(sql, params, function(rows)
                        domain_uuid = rows["domain_uuid"];
                end);
        end
        freeswitch.consoleLog("notice", "[DIALER] Domain UUID: " .. domain_uuid..", Voice_Broadcast_UUID : "..voice_broadcast_uuid.."\n");

	local sql = "SELECT broadcast_type,ivr,prompts FROM v_voice_broadcasts "
                 .. " WHERE voice_broadcast_uuid=:voice_broadcast_uuid AND domain_uuid=:domain_uuid";
        local params = {voice_broadcast_uuid = voice_broadcast_uuid, domain_uuid = domain_uuid};
        if (debug["sql"]) then
             freeswitch.consoleLog("notice", "[DIDLOOKUP] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
        end

        dbh:query(sql, params, function(rows)
		broadcast_type=rows["broadcast_type"];
		ivr=rows["ivr"];
		prompts=rows["prompts"];
	end);

	if tostring(broadcast_type) == "Prompts" then
		local sql = "SELECT file_location FROM v_prompts "
	                 .. " WHERE pmt_uuid=:prompts AND domain_uuid=:domain_uuid";
	        local params = {prompts = prompts, domain_uuid = domain_uuid};
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
	end
