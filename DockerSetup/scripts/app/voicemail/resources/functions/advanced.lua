--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define a function for the advanced menu
	function advanced ()
		--clear the dtmf
			dtmf_digits = '';
		--flush dtmf digits from the input buffer
			session:flushDigits();
		--To record a greeting press 1
			if (session:ready()) then
				dtmf_digits = macro(session, "to_record_greeting", 1, 100, '');
			end
		--To choose greeting press 2
			if (session:ready()) then
				if (string.len(dtmf_digits) == 0) then
					dtmf_digits = macro(session, "choose_greeting", 1, 100, '');
				end
			end
		--To record your name 3
			if (session:ready()) then
				if (string.len(dtmf_digits) == 0) then
					dtmf_digits = macro(session, "to_record_name", 1, 100, '');
				end
			end
		--To change your password press 6
			if (session:ready()) then
				if (string.len(dtmf_digits) == 0) then
					dtmf_digits = macro(session, "change_password", 1, 100, '');
				end
			end
		--For the main menu press 0
			if (session:ready()) then
				if (string.len(dtmf_digits) == 0) then
					dtmf_digits = macro(session, "main_menu", 1, 5000, '');
				end
			end
		--process the dtmf
			if (session:ready()) then
				if (dtmf_digits == "1") then
					--To record a greeting press 1
					timeouts = 0;
					record_greeting(nil,"advanced");
				elseif (dtmf_digits == "2") then
					--To choose greeting press 2
					timeouts = 0;
					choose_greeting();
				elseif (dtmf_digits == "3") then
					--To record your name 3
					record_name("advanced");
				elseif (dtmf_digits == "6") then
					--To change your password press 6
					change_password(voicemail_id, "advanced");
				elseif (dtmf_digits == "0") then
					--For the main menu press 0
					timeouts = 0;
					main_menu();
				else
					timeouts = timeouts + 1;
					if (timeouts <= max_timeouts) then
						advanced();
					else
						macro(session, "goodbye", 1, 1000, '');
						session:hangup();
					end
				end
			end
	end
