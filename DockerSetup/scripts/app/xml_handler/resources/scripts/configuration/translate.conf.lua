--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--get the cache
	local cache = require "resources.functions.cache"
	local translate_cache_key = "configuration:translate.conf"
	XML_STRING, err = cache.get(translate_cache_key)

--set the cache
	if not XML_STRING then
		--log cache error
			if (debug["cache"]) then
				freeswitch.consoleLog("warning", "[xml_handler] " .. translate_cache_key .. " can not be get from the cache: " .. tostring(err) .. "\n");
			end

		--log cache error
			if (debug["cache"]) then
				freeswitch.consoleLog("warning", "[xml_handler] configuration:translate.conf can not be get from the cache: " .. tostring(err) .. "\n");
			end

		--set a default value
			if (expire["translate"] == nil) then
				expire["translate"]= "3600";
			end

		--connect to the database
			local Database = require "resources.functions.database";
			dbh = Database.new('system');

		--include json library
			local json
			if (debug["sql"]) then
				json = require "resources.functions.lunajson"
			end

		--exits the script if we didn't connect properly
			assert(dbh:connected());

		--start the xml array
			local xml = {}
			table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
			table.insert(xml, [[<document type="freeswitch/xml">]]);
			table.insert(xml, [[	<section name="configuration">]]);
			table.insert(xml, [[		<configuration name="translate.conf" description="Number Translation Rules" autogenerated="true">]]);
			table.insert(xml, [[			<profiles>]]);

		--run the query
			sql = "select * from v_number_translations ";
			sql = sql .. "order by number_translation_name asc ";
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
			end
			x = 0;
			dbh:query(sql, function(row)

				--list open tag
					table.insert(xml, [[				<profile name="]]..row.number_translation_name..[[" description="]]..row.number_translation_description..[[">]]);

				--get the nodes
					sql = "select * from v_number_translation_details ";
					sql = sql .. "where number_translation_uuid = :number_translation_uuid ";
					sql = sql .. "order by number_translation_detail_order asc ";
					local params = {number_translation_uuid = row.number_translation_uuid}
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
					end
					x = 0;
					dbh:query(sql, params, function(field)
						if (string.len(field.number_translation_detail_regex) > 0) then
							table.insert(xml, [[					<rule regex="]] .. field.number_translation_detail_regex .. [[" replace="]] .. field.number_translation_detail_replace .. [[" />]]);
						end
					end)

				--list close tag
					table.insert(xml, [[				</profile>]]);

			end)

		--close the extension tag if it was left open
			table.insert(xml, [[			</profiles>]]);
			table.insert(xml, [[		</configuration>]]);
			table.insert(xml, [[	</section>]]);
			table.insert(xml, [[</document>]]);
			XML_STRING = table.concat(xml, "\n");
			if (debug["xml_string"]) then
				freeswitch.consoleLog("notice", "[xml_handler] XML_STRING: " .. XML_STRING .. "\n");
			end

		--close the database connection
			dbh:release();

		--set the cache
			local ok, err = cache.set(translate_cache_key, XML_STRING, expire["translate"]);
			if debug["cache"] then
				if ok then
					freeswitch.consoleLog("notice", "[xml_handler] " .. translate_cache_key .. " stored in the cache\n");
				else
					freeswitch.consoleLog("warning", "[xml_handler] " .. translate_cache_key .. " can not be stored in the cache: " .. tostring(err) .. "\n");
				end
			end

		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. translate_cache_key .. " source: database\n");
			end
	else
		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. translate_cache_key .. " source: cache\n");
			end
	end --if XML_STRING

--send the xml to the console
	if (debug["xml_string"]) then
		local file = assert(io.open(temp_dir .. "/translate.conf.xml", "w"));
		file:write(XML_STRING);
		file:close();
	end
