--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define function main menu
	function main_menu ()
		if (voicemail_uuid) then
			--clear the value
				dtmf_digits = '';
			--flush dtmf digits from the input buffer
				if (session ~= nil) then
					session:flushDigits();
				end
			--answer the session
				if (session ~= nil) then
					session:answer();
					session:execute("sleep", "1000");
				end
			--new voicemail count
				if (session:ready()) then
					local sql = [[SELECT count(*) as new_messages FROM v_voicemail_messages
						WHERE domain_uuid = :domain_uuid
						AND voicemail_uuid = :voicemail_uuid
						AND (message_status is null or message_status = '') ]];
					local params = {domain_uuid = domain_uuid, voicemail_uuid = voicemail_uuid};
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
					end
					dbh:query(sql, params, function(row)
						new_messages = row["new_messages"];
					end);
					dtmf_digits = macro(session, "new_messages", 1, 100, new_messages);
				end
			--saved voicemail count
				if (session:ready()) then
					if (string.len(dtmf_digits) == 0) then
						sql = [[SELECT count(*) as saved_messages FROM v_voicemail_messages
							WHERE domain_uuid = :domain_uuid
							AND voicemail_uuid = :voicemail_uuid
							AND message_status = 'saved' ]];
						local params = {domain_uuid = domain_uuid, voicemail_uuid = voicemail_uuid};
						if (debug["sql"]) then
							freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
						end
						dbh:query(sql, params, function(row)
							saved_messages = row["saved_messages"];
						end);
						dtmf_digits = macro(session, "saved_messages", 1, 100, saved_messages);
					end
				end
			--to listen to new message
				if (session:ready() and new_messages ~= '0') then
					if (string.len(dtmf_digits) == 0) then
						dtmf_digits = macro(session, "listen_to_new_messages", 1, 100, '');
					end
				end
			--to listen to saved message
				if (session:ready() and saved_messages ~= '0') then
					if (string.len(dtmf_digits) == 0) then
						dtmf_digits = macro(session, "listen_to_saved_messages", 1, 100, '');
					end
				end
			--for advanced options
				if (session:ready()) then
					if (string.len(dtmf_digits) == 0) then
						dtmf_digits = macro(session, "advanced", 1, 100, '');
					end
				end
			--to exit press #
				--if (session:ready()) then
				--	if (string.len(dtmf_digits) == 0) then
				--		dtmf_digits = macro(session, "to_exit_press", 1, 3000, '');
				--	end
				--end
			--process the dtmf
				if (session:ready()) then
					if (dtmf_digits == "1") then
						menu_messages("new");
					elseif (dtmf_digits == "2") then
						menu_messages("saved");
					elseif (dtmf_digits == "5") then
						timeouts = 0;
						advanced();
					elseif (dtmf_digits == "0") then
						main_menu();
					elseif (dtmf_digits == "*") then
						dtmf_digits = '';
						macro(session, "goodbye", 1, 100, '');
						session:hangup();
					else
						if (session:ready()) then
							timeouts = timeouts + 1;
							if (timeouts < max_timeouts) then
								main_menu();
							else
								macro(session, "goodbye", 1, 1000, '');
								session:hangup();
							end
						end
					end
				end
		end
	end
