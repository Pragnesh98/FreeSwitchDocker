--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--include functions
	require "resources.functions.format_ringback"

--get the cache
	local cache = require "resources.functions.cache"
	hostname = trim(api:execute("switchname", ""));
	local cc_cache_key = "configuration:callcenter.conf:" .. hostname
	XML_STRING, err = cache.get(cc_cache_key)

-- 	freeswitch.consoleLog("warning", "[xml_handler] XML_STRING " .. tostring(XML_STRING) .. "\n");
--set the cache
	if XML_STRING then
		--log cache error
			if (debug["cache"]) then
				freeswitch.consoleLog("warning", "[xml_handler] " .. cc_cache_key .. " can not be get from the cache: " .. tostring(err) .. "\n");
			end

		--connect to the database
			local Database = require "resources.functions.database";
			dbh = Database.new('system');

		--exits the script if we didn't connect properly
			assert(dbh:connected());

		--get the variables
			dsn = freeswitch.getGlobalVariable("dsn") or ''
			dsn_callcenter = freeswitch.getGlobalVariable("dsn_system") or ''

		--start the xml array
			local xml = {}
			table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
			table.insert(xml, [[<document type="freeswitch/xml">]]);
			table.insert(xml, [[    <section name="configuration">]]);
			table.insert(xml, [[            <configuration name="callcenter.conf" description="Call Center">]]);
			table.insert(xml, [[                    <settings>]]);
			if #dsn_callcenter > 0 then
				table.insert(xml, [[                            <param name="odbc-dsn" value="]]..dsn_callcenter..[["/>]]);
			elseif #dsn > 0 then
				table.insert(xml, [[                            <param name="odbc-dsn" value="]]..database["switch"]..[["/>]]);
			end
			-- table.insert(xml, [[                          <param name="dbname" value="]]..database_dir..[[/call_center.db"/>]]);
			table.insert(xml, [[                    </settings>]]);

-- 		--write the queues

		--close the extension tag if it was left open
			table.insert(xml, [[            </configuration>]]);
			table.insert(xml, [[    </section>]]);
			table.insert(xml, [[</document>]]);
			XML_STRING = table.concat(xml, "\n");
			if (debug["xml_string"]) then
					freeswitch.consoleLog("notice", "[xml_handler] XML_STRING: " .. XML_STRING .. "\n");
			end

		--close the database connection
			dbh:release();
			--freeswitch.consoleLog("notice", "[xml_handler]"..api:execute("eval ${dsn}"));

		--set the cache
			local ok, err = cache.set(cc_cache_key, XML_STRING, expire["callcenter"]);
			if debug["cache"] then
				if ok then
					freeswitch.consoleLog("notice", "[xml_handler] " .. cc_cache_key .. " stored in the cache\n");
				else
					freeswitch.consoleLog("warning", "[xml_handler] " .. cc_cache_key .. " can not be stored in the cache: " .. tostring(err) .. "\n");
				end
			end

		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. cc_cache_key .. " source: database\n");
			end
	else
		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. cc_cache_key .. " source: cache\n");
			end
	end --if XML_STRING

--send the xml to the console
	if (debug["xml_string"]) then
		local file = assert(io.open(temp_dir .. "/callcenter.conf.xml", "w"));
		file:write(XML_STRING);
		file:close();
	end
