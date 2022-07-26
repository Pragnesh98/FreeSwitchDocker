--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--include config.lua
	require "resources.functions.config";

--create the api object
	api = freeswitch.API();

	require "resources.functions.channel_utils";
	local log = require "resources.functions.log".follow_me
	local cache = require "resources.functions.cache"
	local Database = require "resources.functions.database"
	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end

--check if the session is ready
	if not session:ready() then return end

--answer the call
	session:answer();

--get the variables
	local domain_uuid = session:getVariable("domain_uuid");
	local domain_name = session:getVariable("domain_name");
	local extension_uuid = session:getVariable("extension_uuid");

--set the sounds path for the language, dialect and voice
	local sounds_dir = session:getVariable("sounds_dir");
	local default_language = session:getVariable("default_language") or 'en';
	local default_dialect = session:getVariable("default_dialect") or 'us';
	local default_voice = session:getVariable("default_voice") or 'callie';

--a moment to sleep
	session:sleep(1000);

--check if the session is ready
	if not session:ready() then return end

--connect to the database
	local dbh = Database.new('system');

--determine whether to update the dial string
	local sql = "select extension, number_alias, accountcode, follow_me_uuid, follow_me_enabled ";
	sql = sql .. "from v_extensions ";
	sql = sql .. "where domain_uuid = :domain_uuid ";
	sql = sql .. "and extension_uuid = :extension_uuid ";
	local params = {domain_uuid=domain_uuid, extension_uuid=extension_uuid};
	if (debug["sql"]) then
		log.notice("SQL: %s; params: %s", sql, json.encode(params));
	end

	local row = dbh:first_row(sql, params)
	if not row then return end

	local extension = row.extension;
	local number_alias = row.number_alias or '';
	local accountcode = row.accountcode;
	local follow_me_uuid = row.follow_me_uuid;
	local follow_me_enabled = row.follow_me_enabled;

--determine whether to update the dial string
	sql = "select follow_me_enabled, cid_name_prefix, cid_number_prefix, dial_string "
	sql = sql .. "from v_follow_me ";
	sql = sql .. "where domain_uuid = :domain_uuid ";
	sql = sql .. "and follow_me_uuid = :follow_me_uuid ";
	local params = {domain_uuid=domain_uuid, follow_me_uuid=follow_me_uuid};
	if (debug["sql"]) then
		log.notice("SQL: %s; params: %s", sql, json.encode(params));
	end

	row = dbh:first_row(sql, params)
	if not row then return end

	--local follow_me_enabled = row.follow_me_enabled;
	local cid_name_prefix = row.cid_name_prefix;
	local cid_number_prefix = row.cid_number_prefix;
	local dial_string = row.dial_string;

--set follow me
	if (follow_me_enabled == "false") then
		--update the display and play a message
		channel_display(session:get_uuid(), "Activated")
		session:execute("sleep", "2000");
		--session:execute("playback", "ivr/ivr-call_forwarding_has_been_set.wav");
		session:streamFile(sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/ivr/ivr-call_forwarding_has_been_set.wav");
	end

--unset follow me
	if (follow_me_enabled == "true") then
		--update the display and play a message
		channel_display(session:get_uuid(), "Cancelled")
		session:execute("sleep", "2000");
		--session:execute("playback", "ivr/ivr-call_forwarding_has_been_cancelled.wav");
		session:streamFile(sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/ivr/ivr-call_forwarding_has_been_cancelled.wav");
	end

--enable or disable follow me
	sql = "update v_follow_me set ";
	sql = sql .. "dial_string = null, ";
	if (follow_me_enabled == "true") then
		sql = sql .. "follow_me_enabled = 'false' ";
	else
		sql = sql .. "follow_me_enabled = 'true' ";
	end
	sql = sql .. "where domain_uuid = :domain_uuid ";
	sql = sql .. "and follow_me_uuid = :follow_me_uuid ";
	local params = {domain_uuid=domain_uuid, follow_me_uuid=follow_me_uuid};
	if (debug["sql"]) then
		log.notice("SQL: %s; params: %s", sql, json.encode(params));
	end
	dbh:query(sql, params);

--update the extension
	sql = "update v_extensions set ";
	sql = sql .. "dial_string = null, ";
	sql = sql .. "do_not_disturb = 'false', ";
	if (follow_me_enabled == "true") then
		sql = sql .. "follow_me_enabled = 'false', ";
	else
		sql = sql .. "follow_me_enabled = 'true', ";
	end
	sql = sql .. "forward_all_enabled = 'false' ";
	sql = sql .. "where domain_uuid = :domain_uuid ";
	sql = sql .. "and extension_uuid = :extension_uuid ";
	local params = {domain_uuid=domain_uuid, extension_uuid=extension_uuid};
	if (debug["sql"]) then
		log.notice("SQL: %s; params: %s", sql, json.encode(params));
	end
	dbh:query(sql, params);

--clear the cache
	if (extension ~= nil) and cache.support() then
		cache.del("directory:"..extension.."@"..domain_name);
		if #number_alias > 0 then
			cache.del("directory:"..number_alias.."@"..domain_name);
		end
	end

--wait for the file to be written before proceeding
	session:sleep(1000);

--end the call
	session:hangup();
