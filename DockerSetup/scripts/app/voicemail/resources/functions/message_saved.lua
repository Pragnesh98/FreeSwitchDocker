--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--save the message
	function message_saved(voicemail_id, uuid)
		--clear the dtmf
			dtmf_digits = '';
		--flush dtmf digits from the input buffer
			session:flushDigits();
		--get the voicemail_uuid
			local sql = [[SELECT * FROM v_voicemails
				WHERE domain_uuid = :domain_uuid
				AND voicemail_id = :voicemail_id]];
			local params = {domain_uuid = domain_uuid, voicemail_id = voicemail_id};
			dbh:query(sql, params, function(row)
				db_voicemail_uuid = row["voicemail_uuid"];
			end);
		--delete from the database
			sql = [[UPDATE v_voicemail_messages SET message_status = 'saved'
				WHERE domain_uuid = :domain_uuid
				AND voicemail_uuid = :voicemail_uuid
				AND voicemail_message_uuid = :uuid]];
			params = {domain_uuid = domain_uuid, voicemail_uuid = db_voicemail_uuid, uuid = uuid};
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
			end
			dbh:query(sql, params);
		--log to console
			if (debug["info"]) then
				freeswitch.consoleLog("notice", "[voicemail][saved] id: " .. voicemail_id .. " message: "..uuid.."\n");
			end
		--check the message waiting status
			message_waiting(voicemail_id, domain_uuid);
		--clear the variable
			db_voicemail_uuid = '';
	end
