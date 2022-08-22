--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--get the cache
	if (trim(api:execute("module_exists", "mod_memcache")) == "true") then
		XML_STRING = trim(api:execute("memcache", "get directory:groups:"..domain_name));
	else
		XML_STRING = "-ERR NOT FOUND";
	end

--set the cache
	if (XML_STRING == "-ERR NOT FOUND") then
		--connect to the database
			local Database = require "resources.functions.database";
			local dbh = Database.new('system');

		--include json library
			local json
			if (debug["sql"]) then
				json = require "resources.functions.lunajson"
			end

		--exits the script if we didn't connect properly
			assert(dbh:connected());

		--get the domain_uuid
			if (domain_uuid == nil) then
				--get the domain_uuid
					if (domain_name ~= nil) then
						local sql = "SELECT domain_uuid FROM v_domains ";
						sql = sql .. "WHERE domain_name = :domain_name ";
						local params = {domain_name = domain_name};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params: " .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params, function(rows)
							domain_uuid = rows["domain_uuid"];
						end);
					end
			end

			if not domain_uuid then
				freeswitch.consoleLog("warning", "[xml_handler] Can not find domain name: " .. tostring(domain_name) .. "\n");
				return
			end

		--build the call group array
			local sql = [[
			select * from v_extensions
			where domain_uuid = :domain_uuid
			order by call_group asc
			]];
			local params = {domain_uuid = domain_uuid};
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params: " .. json.encode(params) .. "\n");
			end
			call_group_array = {};
			dbh:query(sql, params, function(row)
				call_group = row['call_group'];
				--call_group = str_replace(";", ",", call_group);
				tmp_array = explode(",", call_group);
				for key,value in pairs(tmp_array) do
					value = trim(value);
					--freeswitch.consoleLog("notice", "[directory] Key: " .. key .. " Value: " .. value .. " " ..row['extension'] .."\n");
					if (string.len(value) == 0) then
						--do nothing
					else
						if (call_group_array[value] == nil) then
							call_group_array[value] = row['extension'];
						else
							call_group_array[value] = call_group_array[value]..','..row['extension'];
						end
					end
				end
			end);
			--for key,value in pairs(call_group_array) do
			--	freeswitch.consoleLog("notice", "[directory] Key: " .. key .. " Value: " .. value .. "\n");
			--end

		--build the xml array
			local xml = {}
			table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
			table.insert(xml, [[<document type="freeswitch/xml">]]);
			table.insert(xml, [[	<section name="directory">]]);
			table.insert(xml, [[		<domain name="]] .. domain_name .. [[">]]);
			table.insert(xml, [[		<groups>]]);
			previous_call_group = "";
			for key, value in pairs(call_group_array) do
				call_group = trim(key);
				extension_list = trim(value);
				if (string.len(call_group) > 0) then
					freeswitch.consoleLog("notice", "[directory] call_group: " .. call_group .. "\n");
					freeswitch.consoleLog("notice", "[directory] extension_list: " .. extension_list .. "\n");
					if (previous_call_group ~= call_group) then
						table.insert(xml, [[			<group name="]]..call_group..[[">]]);
						table.insert(xml, [[				<users>]]);
						extension_array = explode(",", extension_list);
						for index,tmp_extension in pairs(extension_array) do
								table.insert(xml, [[					<user id="]]..tmp_extension..[[" type="pointer"/>]]);
						end
						table.insert(xml, [[				</users>]]);
						table.insert(xml, [[			</group>]]);
					end
					previous_call_group = call_group;
				end
			end
			table.insert(xml, [[		</groups>]]);
			table.insert(xml, [[		</domain>]]);
			table.insert(xml, [[	</section>]]);
			table.insert(xml, [[</document>]]);
			XML_STRING = table.concat(xml, "\n");

		--close the database connection
			dbh:release();

		--set the cache
			result = trim(api:execute("memcache", "set directory:groups:"..domain_name.." '"..XML_STRING:gsub("'", "&#39;").."' "..expire["directory"]));

		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] directory:groups:"..domain_name.." source: database\n");
			end

	else
		--replace the &#39 back to a single quote
			XML_STRING = XML_STRING:gsub("&#39;", "'");

		--send to the console
			if (debug["cache"]) then
				if (XML_STRING) then
					freeswitch.consoleLog("notice", "[xml_handler] directory:groups:"..domain_name.." source: memcache\n");
				end
			end
	end

--send the xml to the console
	if (debug["xml_string"]) then
		freeswitch.consoleLog("notice", "[xml_handler] directory:groups:"..domain_name.." XML_STRING: \n" .. XML_STRING .. "\n");
	end
