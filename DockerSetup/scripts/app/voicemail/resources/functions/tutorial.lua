--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define function main menu
	function tutorial (menu)
		if (voicemail_uuid) then
			--intro menu
				if (menu == "intro") then 
					--clear the value
						dtmf_digits = '';
					--flush dtmf digits from the input buffer
						session:flushDigits();
					--play the tutorial press 1, to skip 2
						if (session:ready()) then
								if (string.len(dtmf_digits) == 0) then
									dtmf_digits = macro(session, "tutorial_intro", 1, 3000, '');
								end
						end
					--process the dtmf
						if (session:ready()) then
							if (dtmf_digits == "1") then
								timeouts = 0;
								tutorial("record_name");
							elseif (dtmf_digits == "2") then
								timeouts = 0;
								tutorial("finish");
							else
								if (session:ready()) then
									timeouts = timeouts + 1;
									if (timeouts < max_timeouts) then
										tutorial("intro");
									else
										timeouts = 0;
										tutorial("finish");
									end
								end
							end
						end
				end	
			--record name menu
				if (menu == "record_name") then 
					--clear the value
						dtmf_digits = '';
					--flush dtmf digits from the input buffer
						session:flushDigits();
					--play the record name press 1
						if (session:ready()) then
								if (string.len(dtmf_digits) == 0) then
									dtmf_digits = macro(session, "tutorial_to_record_name", 1, 100, '');
								end
						end
					--skip the name and go to password press 2
						if (session:ready()) then
							if (string.len(dtmf_digits) == 0) then
									dtmf_digits = macro(session, "tutorial_skip", 1, 3000, '');
								end
						end
					--process the dtmf
						if (session:ready()) then
							if (dtmf_digits == "1") then
								timeouts = 0;
								record_name("tutorial");
							elseif (dtmf_digits == "2") then
								timeouts = 0;
								tutorial("change_password");
							else
								if (session:ready()) then
									timeouts = timeouts + 1;
									if (timeouts < max_timeouts) then
										tutorial("record_name");
									else
										tutorial("change_password");
									end
								end
							end
						end
				end				
			--change password menu
				if (menu == "change_password") then 
					--clear the value
						dtmf_digits = '';
					--flush dtmf digits from the input buffer
						session:flushDigits();
					--to change your password press 1
						if (session:ready()) then
								if (string.len(dtmf_digits) == 0) then
									dtmf_digits = macro(session, "tutorial_change_password", 1, 100, '');
								end
						end
					--skip the password and go to greeting press 2
						if (session:ready()) then
							if (string.len(dtmf_digits) == 0) then
									dtmf_digits = macro(session, "tutorial_skip", 1, 3000, '');
								end
						end
					--process the dtmf
						if (session:ready()) then
							if (dtmf_digits == "1") then
								timeouts = 0;
								change_password(voicemail_id, "tutorial");
							elseif (dtmf_digits == "2") then
								timeouts = 0;
								tutorial("record_greeting");
							else
								if (session:ready()) then
									timeouts = timeouts + 1;
									if (timeouts < max_timeouts) then
										tutorial("change_password");
									else
										tutorial("record_greeting");
									end
								end
							end
						end
				end				
			--change greeting menu
				if (menu == "record_greeting") then 
					--clear the value
						dtmf_digits = '';
					--flush dtmf digits from the input buffer
						session:flushDigits();
					--to record a greeting press 1
						if (session:ready()) then
								if (string.len(dtmf_digits) == 0) then
									dtmf_digits = macro(session, "tutorial_record_greeting", 1, 100, '');
								end
						end
					--skip the record greeting press 2. finishes the tutorial and routes to main menu
						if (session:ready()) then
							if (string.len(dtmf_digits) == 0) then
									dtmf_digits = macro(session, "tutorial_skip", 1, 3000, '');
								end
						end
					--process the dtmf
						if (session:ready()) then
							if (dtmf_digits == "1") then
								timeouts = 0;
								record_greeting(nil, "tutorial");
							elseif (dtmf_digits == "2") then
								timeouts = 0;
								tutorial("finish");
							else
								if (session:ready()) then
									timeouts = timeouts + 1;
									if (timeouts < max_timeouts) then
										tutorial("record_greeting");
									else
										tutorial("finish");
									end
								end
							end
						end
				end
				if (menu == "finish") then 
					--clear the value
						dtmf_digits = '';
					--flush dtmf digits from the input buffer
						session:flushDigits();
					--update play tutorial in the datebase
						local sql = [[UPDATE v_voicemails
							set voicemail_tutorial = 'false'
							WHERE domain_uuid = :domain_uuid
							AND voicemail_id = :voicemail_id 
							AND voicemail_enabled = 'true' ]];
						local params = {domain_uuid = domain_uuid,
							voicemail_id = voicemail_id};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params);
					--go to main menu
						main_menu();
				end					
		end
	end
