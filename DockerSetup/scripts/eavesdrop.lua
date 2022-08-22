--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--set defaults
	max_tries = "3";
	digit_timeout = "5000";

--get the params
	extension = argv[1];

--include config.lua
	require "resources.functions.config";

--add the file_exists function
	require "resources.functions.file_exists";

--connect to the database
	local Database = require "resources.functions.database"
	local dbh = Database.new('system')
	
	--local dbh = Database.new('switch')

--include json library
	local json
	if (debug["sql"]) then
		json = require "resources.functions.lunajson"
	end

--exits the script if we didn't connect properly
	assert(dbh:connected());

--answer the call
	if (session:ready()) then
		session:answer();
	end

--get session variables
	if (session:ready()) then
		pin_number = session:getVariable("pin_number");
		sounds_dir = session:getVariable("sounds_dir");
		domain_name = session:getVariable("domain_name");
		domain_uuid = session:getVariable("domain_uuid");
	end

--get the domain from sip_from_host
	if (session:ready() and domain_name == nil) then
		domain_name = session:getVariable("sip_auth_realm");
	end

--set the sounds path for the language, dialect and voice
	if (session:ready()) then
		default_language = session:getVariable("default_language");
		default_dialect = session:getVariable("default_dialect");
		default_voice = session:getVariable("default_voice");
		if (not default_language) then default_language = 'en'; end
		if (not default_dialect) then default_dialect = 'us'; end
		if (not default_voice) then default_voice = 'callie'; end
	end

--set defaults
	if (digit_min_length) then
		--do nothing
	else
		digit_min_length = "2";
	end

	if (digit_max_length) then
		--do nothing
	else
		digit_max_length = "11";
	end

--session:execute('info');
	--if the pin number is provided then require it
	if (session:ready()) then
		if (pin_number) then
			min_digits = string.len(pin_number);
			max_digits = string.len(pin_number)+1;
			--digits = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", "phrase:voicemail_enter_pass:#", "", "\\d+");
			digits = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/ivr/ivr-please_enter_pin_followed_by_pound.wav", "", "\\d+");
			if (digits == pin_number) then
				--pin is correct
				freeswitch.consoleLog("NOTICE", "[eavesdrop] pin is correct\n");
			else
				session:streamFile(sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/voicemail/vm-fail_auth.wav");
				session:hangup("NORMAL_CLEARING");
				return;
			end
		end
	end

--check the database to get the uuid to eavesdrop on
	if (session:ready()) then
		--local sql = "select uuid from channels where presence_id = :presence_id OR cid_num = :cid_num OR dest = :dest ";
		--local params = {presence_id = extension.."@"..domain_name, cid_num = extension, dest = extension};
		local sql = "select uuid from active_calls where username = :username OR customer_number = :customer_number AND domain_uuid = :domain_uuid";
		local params = {username = extension, customer_number = extension, domain_uuid = domain_uuid};
		if (debug["sql"]) then
			freeswitch.consoleLog("notice", "[eavesdrop] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
		end
		dbh:query(sql, params, function(result)
			for key, val in pairs(result) do
				freeswitch.consoleLog("NOTICE", "[eavesdrop] result "..key.." "..val.."\n");
			end
			uuid = result.uuid;
		end);
	end

--eavesdrop
	if (session:ready() and uuid) then
		session:execute("eavesdrop", uuid); --call barge
	end

--notes
	--originate a call
		--cmd = "originate user/1007@voip.example.com &eavesdrop("..uuid..")";
		--cmd = "uuid_bridge "..caller_uuid.." "..uuid;
		--api = freeswitch.API();
		--result = api:executeString(cmd);
