		--[[ Cover the defaults ]]
		if (out_midi == pad_state.toggle[i][2]) then --[[ Pad Pressed ]]	
		
			if ((devc_text == "subtractor") 
			and (current_mode == sys_msg.auto_prog)
			and (devc_layout.subtractor[i] ~= 1)) then
			
				table.insert(events, remote.make_midi(pad_state.subtractor[i][2]))
			
			end
			
		elseif (out_midi == pad_state.toggle[i][1]) then --[[ Pad Released ]]
		
			if ((devc_text == "subtractor") 
			and (current_mode == sys_msg.auto_prog)
			and (devc_layout.subtractor[i] ~= 1)) then
			
				table.insert(events, remote.make_midi(pad_state.subtractor[i][1]))
				
			end
			
		end
