--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

	--[[
	These ACL's are automatically created on startup.
		rfc1918.auto  - RFC1918 Space
		nat.auto      - RFC1918 Excluding your local lan.
		localnet.auto - ACL for your local lan.
		loopback.auto - ACL for your local lan.
	]]

--get the cache
	local cache = require "resources.functions.cache"
	local acl_cache_key = "configuration:acl.conf"
	XML_STRING, err = cache.get(acl_cache_key)

--set the cache
	if not XML_STRING then

		--log cache error
			if (debug["cache"]) then
				freeswitch.consoleLog("warning", "[xml_handler] configuration:acl.conf can not be get from the cache: " .. tostring(err) .. "\n");
			end

		--set a default value
			if (expire["acl"] == nil) then
				expire["acl"]= "3600";
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
			table.insert(xml, [[		<configuration name="acl.conf" description="Network Lists">]]);
			table.insert(xml, [[			<network-lists>]]);

		--run the query
			sql = "select * from v_access_controls ";
			sql = sql .. "order by access_control_name asc ";
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
			end
			x = 0;
			dbh:query(sql, function(row)

				--list open tag
					table.insert(xml, [[				<list name="]]..row.access_control_name..[[" default="]]..row.access_control_default..[[">]]);

				--get the nodes
					sql = "select * from v_access_control_nodes ";
					sql = sql .. "where access_control_uuid = :access_control_uuid";
					local params = {access_control_uuid = row.access_control_uuid}
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
					end
					x = 0;
					dbh:query(sql, params, function(field)
						if (string.len(field.node_domain) > 0) then
							table.insert(xml, [[					<node type="]] .. field.node_type .. [[" domain="]] .. field.node_domain .. [[" description="]] .. field.node_description .. [["/>]]);
						else
							table.insert(xml, [[					<node type="]] .. field.node_type .. [[" cidr="]] .. field.node_cidr .. [[" description="]] .. field.node_description .. [["/>]]);
						end
					end)

				--list close tag
					table.insert(xml, [[				</list>]]);

			end)

		--close the extension tag if it was left open
			table.insert(xml, [[			</network-lists>]]);
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
			local ok, err = cache.set(acl_cache_key, XML_STRING, expire["acl"]);
			if debug["cache"] then
				if ok then
					freeswitch.consoleLog("notice", "[xml_handler] " .. acl_cache_key .. " stored in the cache\n");
				else
					freeswitch.consoleLog("warning", "[xml_handler] " .. acl_cache_key .. " can not be stored in the cache: " .. tostring(err) .. "\n");
				end
			end

		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. acl_cache_key .. " source: database\n");
			end
	else
		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. acl_cache_key .. " source: cache\n");
			end
	end --if XML_STRING

--send the xml to the console
	if (debug["xml_string"]) then
		local file = assert(io.open(temp_dir .. "/acl.conf.xml", "w"));
		file:write(XML_STRING);
		file:close();
	end
