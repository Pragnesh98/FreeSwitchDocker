--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--get the action
	action = params:getHeader("action");
	purpose = params:getHeader("purpose");
		--sip_auth - registration
		--group_call - call group has been called
		--user_call - user has been called

--get logger
	local log = require "resources.functions.log".xml_handler;

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
	if (domain_uuid == nil) then
		if (domain_name ~= nil) then
			local sql = "SELECT domain_uuid FROM v_domains ";
			sql = sql .. "WHERE domain_name = :domain_name ";
			local params = {domain_name = domain_name}
			if (debug["sql"]) then
				log.noticef("SQL: %s; params %s", sql, json.encode(params));
			end
			dbh:query(sql, params, function(rows)
				domain_uuid = rows["domain_uuid"];
			end);
		end
	end

--get the extension information
	if (domain_uuid ~= nil) then
		local sql = "SELECT * FROM v_extensions WHERE domain_uuid = :domain_uuid "
			.. "and (extension = :user or number_alias = :user) "
			.. "and enabled = 'true' ";
		local params = {domain_uuid=domain_uuid, user=user};
		if (debug["sql"]) then
			log.noticef("SQL: %s; params ", sql);
		end
		dbh:query(sql, params, function(row)
			--general
				domain_uuid = row.domain_uuid;
				extension_uuid = row.extension_uuid;
				extension = row.extension;
				cidr = "";
				if (string.len(row.cidr) > 0) then
					cidr = [[ cidr="]] .. row.cidr .. [["]];
				end
				number_alias = "";
				if (string.len(row.number_alias) > 0) then
					number_alias = [[ number-alias="]] .. row.number_alias .. [["]];
				end
			--params
				password = row.password;
		end);
	end

--build the xml
	if (domain_name ~= nil and extension ~= nil and password ~= nil) then
		local xml = {}
		--table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
		table.insert(xml, [[<document type="freeswitch/xml">]]);
		table.insert(xml, [[	<section name="directory">]]);
		table.insert(xml, [[		<domain name="]] .. domain_name .. [[" alias="true">]]);
		table.insert(xml, [[			<user id="]] .. extension .. [["]] .. number_alias .. [[>]]);
		table.insert(xml, [[				<params>]]);
		table.insert(xml, [[					<param name="reverse-auth-user" value="]] .. extension .. [["/>]]);
		table.insert(xml, [[					<param name="reverse-auth-pass" value="]] .. password .. [["/>]]);
		table.insert(xml, [[				</params>]]);
		table.insert(xml, [[			</user>]]);
		table.insert(xml, [[		</domain>]]);
		table.insert(xml, [[	</section>]]);
		table.insert(xml, [[</document>]]);
		XML_STRING = table.concat(xml, "\n");
	end

--close the database connection
	dbh:release();

--send the xml to the console
	if (debug["xml_string"]) then
		freeswitch.consoleLog("notice", "[xml_handler] XML_STRING: \n" .. XML_STRING .. "\n");
	end
