--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--general functions
	require "resources.functions.is_uuid";

--set the default
	continue = true;

--additional information
	--event_calling_function = params:getHeader("Event-Calling-Function");

--show the params in the console
	--if (params:serialize() ~= nil) then
	--	freeswitch.consoleLog("notice", "[xml_handler-languages.lua] Params:\n" .. params:serialize() .. "\n");
	--end

--get the action
	--action = params:getHeader("action");
	language = params:getHeader("lang");
	macro_name = params:getHeader("macro_name");

--get the cache
	local cache = require "resources.functions.cache"
	local language_cache_key = "languages:" .. language..":" .. macro_name;
	XML_STRING, err = cache.get(language_cache_key)

--build the XML string from the database
	if not XML_STRING then

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

		--get the domain_uuid
			if (continue) then
				if (domain_uuid == nil) then
					--get the domain_uuid
						if (domain_name ~= nil) then
							local sql = "SELECT domain_uuid FROM v_domains ";
							sql = sql .. "WHERE domain_name = :domain_name ";
							local params = {domain_name = domain_name};
							if (debug["sql"]) then
								freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
							end
							dbh:query(sql, params, function(rows)
								domain_uuid = rows["domain_uuid"];
							end);
						end
				end
			end

		--prevent processing for invalid domains
			if (domain_uuid == nil) then
				continue = false;
			end

		--set the xml array and then concatenate the array to a string
			if (continue) then

				-- if macro_name is a uuid get from the phrase details
					if (is_uuid(macro_name)) then
						--define the xml table
							local xml = {}

						--get the xml
							table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
							table.insert(xml, [[<document type="freeswitch/xml">]]);
							table.insert(xml, [[	<section name="languages">]]);
							table.insert(xml, [[		<language name="]]..language..[[" say-module="]]..language..[[" sound-prefix="]]..sounds_dir..[[/]]..language..[[/us/callie" tts-engine="cepstral" tts-voice="callie">]]);
							table.insert(xml, [[			<phrases>]]);
							table.insert(xml, [[				<macros>]]);

							local sql = "SELECT * FROM v_phrases as p, v_phrase_details as d ";
							sql = sql .. "WHERE d.domain_uuid = :domain_uuid ";
							sql = sql .. "AND p.phrase_uuid = :macro_name ";
							sql = sql .. "AND p.phrase_language = :language ";
							sql = sql .. "AND p.phrase_uuid = d.phrase_uuid ";
							sql = sql .. "AND p.phrase_enabled = 'true' ";
							sql = sql .. "ORDER BY d.domain_uuid, p.phrase_uuid, d.phrase_detail_order ASC ";
							local params = {domain_uuid = domain_uuid, macro_name = macro_name, language = language};
							if (debug["sql"]) then
								freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
							end
							previous_phrase_uuid = "";
							match_tag = "open";
							x = 0;
							dbh:query(sql, params, function(row)
								--phrase_uuid,domain_uuid,phrase_name,phrase_language
								--phrase_description,phrase_enabled,phrase_detail_uuid
								--phrase_detail_group,phrase_detail_tag,phrase_detail_pattern
								--phrase_detail_function,phrase_detail_data,phrase_detail_method
								--phrase_detail_type,phrase_detail_order
								if (previous_phrase_uuid ~= row.phrase_uuid) then
									if (x > 0) then
										table.insert(xml, [[							</match>]]);
										table.insert(xml, [[						</input>]]);
										table.insert(xml, [[					</macro>]]);
									end
									table.insert(xml, [[					<macro name="]]..row.phrase_uuid..[[">]]);
									table.insert(xml, [[						<input pattern=\"(.*)\">]]);
									table.insert(xml, [[							<match>]]);
									match_open_tag = true
								end
								table.insert(xml, [[								<action function="]]..row.phrase_detail_function..[[" data="]]..row.phrase_detail_data..[["/>]]);
								previous_phrase_uuid = row.phrase_uuid;
								x = x + 1;
							end);
							if (x > 0) then
								table.insert(xml, [[							</match>]]);
								table.insert(xml, [[						</input>]]);
								table.insert(xml, [[					</macro>]]);
							end
							table.insert(xml, [[				</macros>]]);

						--output xml & close previous file
							table.insert(xml, [[			</phrases>]]);
							table.insert(xml, [[		</language>]]);
							table.insert(xml, [[	</section>]]);
							table.insert(xml, [[</document>]]);
							XML_STRING = table.concat(xml, "\n");
					end

				--log to the console
					--freeswitch.consoleLog("notice", "[xml_handler] language " .. XML_STRING .. " \n");

				--close the database connection
					dbh:release();
			end

		--set the cache
			if (XML_STRING) then
				local ok, err = cache.set(language_cache_key, XML_STRING, expire["acl"]);
				if debug["cache"] then
					if ok then
						freeswitch.consoleLog("notice", "[xml_handler] " .. language_cache_key .. " stored in the cache\n");
					else
						freeswitch.consoleLog("warning", "[xml_handler] " .. language_cache_key .. " can not be stored in the cache: " .. tostring(err) .. "\n");
					end
				end
			end

		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. language_cache_key .. " source: database\n");
			end
	else
		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. language_cache_key .. " source: cache\n");
			end
	end --if XML_STRING

--send the xml to the console
	if (debug["xml_string"] and XML_STRING ~= nil) then
		local file = assert(io.open(temp_dir .. "/languages.conf.xml", "w"));
		file:write(XML_STRING);
		file:close();
	end

--if the macro does not exist send "not found", don't cache the not found
	if (XML_STRING == nil or trim(XML_STRING) == "-ERR NOT FOUND") then
		XML_STRING = [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
		<document type="freeswitch/xml">
			<section name="result">
				<result status="not found" />
			</section>
		</document>]];
	end

--send the xml to the console
	if (debug["xml_string"]) then
		freeswitch.consoleLog("notice", "[xml_handler] XML_STRING: \n" .. XML_STRING .. "\n");
	end
