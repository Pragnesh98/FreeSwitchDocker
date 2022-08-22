--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define a function to send sms
	function send_sms(id, uuid)
		debug["info"] = true;
		api = freeswitch.API();

		--get voicemail message details
			sql = [[SELECT * FROM v_voicemails
				WHERE domain_uuid = ']] .. domain_uuid ..[['
				AND voicemail_id = ']] .. id ..[[']]
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "\n");
			end
			status = dbh:query(sql, function(row)
				db_voicemail_uuid = string.lower(row["voicemail_uuid"]);
				voicemail_sms_to = row["voicemail_sms_to"];
				voicemail_file = row["voicemail_file"];
			end);

		--get the sms_body template
			if (settings['voicemail']['voicemail_sms_body'] ~= nil) then
				if (settings['voicemail']['voicemail_sms_body']['text'] ~= nil) then
					sms_body = settings['voicemail']['voicemail_sms_body']['text'];
				end
			else
				sms_body = 'You have a new voicemail from: ${caller_id_name} - ${caller_id_number} length ${message_length_formatted}';
			end


		--require the sms address to send to
			if (string.len(voicemail_sms_to) > 2) then
				--include languages file
					local Text = require "resources.functions.text"
					local text = Text.new("app.voicemail.app_languages")

				--get voicemail message details
					sql = [[SELECT * FROM v_voicemail_messages
						WHERE domain_uuid = ']] .. domain_uuid ..[['
						AND voicemail_message_uuid = ']] .. uuid ..[[']]
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "\n");
					end
					status = dbh:query(sql, function(row)
						--get the values from the database
							--uuid = row["voicemail_message_uuid"];
							created_epoch = row["created_epoch"];
							caller_id_name = row["caller_id_name"];
							caller_id_number = row["caller_id_number"];
							message_length = row["message_length"];
					end);

				--format the message length and date
					message_length_formatted = format_seconds(message_length);
					if (debug["info"]) then
						freeswitch.consoleLog("notice", "[voicemail-sms] message length: " .. message_length .. "\n");
						if (transcription ~= nil) then
							freeswitch.consoleLog("notice", "[voicemail-sms] transcription: " .. transcription .. "\n");
						end
						freeswitch.consoleLog("notice", "[voicemail-sms] domain_name: " .. domain_name .. "\n");
					end
					local message_date = os.date("%A, %d %b %Y %I:%M %p", created_epoch)

					sms_body = sms_body:gsub("${caller_id_name}", caller_id_name);
					sms_body = sms_body:gsub("${caller_id_number}", caller_id_number);
					sms_body = sms_body:gsub("${message_date}", message_date);
					sms_body = sms_body:gsub("${message_duration}", message_length_formatted);
					sms_body = sms_body:gsub("${account}", id);
					sms_body = sms_body:gsub("${domain_name}", domain_name);
					sms_body = sms_body:gsub("${sip_to_user}", id);
					sms_body = sms_body:gsub("${dialed_user}", id);
					if (transcription ~= nil) then
						sms_body = sms_body:gsub("${message_text}", transcription);
					end

					if (debug["info"]) then
						freeswitch.consoleLog("notice", "[voicemail-sms] sms_body: " .. sms_body .. "\n");
					end

--					sms_body = "hello";
					cmd = "luarun app.lua sms outbound " .. voicemail_sms_to .. "@" .. domain_name .. " " .. voicemail_to_sms_did .. " '" .. sms_body .. "'";
					api:executeString(cmd);

			end

	end
