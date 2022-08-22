--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--check the voicemail password
	function check_password(voicemail_id, password_tries)
		if (session:ready()) then

			--flush dtmf digits from the input buffer
				session:flushDigits();

			--please enter your id followed by pound
				if (voicemail_id) then
					--do nothing
				else
					timeouts = 0;
					voicemail_id = get_voicemail_id();
					if (debug["info"]) then
						freeswitch.consoleLog("notice", "[voicemail] voicemail id: " .. voicemail_id .. "\n");
					end
				end

			--get the voicemail settings from the database
				if (voicemail_id) then
					if (session:ready()) then
						local sql = [[SELECT * FROM v_voicemails
							WHERE domain_uuid = :domain_uuid
							AND voicemail_id = :voicemail_id
							AND voicemail_enabled = 'true' ]];
						local params = {domain_uuid = domain_uuid, voicemail_id = voicemail_id};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params, function(row)
							voicemail_uuid = string.lower(row["voicemail_uuid"]);
							voicemail_password = row["voicemail_password"];
							greeting_id = row["greeting_id"];
							voicemail_mail_to = row["voicemail_mail_to"];
							voicemail_attach_file = row["voicemail_attach_file"];
							voicemail_local_after_email = row["voicemail_local_after_email"];
						end);
					end
				end

			--end the session if this is an invalid voicemail box
				if (not voicemail_uuid) or (#voicemail_uuid == 0) then
					return session:hangup();
				end

			--please enter your password followed by pound
				min_digits = 2;
				max_digits = 20;
				digit_timeout = 5000;
				max_tries = 3;
				password = session:playAndGetDigits(min_digits, max_digits, max_tries, digit_timeout, "#", "phrase:voicemail_enter_pass:#", "", "\\d+");
				--freeswitch.consoleLog("notice", "[voicemail] password: " .. password .. "\n");

			--compare the password from the database with the password provided by the user
				if (voicemail_password ~= password) then
					--incorrect password
					dtmf_digits = '';
					macro(session, "password_not_valid", 1, 1000, '');
					if (session:ready()) then
						password_tries = password_tries + 1;
						if (password_tries < max_tries) then
							check_password(voicemail_id, password_tries);
						else
							macro(session, "goodbye", 1, 1000, '');
							session:hangup();
						end
					end
				end
		end
	end
