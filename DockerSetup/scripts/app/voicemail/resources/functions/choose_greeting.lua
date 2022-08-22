--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

	local Database = require "resources.functions.database"

--define a function to choose the greeting
	function choose_greeting()

		--flush dtmf digits from the input buffer
			session:flushDigits();

		--select the greeting
			if (session:ready()) then
				dtmf_digits = '';
				greeting_id = macro(session, "choose_greeting_choose", 1, 5000, '');
			end

		--check to see if the greeting file exists
			if (storage_type == "base64" or storage_type == "http_cache") then
				greeting_invalid = true;
				local sql = [[SELECT * FROM v_voicemail_greetings
					WHERE domain_uuid = :domain_uuid
					AND voicemail_id = :voicemail_id
					AND greeting_id = :greeting_id]];
				local params = {domain_uuid = domain_uuid, voicemail_id = voicemail_id,
					greeting_id = greeting_id};
				dbh:query(sql, params, function(row)
					--greeting found
					greeting_invalid = false;
				end);
				if (greeting_invalid) then
					greeting_id = "invalid";
				end
			else
				if (greeting_id ~= "0") then
					if (not file_exists(voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav")) then
						--invalid greeting_id file does not exist
						greeting_id = "invalid";
					end
				end
			end

		--validate the greeting_id
			if (greeting_id == "0"
				or greeting_id == "1"
				or greeting_id == "2"
				or greeting_id == "3"
				or greeting_id == "4"
				or greeting_id == "5"
				or greeting_id == "6"
				or greeting_id == "7"
				or greeting_id == "8"
				or greeting_id == "9") then

				--valid greeting_id update the database
					if (session:ready()) then
						local params = {domain_uuid = domain_uuid, voicemail_uuid = voicemail_uuid};
						local sql = "UPDATE v_voicemails SET "
						if (greeting_id == "0") then
							sql = sql .. "greeting_id = null ";
						else
							sql = sql .. "greeting_id = :greeting_id ";
							params.greeting_id = greeting_id;
						end
						sql = sql .. "WHERE domain_uuid = :domain_uuid ";
						sql = sql .. "AND voicemail_uuid = :voicemail_uuid ";
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params);
					end

				--get the greeting from the database
					if (storage_type == "base64") then
						local dbh = Database.new('system', 'base64/read')
						local sql = [[SELECT greeting_base64
							FROM v_voicemail_greetings
							WHERE domain_uuid = :domain_uuid
							AND voicemail_id = :voicemail_id
							AND greeting_id = :greeting_id]];
						local params = {
							domain_uuid = domain_uuid;
							voicemail_id = voicemail_id;
							greeting_id = greeting_id;
						};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params, function(row)
							--set the voicemail message path
								greeting_location = voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav"; --vm_message_ext;

							--save the greeting to the file system
								if (string.len(row["greeting_base64"]) > 32) then
									--include the file io
										local file = require "resources.functions.file"

									--write decoded string to file
										assert(file.write_base64(greeting_location, row["greeting_base64"]));
								end
						end);

						dbh:release()
					elseif (storage_type == "http_cache") then
						greeting_location = storage_path.."/"..voicemail_id.."/greeting_"..greeting_id..".wav"; --vm_message_ext;
					end

				--play the greeting
					if (session:ready()) then
						if (file_exists(voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav")) then
							session:streamFile(voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav");
						end
					end

				--greeting selected
					if (session:ready()) then
						dtmf_digits = '';
						macro(session, "greeting_selected", 1, 100, greeting_id);
					end

				--advanced menu
					if (session:ready()) then
						timeouts = 0;
						advanced();
					end
			else
				--invalid greeting_id
					if (session:ready()) then
						dtmf_digits = '';
						greeting_id = macro(session, "choose_greeting_fail", 1, 100, '');
					end

				--send back to choose the greeting
					if (session:ready()) then
						timeouts = timeouts + 1;
						if (timeouts < max_timeouts) then
							choose_greeting();
						else
							timeouts = 0;
							advanced();
						end
					end
			end

	end
