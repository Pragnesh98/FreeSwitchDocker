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

--set variables
	digit_timeout = "5000";

--check if a file exists
	require "resources.functions.file_exists"

--run if the session is ready
	if ( session:ready() ) then
		--answer the call
			session:answer();

		--add short delay before playing the audio
			--session:sleep(1000);

		--get the variables
			uuid = session:getVariable("uuid");
			domain_name = session:getVariable("domain_name");
			context = session:getVariable("context");
			sounds_dir = session:getVariable("sounds_dir");
			destination_number = session:getVariable("destination_number");
			caller_id_number = session:getVariable("caller_id_number");
			record_ext = session:getVariable("record_ext");

		--confirm or not to confirm
			if (session:getVariable("confirm")) then
				confirm = session:getVariable("confirm");
			end

		--prepare the api
			api = freeswitch.API();

		--set the sounds path for the language, dialect and voice
			default_language = session:getVariable("default_language");
			default_dialect = session:getVariable("default_dialect");
			default_voice = session:getVariable("default_voice");
			if (not default_language) then default_language = 'en'; end
			if (not default_dialect) then default_dialect = 'us'; end
			if (not default_voice) then default_voice = 'callie'; end

		--if the screen file is found then set confirm to true
			if (domain_name ~= nil) then
				if (file_exists(temp_dir .. "/" .. domain_name .. "-" .. caller_id_number .. "." .. record_ext)) then
					call_screen_file = temp_dir .. "/" .. domain_name .. "-" .. caller_id_number .. "." .. record_ext;
					confirm = "true";
				end
			end

		--confirm the calls
			--prompt for digits
				if (confirm == "true") then
					--send to the log
						--freeswitch.consoleLog("NOTICE", "[confirm] prompt\n");
					--get the digit
						min_digits = 1;
						max_digits = 1;
						digit = '';
						if (call_screen_file ~= nil) then
							max_tries = "1";
							digit = session:playAndGetDigits(min_digits, max_digits, max_tries, "500", "#", call_screen_file:gsub("\\","/"), "", "\\d+");
						end
						if (string.len(digit) == 0) then
							max_tries = "3";
							digit = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", sounds_dir.."/"..default_language.."/"..default_dialect.."/"..default_voice.."/ivr/ivr-accept_reject_voicemail.wav", "", "\\d+");
						end
					--process the response
						if (digit == "1") then
							--freeswitch.consoleLog("NOTICE", "[confirm] accept\n");
						elseif (digit == "2") then
							--freeswitch.consoleLog("NOTICE", "[confirm] reject\n");
							session:hangup("CALL_REJECTED"); --LOSE_RACE
						elseif (digit == "3") then
							--freeswitch.consoleLog("NOTICE", "[confirm] voicemail\n");
							session:hangup("NO_ANSWER");
						else
							--freeswitch.consoleLog("NOTICE", "[confirm] no answer\n");
							session:hangup("NO_ANSWER");
						end
				else
					--send to the log
						--freeswitch.consoleLog("NOTICE", "[confirm] automatically accepted\n");
				end
	end
