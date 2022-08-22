--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--check the voicemail password
	function change_password(voicemail_id, menu)
		if (session:ready()) then
			--flush dtmf digits from the input buffer
				session:flushDigits();
			--set password valitity in case of hangup
				valid_password = "false";
			--please enter your password followed by pound
				dtmf_digits = '';
				password = macro(session, "password_new", 20, 5000, '');
				if (password_complexity ~= "true") then
					valid_password = "true";
				end
			--check password comlexity
				if (password_complexity == "true") then 
					--check for length
						if (string.len(password) < tonumber(password_min_length)) then
							password_error_flag = "1";
							dtmf_digits = '';
							--freeswitch.consoleLog("notice", "[voicemail] Not long enough \n");
							macro(session, "password_below_minimum", 20, 3000, password_min_length);
							timeouts = 0;
							if (menu == "tutorial") then
								change_password(voicemail_id, "tutorial");
							end
							if (menu == "advanced") then
								change_password(voicemail_id, "advanced");
							end
						end
					
					--check for repeating digits
						local repeating = {"000", "111", "222", "333", "444", "555", "666", "777", "888", "999"};
						for i = 1, 10 do
							if (string.match(password, repeating[i])) then
								password_error_flag = "1";
								dtmf_digits = '';
								--freeswitch.consoleLog("notice", "[voicemail] You can't use repeating digits like ".. repeating[i] .."  \n");
								macro(session, "password_not_secure", 20, 3000);
								timeouts = 0;
								if (menu == "tutorial") then
									change_password(voicemail_id, "tutorial");
								end
								if (menu == "advanced") then
									change_password(voicemail_id, "advanced");
								end
							end	
						end

					--check for squential digits
						local sequential = {"012", "123", "345", "456", "567", "678", "789", "987"};
						for i = 1, 8 do
							if (string.match(password, sequential[i])) then
								password_error_flag = "1";
								dtmf_digits = '';
								--freeswitch.consoleLog("notice", "[voicemail] You can't use sequential digits like ".. sequential[i] .."  \n");
								macro(session, "password_not_secure", 20, 3000);
								timeouts = 0;
								if (menu == "tutorial") then
									change_password(voicemail_id, "tutorial");
								end
								if (menu == "advanced") then
									change_password(voicemail_id, "advanced");
								end
							end	
						end
					--password is valid
						if (password_error_flag ~= "1") then 
							freeswitch.consoleLog("notice", "[voicemail] Password is valid! \n");
							valid_password = "true";
						end
				end
			--update the voicemail password
				if (valid_password == "true") then 
					local sql = [[UPDATE v_voicemails
						set voicemail_password = :password
						WHERE domain_uuid = :domain_uuid
						AND voicemail_id = :voicemail_id 
						AND voicemail_enabled = 'true' ]];
					local params = {password = password, domain_uuid = domain_uuid,
						voicemail_id = voicemail_id};
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
					end
					dbh:query(sql, params);
				end
			--has been changed to
				dtmf_digits = '';
				macro(session, "password_changed", 20, 3000, password);
			--advanced menu
				timeouts = 0;
				if (menu == "advanced") then
					advanced();
				end
				if (menu == "tutorial") then
					tutorial("record_greeting");
				end
		end
	end
