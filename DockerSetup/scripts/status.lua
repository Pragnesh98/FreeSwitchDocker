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

	session:sleep(5000);

			 amd_detect = session:getVariable("amd_result")
			freeswitch.consoleLog("notice","[New] AMD_STATUS :"..tostring(amd_detect).."\n\n\n");
			if amd_detect == "MACHINE" then 
				session:hangup();
			end
