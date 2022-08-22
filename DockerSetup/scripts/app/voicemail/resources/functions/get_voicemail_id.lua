--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--get the voicemail id
	function get_voicemail_id()
		session:flushDigits();
		dtmf_digits = '';
		voicemail_id = macro(session, "voicemail_id", 20, 5000, '');
		if (string.len(voicemail_id) == 0) then
			if (session:ready()) then
				timeouts = timeouts + 1;
				if (timeouts < max_timeouts) then
					voicemail_id = get_voicemail_id();
				else
					macro(session, "goodbye", 1, 1000, '');
					session:hangup();
				end
			end
		end
		return voicemail_id;
	end
