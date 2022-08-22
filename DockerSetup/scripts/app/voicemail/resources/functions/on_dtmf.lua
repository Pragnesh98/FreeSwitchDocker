--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define on_dtmf call back function
	function on_dtmf(s, type, obj, arg)
		if (type == "dtmf") then
			freeswitch.console_log("info", "[voicemail] dtmf digit: " .. obj['digit'] .. ", duration: " .. obj['duration'] .. "\n");
			if (obj['digit'] == "#") then
				return 0;
			else
				dtmf_digits = dtmf_digits .. obj['digit'];
				if (debug["info"]) then
					freeswitch.console_log("info", "[voicemail] dtmf digits: " .. dtmf_digits .. ", length: ".. string.len(dtmf_digits) .." max_digits: " .. max_digits .. "\n");
				end
				if (stream_seek == true) then
					if (dtmf_digits == "4") then
						dtmf_digits = "";
						return("seek:-5000");
					end
					if (dtmf_digits == "5") then
						dtmf_digits = "";
						return("pause");
					end
					if (dtmf_digits == "6") then
						dtmf_digits = "";
						return("seek:+5000");
					end
				end
				if (string.len(dtmf_digits) >= max_digits) then
					if (debug["info"]) then
						freeswitch.console_log("info", "[voicemail] max_digits reached\n");
					end
					return 0;
				end
			end
		end
		return 0;
	end
