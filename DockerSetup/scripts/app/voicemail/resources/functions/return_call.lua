--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--define a function to return the call
	function return_call(destination)
		if (session:ready()) then
			--clear the dtmf
				dtmf_digits = '';
			--flush dtmf digits from the input buffer
				session:flushDigits();
			--transfer the call
				session:transfer(destination, "XML", context);
		end
	end
