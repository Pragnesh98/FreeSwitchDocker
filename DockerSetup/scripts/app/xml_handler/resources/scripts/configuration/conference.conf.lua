--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

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

--set the xml array
	local xml = {}
	table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
	table.insert(xml, [[<document type="freeswitch/xml">]]);
	table.insert(xml, [[	<section name="configuration">]]);
	table.insert(xml, [[		<configuration name="conference.conf" description="Audio Conference">]]);

--start the conference controls
	table.insert(xml, [[			<caller-controls>]]);
	sql = [[SELECT * FROM v_conference_controls
		WHERE control_enabled = 'true' ]];
	if (debug["sql"]) then
		freeswitch.consoleLog("notice", "[conference_control] SQL: " .. sql .. "\n");
	end
	dbh:query(sql, function(field)
		conference_control_uuid = field["conference_control_uuid"];
		table.insert(xml, [[				<group name="]]..field["control_name"]..[[">]]);

		--get the conference control details from the database
		sql = [[SELECT * FROM v_conference_control_details
			WHERE conference_control_uuid = :conference_control_uuid
			AND control_enabled = 'true' ]];
		local params = {conference_control_uuid = conference_control_uuid};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[conference_control] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end

		dbh:query(sql, params, function(row)
			--conference_control_uuid = row["conference_control_uuid"];
			--conference_control_detail_uuid = row["conference_control_detail_uuid"];
			table.insert(xml, [[					<control digits="]]..row["control_digits"]..[[" action="]]..row["control_action"]..[[" data="]]..row["control_data"]..[["/>]]);
		end);
		table.insert(xml, [[				</group>]]);
	end);
	table.insert(xml, [[			</caller-controls>]]);


--start the conference profiles
	table.insert(xml, [[			<profiles>]]);
	sql = [[SELECT * FROM v_conference_profiles
		WHERE profile_enabled = 'true' ]];
	if (debug["sql"]) then
		freeswitch.consoleLog("notice", "[conference_profiles] SQL: " .. sql .. "\n");
	end
	dbh:query(sql, function(field)
		conference_profile_uuid = field["conference_profile_uuid"];
		table.insert(xml, [[				<profile name="]]..field["profile_name"]..[[">]]);

		--get the conference profile parameters from the database
		sql = [[SELECT * FROM v_conference_profile_params
			WHERE conference_profile_uuid = :conference_profile_uuid
			AND profile_param_enabled = 'true' ]];
		local params = {conference_profile_uuid = conference_profile_uuid};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[conference_profiles] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end

		dbh:query(sql, params, function(row)
			--conference_profile_uuid = row["conference_profile_uuid"];
			--conference_profile_param_uuid = row["conference_profile_param_uuid"];
			--profile_param_description = row["profile_param_description"];
			table.insert(xml, [[					<param name="]]..row["profile_param_name"]..[[" value="]]..row["profile_param_value"]..[["/>]]);
		end);
		table.insert(xml, [[				</profile>]]);
	end);
	table.insert(xml, [[			</profiles>]]);

--set the xml array and then concatenate the array to a string
	table.insert(xml, [[		</configuration>]]);
	table.insert(xml, [[	</section>]]);
	table.insert(xml, [[</document>]]);
	XML_STRING = table.concat(xml, "\n");
	if (debug["xml_string"]) then
		freeswitch.consoleLog("notice", "[xml_handler] XML_STRING: " .. XML_STRING .. "\n");
	end

--send the xml to the console
	if (debug["xml_string"]) then
		local file = assert(io.open(temp_dir .."/conference.conf.xml", "w"));
		file:write(XML_STRING);
		file:close();
	end
