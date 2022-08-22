--[[
	The Initial Developer of the Original Code is
	ucall <https://uvoice.ucall.co.ao/> [ucall]

	Portions created by the Initial Developer are Copyright (C)
	the Initial Developer. All Rights Reserved.

	Contributor(s):
	ucall <https://uvoice.ucall.co.ao/> [ucall]
--]]

--voicemail count if zero new messages set the mwi to no
	function message_waiting(voicemail_id, domain_uuid)

		--initialize the array and add the voicemail_id
		 	local accounts = {}

		--add the current voicemail id to the accounts array
			table.insert(accounts, voicemail_id);

		--get the voicemail id and all related mwi accounts
			local sql = [[SELECT extension, number_alias from v_extensions
				WHERE domain_uuid = :domain_uuid
				AND (
					mwi_account = :voicemail_id
					OR mwi_account = :mwi_account
					OR number_alias = :voicemail_id
				)]];
			local params = {domain_uuid = domain_uuid, voicemail_id = voicemail_id, 
				mwi_account = voicemail_id .. "@" .. domain_name};
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[voicemail] SQL: " .. sql .. "; params:" .. json.encode(params) .. "\n");
			end
			dbh:query(sql, params, function(row)
				table.insert(accounts, row["extension"]);
			end);
		--freeswitch.consoleLog("notice"," voice_mail_id :"..tostring(voicemail_id).."\n");
		--freeswitch.consoleLog("notice"," domain :"..tostring(domain_uuid).."\n");

		--get new and saved message counts
			local new_messages, saved_messages = message_count_by_id(voicemail_id, domain_uuid);

		--freeswitch.consoleLog("notice"," new_messages:"..tostring(new_messages).."\n saved_messages :"..tostring(saved_messages).."\n accounts:" ..tostring(accounts).."\n");
		--send the message waiting event
			for _,value in ipairs(accounts) do
				--add the domain to voicemail id
					local account = value.."@"..domain_name;
		--freeswitch.consoleLog("notice"," account :"..tostring(account).."\n");
				--send the message waiting notifications
					mwi_notify(account, new_messages, saved_messages);
				--send information to the console
					if (debug["info"]) then
						if new_messages == "0" then
							freeswitch.consoleLog("notice", "[voicemail] mailbox: "..account.." messages: no new messages\n");
						else
							freeswitch.consoleLog("notice", "[voicemail] mailbox: "..account.." messages: " .. new_messages .. " new message(s)\n");
						end
					end
			end
		--freeswitch.consoleLog("notice"," voice_mail_id :"..tostring(voicemail_id).."\n");
		--freeswitch.consoleLog("notice"," domain :"..tostring(domain_uuid).."\n");
	end
