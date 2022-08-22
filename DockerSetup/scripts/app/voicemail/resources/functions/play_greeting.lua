--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

	local Database = require"resources.functions.database"

--play the greeting
	function play_greeting()
		timeout = 100;
		tries = 1;
		max_timeout = 200;

		--voicemail prompt
		if (skip_greeting == "true") then
			--skip the greeting
		else
			if (session:ready()) then
				--set the greeting based on the voicemail_greeting_number variable
					if (voicemail_greeting_number ~= nil) then
						if (string.len(voicemail_greeting_number) > 0) then
							greeting_id = voicemail_greeting_number;
						end
					end

				--play the greeting
					dtmf_digits = '';
					if (string.len(greeting_id) > 0) then

						--sleep
							session:execute("playback","silence_stream://200");

						--get the greeting from the database
							if (storage_type == "base64") then
								local dbh = Database.new('system', 'base64/read')

								local sql = [[SELECT * FROM v_voicemail_greetings
									WHERE domain_uuid = :domain_uuid
									AND voicemail_id = :voicemail_id
									AND greeting_id = :greeting_id ]];
								local params = {domain_uuid = domain_uuid, voicemail_id = voicemail_id,
									greeting_id = greeting_id};
								if (debug["sql"]) then
									freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
								end
								local saved
								dbh:query(sql, params, function(row)
									--set the voicemail message path
										mkdir(voicemail_dir.."/"..voicemail_id);
										greeting_location = voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav"; --vm_message_ext;

									--if not found, save greeting to local file system
										--saved = file_exists(greeting_location)
										--if not saved then
											if (string.len(row["greeting_base64"]) > 32) then
												--include the file io
													local file = require "resources.functions.file"

												--write decoded string to file
													saved = file.write_base64(greeting_location, row["greeting_base64"]);
											end
										--end
								end);
								dbh:release();

								if saved then
									--play the greeting
										dtmf_digits = session:playAndGetDigits(min_digits, max_digits, tries, timeout, "#", voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav", "", ".*", max_timeout);								
										--session:execute("playback",voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav");

									--delete the greeting (retain local for better responsiveness)
										--os.remove(voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav");
								end
							elseif (storage_type == "http_cache") then
								dtmf_digits = session:playAndGetDigits(min_digits, max_digits, tries, timeout, "#", voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav", "", ".*", max_timeout);								
								--session:execute("playback",storage_path.."/"..voicemail_id.."/greeting_"..greeting_id..".wav");
							else
								dtmf_digits = session:playAndGetDigits(min_digits, max_digits, tries, timeout, "#", voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav", "",".*", max_timeout);								
								--session:execute("playback",voicemail_dir.."/"..voicemail_id.."/greeting_"..greeting_id..".wav");
							end

					else
						--default greeting
						session:execute("playback","silence_stream://200");
						dtmf_digits = macro(session, "person_not_available_record_message", 1, 200);
					end
			end
		end
	end
