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
		
		
		--[[ Used within RPM ]]
				if (idx == 09) then -- [[ Pitch range select ]] 
					msg = {item = 106, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 17) then
					msg = {item = 106,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
						
				elseif (idx == 10) then   --[[ Poly select ]]
					msg = {item = 107, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 18) then
					msg = {item = 107,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
			--[[==========================================================]]	
			--[[==========================================================]]	
					
				elseif (idx == 34) then  --[[ Osc 2 Wave ]]
					msg = {item = 114, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)		
				elseif (idx == 42) then
					msg = {item = 114,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)	
						
				elseif (idx == 35) then --[[ Osc 2 Octave ]]
					msg = {item = 115, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 43) then
					msg = {item = 115,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
				elseif (idx == 36) then --[[ Osc 2 Semitone ]]
					msg = {item = 110, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 44) then
					msg = {item = 110,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
				elseif (idx == 37) then --[[ Osc 2 Fine Tune ]]
					msg = {item = 111, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 45) then
					msg = {item = 111,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
			--[[==========================================================]]	
			--[[==========================================================]]	
					
				elseif (idx == 50) then  --[[ Osc 1 Wave ]]
					msg = {item = 112, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)		
				elseif (idx == 58) then
					msg = {item = 112,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)	
						
				elseif (idx == 51) then --[[ Osc 1 Octave ]]
					msg = {item = 113, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 59) then
					msg = {item = 113,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
				elseif (idx == 52) then --[[ Osc 1 Semitone ]]
					msg = {item = 108, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 60) then
					msg = {item = 108,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
				elseif (idx == 53) then --[[ Osc 1 Fine Tune ]]
					msg = {item = 109, value = -1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				elseif (idx == 61) then
					msg = {item = 109,  value = 1, time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				
			--[[==========================================================]]	
			--[[==========================================================]]	
			
--[[ Used within devc_switch(midi) ]]			
			if (current_mode == sys_msg.auto_prog) then --[[ Only switch device layouts in prog ]]
	
		if     (midi == btn_state[3][4]) then --[[ If left arrow pressed, decrement.  ]]
		
			devc_counter = devc_counter-1
			--[[ The second instance of devc_counter should be the maximum # of devices available above ]]
			if (devc_counter == -1) then
				devc_counter = 2
			end	
			
		elseif (midi == btn_state[4][4]) then --[[ If right arrow pressed, increment. ]]
		
			devc_counter = devc_counter+1
			--[[ The first instance of devc_counter should be the maximum # of devices available above ]]
			if (devc_counter == 3) then
				devc_counter = 0
			end
			
		end
		
		if devc_counter == 0 then     --[[ Default layout, for Reason non-device items ]]
			devc_name = "default"	
		elseif devc_counter == 1 then --[[ Subtractor layout ]]
			devc_name = "subtractor"		
		elseif devc_counter == 2 then --[[ Malstrom layout ]]
			devc_name = "malstrom"
		end
		
		
		
	if (return_midi == nil) then
		--[[ This is a dummy message. it does nothing because that hex address has no key on it. 
		     This also ensures an assignment check on this function always returns a table
			 I consider this rudimentary input checking
		  ]]
		table.insert(remote.make_midi("B0 63 00"))
	end
	
	
			--[[ Pad Logic, used within RDM]]
		if (string.match(out_midi, "9.*")
		and (devc_name == "subtractor") 
		and (current_mode == sys_msg.auto_prog)) then
			
		end