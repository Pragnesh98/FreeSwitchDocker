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

--exits the script if we didn't connect properly
	assert(dbh:connected());

--process when the sip profile is rescanned, sofia is reloaded, or sip redirect
	local xml = {}
	table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
	table.insert(xml, [[<document type="freeswitch/xml">]]);
	table.insert(xml, [[	<section name="directory">]]);
	local sql = "SELECT domain_name FROM v_domains ";
	dbh:query(sql, function(row)
		table.insert(xml, [[		<domain name="]]..row.domain_name..[[" />]]);
	end);
	table.insert(xml, [[	</section>]]);
	table.insert(xml, [[</document>]]);
	XML_STRING = table.concat(xml, "\n");

--close the database connection
	dbh:release();
