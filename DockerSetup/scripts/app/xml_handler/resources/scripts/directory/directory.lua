--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--set the default
	continue = true;

--get the action
	action = params:getHeader("action");
	purpose = params:getHeader("purpose");

	debug["sql"] = false;
--include json library
	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end

--include cache library
	local cache = require "resources.functions.cache"
	debug['cache'] = false;
	debug["xml_string"] = false;
-- event source
	local event_calling_function = params:getHeader("Event-Calling-Function")
	local event_calling_file = params:getHeader("Event-Calling-File")

--determine the correction action to perform
	if (purpose == "gateways") then
		dofile(scripts_dir.."/app/xml_handler/resources/scripts/directory/action/domains.lua");
	elseif (action == "message-count") then
		dofile(scripts_dir.."/app/xml_handler/resources/scripts/directory/action/message-count.lua");
	elseif (action == "group_call") then
		dofile(scripts_dir.."/app/xml_handler/resources/scripts/directory/action/group_call.lua");
	elseif (action == "reverse-auth-lookup") then
		dofile(scripts_dir.."/app/xml_handler/resources/scripts/directory/action/reverse-auth-lookup.lua");
	elseif (event_calling_function == "switch_xml_locate_domain") then
		dofile(scripts_dir.."/app/xml_handler/resources/scripts/directory/action/domains.lua");
	elseif (event_calling_function == "switch_load_network_lists") then
		dofile(scripts_dir.."/app/xml_handler/resources/scripts/directory/action/acl.lua");
	elseif (event_calling_function == "populate_database") and (event_calling_file == "mod_directory.c") then
		dofile(scripts_dir.."/app/xml_handler/resources/scripts/directory/action/directory.lua");
	else

		local USE_FS_PATH = xml_handler and xml_handler["fs_path"]
		local DIAL_STRING_BASED_ON_USERID = xml_handler and xml_handler["reg_as_number_alias"]
		local NUMBER_AS_PRESENCE_ID = xml_handler and xml_handler["number_as_presence_id"]

		local sip_auth_method = params:getHeader("sip_auth_method")
		if sip_auth_method then
			sip_auth_method = sip_auth_method:upper();
		end

		local from_user = params:getHeader("sip_from_user")
		if USE_FS_PATH and sip_auth_method == 'INVITE' then
			from_user = user
		end

		dialed_extension = params:getHeader("dialed_extension");
		if (dialed_extension == nil) then
			USE_FS_PATH = false;
		else
			-- freeswitch.consoleLog("notice", "[xml_handler][directory] dialed_extension is " .. dialed_extension .. "\n");
		end

		-- verify from_user and number alias for this methods
		local METHODS = {
			-- _ANY_    = true,
			REGISTER = true,
			-- INVITE   = true,
		}

		if (user == nil) then
			user = "";
		end

		if (from_user == "") or (from_user == nil) then
			from_user = user
		end

	--prevent processing for invalid user
		if (user == "*97") or (user == "") then
			source = "";
			continue = false;
		end

	-- cleanup
		XML_STRING = nil;

		if (continue) and (not USE_FS_PATH) then
			if (cache.support() and domain_name) then
				local key, err = "directory:" .. (from_user or user) .. "@" .. domain_name
				XML_STRING, err = cache.get(key);

				if debug['cache'] then
					if not XML_STRING then
						freeswitch.consoleLog("notice", "[xml_handler][directory][cache] get key: " .. key .. " fail: " .. tostring(err) .. "\n")
					else
						freeswitch.consoleLog("notice", "[xml_handler][directory][cache] get key: " .. key .. " pass!" .. "\n")
					end
				end
			end
			source = XML_STRING and "cache" or "database";
		end

		local loaded_from_db = false
		if (source == "database") or (USE_FS_PATH) then
			loaded_from_db = true
			local Database = require "resources.functions.database";
			if (continue) then
				dbh = Database.new('system');
				assert(dbh:connected());
				if (domain_uuid == nil) then
					if (domain_name ~= nil) then
						local sql = "SELECT domain_uuid FROM v_domains "
							.. "WHERE domain_name = :domain_name ";
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

			if (domain_uuid == nil) then
				continue = false;
			end

			if (continue) then
				if (USE_FS_PATH) then
					if (domain_name == nil) then
						local sql = "SELECT domain_name FROM v_domains "
							.. "WHERE domain_uuid = :domain_uuid ";
						local params = {domain_uuid = domain_uuid};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params, function(row)
							domain_name = row["domain_name"];
						end);
					end
				end
			end

		--get the extension from the database
			if (continue) then
				local sql = "SELECT * FROM v_extensions WHERE domain_uuid = :domain_uuid "
					.. "and (extension = :user or number_alias = :user) "
					.. "and enabled = 'true' ";
				local params = {domain_uuid=domain_uuid, user=user};
				if (debug["sql"]) then
					freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
				end
				continue = false;
				dbh:query(sql, params, function(row)
				--general
					continue = true;
					domain_uuid = row.domain_uuid;
					extension_uuid = row.extension_uuid;
					extension = row.extension;
					password = row.password;
					sip_from_user = row.extension;
					sip_from_number =  row.extension;
					call_screen_enabled = row.call_screen_enabled;
					user_record = row.user_record;
					hold_music = row.hold_music;
					toll_allow = row.toll_allow;
					user_context = row.user_context;
					effective_caller_id_name = row.effective_caller_id_name;
					effective_caller_id_number = row.effective_caller_id_number;
					outbound_caller_id_name = row.outbound_caller_id_name;
					outbound_caller_id_number = row.outbound_caller_id_number;
					call_timeout = row.call_timeout;

					if sip_auth_method then
						local check_from_number = METHODS[sip_auth_method] or METHODS._ANY_
						if DIAL_STRING_BASED_ON_USERID then
							continue = (sip_from_user == user) and ((not check_from_number) or (from_user == sip_from_number))
						else
							continue = (sip_from_user == user) and ((not check_from_number) or (from_user == user))
						end
						if not continue then
							XML_STRING = nil;
							return 1;
						end
					end
					presence_id = (NUMBER_AS_PRESENCE_ID and sip_from_number or sip_from_user) .. "@" .. domain_name;
				end);
			end


			--get the voicemail from the database
				if (continue) then
					vm_enabled = "true";
					vm_mailto = "";
					mwi_account = "";
					local sql = "SELECT * FROM v_voicemails WHERE domain_uuid = :domain_uuid and voicemail_id = :voicemail_id ";
					local params = {domain_uuid = domain_uuid};
					if number_alias and #number_alias > 0 then
						params.voicemail_id = number_alias;
					else
						params.voicemail_id = user;
					end
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
					end
					dbh:query(sql, params, function(row)
						if (string.len(row.voicemail_enabled) > 0) then
							vm_enabled = row.voicemail_enabled;
						end
						vm_password = row.voicemail_password;
						vm_attach_file = "true";
						if (string.len(row.voicemail_attach_file) > 0) then
							vm_attach_file = row.voicemail_attach_file;
						end
						vm_keep_local_after_email = "true";
						if (string.len(row.voicemail_local_after_email) > 0) then
							vm_keep_local_after_email = row.voicemail_local_after_email;
						end
						if (string.len(row.voicemail_mail_to) > 0) then
							vm_mailto = row.voicemail_mail_to;
						else
							vm_mailto = "";
						end
					end);
				end
					
			if (extension_uuid == nil) then
				continue = false;
			end

			if (continue and password) then
			--build the xml
				local xml = {}
				table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
				table.insert(xml, [[<document type="freeswitch/xml">]]);
				table.insert(xml, [[	<section name="directory">]]);
				table.insert(xml, [[		<domain name="]] .. domain_name .. [[" alias="true">]]);
				table.insert(xml, [[			<params>]]);
				table.insert(xml, [[				<param name="jsonrpc-allowed-methods" value="verto"/>]]);
				table.insert(xml, [[				<param name="jsonrpc-allowed-event-channels" value="demo,conference,presence"/>]]);
				table.insert(xml, [[			</params>]]);
				table.insert(xml, [[			<groups>]]);
				table.insert(xml, [[				<group name="default">]]);
				table.insert(xml, [[					<users>]]);
				table.insert(xml, [[						<user id="]] .. extension .. [[">]]);
				table.insert(xml, [[							<params>]]);
				table.insert(xml, [[								<param name="password" value="]] .. password .. [["/>]]);
		
				table.insert(xml, [[								<param name="vm-enabled" value="]] .. vm_enabled .. [["/>]]);
				if (string.len(vm_mailto) > 0) then
					table.insert(xml, [[								<param name="vm-password" value="]] .. vm_password  .. [["/>]]);
					table.insert(xml, [[								<param name="vm-email-all-messages" value="]] .. vm_enabled  ..[["/>]]);
					table.insert(xml, [[								<param name="vm-attach-file" value="]] .. vm_attach_file .. [["/>]]);
					table.insert(xml, [[								<param name="vm-keep-local-after-email" value="]] .. vm_keep_local_after_email .. [["/>]]);
					table.insert(xml, [[								<param name="vm-mailto" value="]] .. vm_mailto .. [["/>]]);
				end
				if (string.len(mwi_account) > 0) then
					table.insert(xml, [[							<param name="MWI-Account" value="]] .. mwi_account .. [["/>]]);
				end
							
				table.insert(xml, [[								<param name="jsonrpc-allowed-event-channels" value="demo,conference,presence"/>]]);
				table.insert(xml, [[							</params>]]);
				table.insert(xml, [[							<variables>]]);
				table.insert(xml, [[								<variable name="domain_uuid" value="]] .. domain_uuid .. [["/>]]);
				table.insert(xml, [[								<variable name="domain_name" value="]] .. domain_name .. [["/>]]);
				table.insert(xml, [[								<variable name="extension_uuid" value="]] .. extension_uuid .. [["/>]]);
				if (user_uuid ~= nil) and (string.len(user_uuid) > 0) then
					table.insert(xml, [[								<variable name="user_uuid" value="]] .. user_uuid .. [["/>]]);
				end
				if (contact_uuid ~= nil) and (string.len(contact_uuid) > 0) then
					table.insert(xml, [[								<variable name="contact_uuid" value="]] .. contact_uuid .. [["/>]]);
				end
				table.insert(xml, [[								<variable name="call_timeout" value="]] .. call_timeout .. [["/>]]);
				table.insert(xml, [[								<variable name="caller_id_name" value="]] .. sip_from_user .. [["/>]]);
				table.insert(xml, [[								<variable name="caller_id_number" value="]] .. sip_from_number .. [["/>]]);
				table.insert(xml, [[								<variable name="presence_id" value="]] .. presence_id .. [["/>]]);
				if (user_record ~= nil) and (string.len(user_record) > 0) then
					table.insert(xml, [[								<variable name="user_record" value="]] .. user_record .. [["/>]]);
				end
				if (hold_music ~= nil) and (string.len(hold_music) > 0) then
					table.insert(xml, [[								<variable name="hold_music" value="]] .. hold_music .. [["/>]]);
				end
				if (toll_allow ~= nil) and (string.len(toll_allow) > 0) then
					table.insert(xml, [[								<variable name="toll_allow" value="]] .. toll_allow .. [["/>]]);
				end
				table.insert(xml, [[								<variable name="user_context" value="]] .. user_context .. [["/>]]);
				if (effective_caller_id_name ~= nil) and (string.len(effective_caller_id_name) > 0) then
					table.insert(xml, [[								<variable name="effective_caller_id_name" value="]] .. effective_caller_id_name.. [["/>]]);
				end
				if (effective_caller_id_number ~= nil) and (string.len(effective_caller_id_number) > 0) then
					table.insert(xml, [[								<variable name="effective_caller_id_number" value="]] .. effective_caller_id_number.. [["/>]]);
				end
				if (outbound_caller_id_name ~= nil) and (string.len(outbound_caller_id_name) > 0) then
					table.insert(xml, [[								<variable name="outbound_caller_id_name" value="]] .. outbound_caller_id_name .. [["/>]]);
				end
				if (outbound_caller_id_number ~= nil) and (string.len(outbound_caller_id_number) > 0) then
					table.insert(xml, [[								<variable name="outbound_caller_id_number" value="]] .. outbound_caller_id_number .. [["/>]]);
				end
				table.insert(xml, [[								<variable name="record_stereo" value="true"/>]]);
				table.insert(xml, [[								<variable name="transfer_fallback_extension" value="operator"/>]]);
				table.insert(xml, [[								<variable name="export_vars" value="domain_name"/>]]);
				table.insert(xml, [[							</variables>]]);
				table.insert(xml, [[						</user>]]);
				table.insert(xml, [[					</users>]]);
				table.insert(xml, [[				</group>]]);
				table.insert(xml, [[			</groups>]]);
				table.insert(xml, [[		</domain>]]);
				table.insert(xml, [[	</section>]]);
				table.insert(xml, [[</document>]]);
				XML_STRING = table.concat(xml, "\n");

				dbh:release();
				if cache.support() then
					local key = "directory:" .. sip_from_number .. "@" .. domain_name
					if debug['cache'] then
						freeswitch.consoleLog("notice", "[xml_handler][directory][cache] set key: " .. key .. "\n")
					end
					--local ok, err = cache.set(key, XML_STRING, expire["directory"])
					--if debug["cache"] and not ok then
					--	freeswitch.consoleLog("warning", "[xml_handler][directory][cache] set key: " .. key .. " fail: " .. tostring(err) .. "\n");
				--	end

					if sip_from_number ~= sip_from_user then
						key = "directory:" .. sip_from_user .. "@" .. domain_name
						if debug['cache'] then
							freeswitch.consoleLog("notice", "[xml_handler][directory][cache] set key: " .. key .. "\n")
						end
						--ok, err = cache.set(key, XML_STRING, expire["directory"])
						--if debug["cache"] and not ok then
						--	freeswitch.consoleLog("warning", "[xml_handler][directory][cache] set key: " .. key .. " fail: " .. tostring(err) .. "\n");
					--	end
					end
				end
				if (debug["xml_string"]) then
					local file = assert(io.open(temp_dir .. "/" .. user .. "@" .. domain_name .. ".xml", "w"));
					file:write(XML_STRING);
					file:close();
				end
				if (debug["cache"]) then
					freeswitch.consoleLog("notice", "[xml_handler] directory:" .. user .. "@" .. domain_name .. " source: database\n");
				end
			end
		end

		if XML_STRING and (not loaded_from_db) and sip_auth_method then
			local user_id = api:execute("user_data", from_user .. "@" .. domain_name .." attr id")
			if user_id ~= user then
				XML_STRING = nil;
			elseif METHODS[sip_auth_method] or METHODS._ANY_ then
				local alias
				if DIAL_STRING_BASED_ON_USERID then
					alias = api:execute("user_data", from_user .. "@" .. domain_name .." attr number-alias")
				end
				if alias and #alias > 0 then
					if from_user ~= alias then
						XML_STRING = nil
					end
				elseif from_user ~= user_id then
					XML_STRING = nil;
				end
			end
		end

		--get the XML string from the cache
		if (source == "cache") then
		--send to the console
			if (debug["cache"]) then
				if (XML_STRING) then
					freeswitch.consoleLog("notice", "[xml_handler] directory:" .. user .. "@" .. domain_name .. " source: cache \n");
				end
			end
		end
	end --if action

--if the extension does not exist send "not found"
	if not XML_STRING then
	--send not found but do not cache it
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
