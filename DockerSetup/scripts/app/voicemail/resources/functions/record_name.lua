--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define a function to record the name
	function record_name(menu)
		if (session:ready()) then

			--flush dtmf digits from the input buffer
				session:flushDigits();

			--play the name record
				dtmf_digits = '';
				macro(session, "record_name", 1, 100, '');

			--prepate to record
				-- syntax is session:recordFile(file_name, max_len_secs, silence_threshold, silence_secs)
				max_len_seconds = 30;
				silence_threshold = 30;
				silence_seconds = 5;
				mkdir(voicemail_dir.."/"..voicemail_id);

			--record and save the file
				if (storage_type == "base64") then
					--set the location
						voicemail_name_location = voicemail_dir.."/"..voicemail_id.."/recorded_name.wav";

					--record the file to the file system
						-- syntax is session:recordFile(file_name, max_len_secs, silence_threshold, silence_secs);
						result = session:recordFile(voicemail_name_location, max_len_seconds, silence_threshold, silence_seconds);
						--session:execute("record", voicemail_dir.."/"..uuid.." 180 200");

					--show the storage type
						freeswitch.consoleLog("notice", "[recordings] ".. storage_type .. "\n");

					--base64 encode the file
						--include the file io
							local file = require "resources.functions.file"

						--read file content as base64 string
							voicemail_name_base64 = assert(file.read_base64(voicemail_name_location));

					--update the voicemail name
						local sql = "UPDATE v_voicemails ";
						sql = sql .. "set voicemail_name_base64 = :voicemail_name_base64 ";
						sql = sql .. "where domain_uuid = :domain_uuid ";
						sql = sql .. "and voicemail_id = :voicemail_id";
						local params = {voicemail_name_base64 = voicemail_name_base64,
							domain_uuid = domain_uuid, voicemail_id = voicemail_id};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[recording] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						if (storage_type == "base64") then
							local dbh = Database.new('system', 'base64');
							dbh:query(sql, params);
							dbh:release();
						else
							dbh:query(sql, params);
						end
				elseif (storage_type == "http_cache") then
					freeswitch.consoleLog("notice", "[voicemail] ".. storage_type .. " ".. storage_path .."\n");
					session:execute("record", storage_path .."/"..recording_name);
				else
					-- syntax is session:recordFile(file_name, max_len_secs, silence_threshold, silence_secs);
					result = session:recordFile(voicemail_dir.."/"..voicemail_id.."/recorded_name.wav", max_len_seconds, silence_threshold, silence_seconds);
				end

			--play the name
				--session:streamFile(voicemail_dir.."/"..voicemail_id.."/recorded_name.wav");

			--option to play, save, and re-record the name
				if (session:ready()) then
					timeouts = 0;
					record_menu("name", voicemail_dir.."/"..voicemail_id.."/recorded_name.wav",nil, menu);
					if (storage_type == "base64") then
						--delete the greeting
						os.remove(voicemail_dir.."/"..voicemail_id.."/recorded_name.wav");
					end
				end
		end
	end
