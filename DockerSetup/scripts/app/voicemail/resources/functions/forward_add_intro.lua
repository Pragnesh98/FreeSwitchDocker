--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define a function to forward a message to an extension
	function forward_add_intro(voicemail_id, uuid)

		--flush dtmf digits from the input buffer
			session:flushDigits();

		--request whether to add the intro
			--To add an introduction to this message press 1
			add_intro_id = session:playAndGetDigits(1, 1, 3, 5000, "#*", "phrase:voicemail_forward_prepend:1:2", "phrase:invalid_entry", "\\d+");
			freeswitch.consoleLog("notice", "[voicemail][forward add intro] "..add_intro_id.."\n");
			if (add_intro_id == '1') then

				--load libraries
					local Database = require "resources.functions.database";
					local Settings = require "resources.functions.lazy_settings";

				--connect to the database
					local db = dbh or Database.new('system');

				--get the settings.
					local settings = Settings.new(db, domain_name, domain_uuid);
					local max_len_seconds = settings:get('voicemail', 'max_len_seconds', 'boolean') or 300;

				--record your message at the tone press any key or stop talking to end the recording
					if (session:ready()) then
						session:sayPhrase("voicemail_record_greeting", "", "en")
					end

				--set the file full path
					message_location = voicemail_dir.."/"..voicemail_id.."/msg_"..uuid.."."..vm_message_ext;
					message_intro_location = voicemail_dir.."/"..voicemail_id.."/intro_"..uuid.."."..vm_message_ext;

				--record the message introduction
					-- syntax is session:recordFile(file_name, max_len_secs, silence_threshold, silence_secs)
					silence_seconds = 5;
					if (storage_path == "http_cache") then
						result = session:recordFile(message_intro_location, max_len_seconds, record_silence_threshold, silence_seconds);
					else
						mkdir(voicemail_dir.."/"..voicemail_id);
						if (vm_message_ext == "mp3") then
							shout_exists = trim(api:execute("module_exists", "mod_shout"));
							if (shout_exists == "true") then
								freeswitch.consoleLog("notice", "using mod_shout for mp3 encoding\n");
								--record in mp3 directly
									result = session:recordFile(message_intro_location, max_len_seconds, record_silence_threshold, silence_seconds);
							else
								--create initial wav recording
									result = session:recordFile(message_intro_location, max_len_seconds, record_silence_threshold, silence_seconds);
								--use lame to encode, if available
									if (file_exists("/usr/bin/lame")) then
										freeswitch.consoleLog("notice", "using lame for mp3 encoding\n");
										--convert the wav to an mp3 (lame required)
											resample = "/usr/bin/lame -b 32 --resample 8 -m s "..voicemail_dir.."/"..voicemail_id.."/intro_"..uuid..".wav "..message_intro_location;
											session:execute("system", resample);
										--delete the wav file, if mp3 exists
											if (file_exists(message_intro_location)) then
												os.remove(voicemail_dir.."/"..voicemail_id.."/intro_"..uuid..".wav");
											else
												vm_message_ext = "wav";
											end
									else
										freeswitch.consoleLog("notice", "neither mod_shout or lame found, defaulting to wav\n");
										vm_message_ext = "wav";
									end
							end
						else
							result = session:recordFile(message_intro_location, max_len_seconds, record_silence_threshold, silence_seconds);
						end
					end

				--save the merged file into the database as base64
					if (storage_type == "base64") then
							local file = require "resources.functions.file"

						--get the content of the file
							local file_content = assert(file.read_base64(message_intro_location));

						--save the merged file as base64
							local sql = [[UPDATE SET v_voicemail_messages
									SET message_intro_base64 = :file_content 
									WHERE domain_uuid = :domain_uuid
									AND voicemail_message_uuid = :uuid]];
							local params = {file_content = file_content, domain_uuid = domain_uuid, uuid = uuid};

							if (debug["sql"]) then
								freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params: " .. json.encode(params) .. "\n");
							end

							local dbh = Database.new('system', 'base64')
							dbh:query(sql, params)
							dbh:release()
					end
		end

	end
