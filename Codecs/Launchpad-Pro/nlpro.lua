--[[___________________________________________________________________________________________________
  || Novation Launchpad Pro -- Propellerhead "Remote" Codec                                          ||
  || Developed by -- James "Nornec" Ratliff                                                          ||
  ||                                                                                                 ||
  || File: nlpro.lua                                                                                 ||
  || Desc:                                                                                           ||
  || This file includes the main routines for running the codec.                                     ||
  ||                                                                                                 ||
  |---------------------------------------------------------------------------------------------------|
  || A few notes before code:                                                                        ||
  || + The "print" function has been supplanted by "remote.trace(<string>)".                         ||
  ||   Use this call for debugging but remove all calls before using in Reason. This will only slow  ||
  ||   things down.                                                                                  ||
  || + The intention of this codec is not to use the pads in programmer mode as a keyboard.          ||
  ||   Novation's firmware does an excellent job supplying (and subsequently mapping) a fully        ||
  ||   functional 127 key keyboard with scale modes built-in.                                        ||
  || + This codec is designed to be used by individuals that want to do live performances            ||
  ||   and/or want a faster work flow while composing or recording.                                  ||
  || + Having said this, the codec is designed to my specifications based on features that I         ||
  ||   never had during my many years using Reason, if you would like to see a feature added,        ||
  ||   please send me an email (jaynornec@gmail.com) and I will see to its feasability               ||
  || + I was disheartened knowing upon the purchase of the Novation Launchpad Pro that its           ||
  ||   compatibility with Reason was lacking, however I hope this codec is a useful marriage         ||
  ||   of "note" mode and "programmer" mode.                                                         ||
  || + Finally, I want this codec to be as documented as possible. If something is not clear         ||
  ||   or can/should be extrapolated, please send me an email: jaynornec@gmail.com                   ||
  |---------------------------------------------------------------------------------------------------|
  || LAUNCHPAD SETUP INSTRUCTIONS                                                                    ||
  ||   For proper operation, please edit the settings of the launchpad from the 'setup' menu         ||
  ||   as follows:                                                                                   ||
  ||   + Disable velocity control in Programmer mode                                                 ||
  ||   + Disable aftertouch control in Programmer mode                                               ||
  ||   + Disable internal (INT) pad lighting on all modes.                                           ||
  ||     (setting this option in one mode will affect all modes)                                     ||
  ```````````````````````````````````````````````````````````````````````````````````````````````````]] 
  
--[[---------------]]
--[[  Definitions  ]]
--[[---------------]]

--[[ In parts of the code, we must assemble a byte string to represent a control item.
     Since it is not easy to reference items by byte string every time we must call them
	 (this would be a nightmare to read if that were the case), we can assemble the message
	 in pieces and easily reference a control item elsewhere. ]]
 
local    on = "7F"     --[[ 'On'   (127 decimal) flag that appears at the end of a byte string. ]]
local   off = "00"     --[[ 'Off'  (000 decimal)   ''                                           ]]
local  half = "40"     --[[ 'Half' (064 decimal)   ''                                           ]]
local sysx_hdr = "F0 00 20 29 02 10 "  --[[ sysx header before any sysx message                 ]]
local sysx_trm = "F7"  --[[ sysx terminator as the last byte of any sysx message                ]]
local msg = {}         --[[ Used in the remote_process_midi function                            ]]
local current_mode     --[[ Holds the current mode (sysx message) in memory                     ]]
local devc_name        --[[ Holds the text name of the selected device in memory                ]]
local current_group= 9 --[[ Holds the currently selected input group in memory                  ]]
local last_group   = 0 --[[ Holds the last used group in memory                                 ]]
local hold = false     --[[ Used to see if a button is being held down. If so, don't repeat msg ]]
local state_midi = {}  --[[ Main midi return table                                              ]]
local prev_state_midi = {}
local count = 0        --[[ Used in error checking                                              ]] 
local errors = {}      --[[ Used in error checking                                              ]]
local event = {}       --[[ Defined before RPM to be used to define encoder controls on the fly ]]

local  btn = 
{
	--[[ This table references the 1st and 2nd byte in a surface item midi string. Each control has a 
	     different reference. 
	  ]]
	
	up      = "B0 5B ",
	down    = "B0 5C ",
	left    = "B0 5D ",
	right   = "B0 5E ",
	session = "B? 5F ",
	note    = "B? 60 ",
	device  = "B? 61 ",
	user    = "B? 62 ",
	              
	group1  = "B0 59 ",
	group2  = "B0 4F ",
	group3  = "B0 45 ",
	group4  = "B0 3B ",
	group5  = "B0 31 ",
	group6  = "B0 27 ",
	group7  = "B0 1D ",
	group8  = "B0 13 ",
	              
	stop    = "B0 08 ",
	send    = "B0 07 ",
	pan     = "B0 06 ",
	vol     = "B0 05 ",
	solo    = "B0 04 ",
	mute    = "B0 03 ",
	trk_sel = "B0 02 ",
	rec_arm = "B0 01 ",
	              
	rec     = "B0 0A ",
	dbl     = "B0 14 ",
	dupe    = "B0 1E ",
	quant   = "B0 28 ",
	del     = "B0 32 ",
	undo    = "B0 3C ",
	click   = "B0 46 ",
	shift   = "B0 50 ",
	
	
}   
  
local  pad = 
{
	--[[ 
		Same as btn2{} but for the 64 pads in the center. 
	  ]]
	  
	p11  = "90 0b ",
    p21  = "90 0c ",
    p31  = "90 0d ",
    p41  = "90 0e ",
    p51  = "90 0f ",
    p61  = "90 10 ",
    p71  = "90 11 ",
    p81  = "90 12 ",
               
    p12  = "90 15 ",
    p22  = "90 16 ",
    p32  = "90 17 ",
    p42  = "90 18 ",
    p52  = "90 19 ",
    p62  = "90 1a ",
    p72  = "90 1b ",
    p82  = "90 1c ",
               
    p13  = "90 1f ",
    p23  = "90 20 ",
    p33  = "90 21 ",
    p43  = "90 22 ",
    p53  = "90 23 ",
    p63  = "90 24 ",
    p73  = "90 25 ",
    p83  = "90 26 ",
               
    p14  = "90 29 ",
    p24  = "90 2a ",
    p34  = "90 2b ",
    p44  = "90 2c ",
    p54  = "90 2d ",
    p64  = "90 2e ",
    p74  = "90 2f ",
    p84  = "90 30 ",
               
    p15  = "90 33 ",
    p25  = "90 34 ",
    p35  = "90 35 ",
    p45  = "90 36 ",
    p55  = "90 37 ",
    p65  = "90 38 ",
    p75  = "90 39 ",
    p85  = "90 3a ",
               
    p16  = "90 3d ",
    p26  = "90 3e ",
    p36  = "90 3f ",
    p46  = "90 40 ",
    p56  = "90 41 ",
    p66  = "90 42 ",
    p76  = "90 43 ",
    p86  = "90 44 ",
               
    p17  = "90 47 ",
    p27  = "90 48 ",
    p37  = "90 49 ",
    p47  = "90 4a ",
    p57  = "90 4b ",
    p67  = "90 4c ",
    p77  = "90 4d ",
    p87  = "90 4e ",
               
    p18  = "90 51 ",
    p28  = "90 52 ",
    p38  = "90 53 ",
    p48  = "90 54 ",
    p58  = "90 55 ",
    p68  = "90 56 ",
    p78  = "90 57 ",
    p88  = "90 58 ",
 
}

local  fdr =
{
	--[[ 
		Same as btn{} but for the 8 surrogate faders. 
		Since there are only 8, it's unnecessary to name these.
		This makes the table addresable by #.
	  ]]
	  
--[[01  
  ]]"B0 15 ",
	"B0 16 ",
	"B0 17 ",
	"B0 18 ",
	"B0 19 ",
	"B0 1A ",
	"B0 1B ",
	"B0 1C ",
	
}

local devc_actions =
{
	subtractor =
	{
		--[[These number assignments correspond to the pad table, not the device table.]]
		
		--[[ Pitch range select ]]
		[09]={item = 131, value = -1, time_stamp = event.time_stamp},
		[17]={item = 131,  value = 1, time_stamp = event.time_stamp},
		
		--[[ Poly select ]]
		[10]={item = 132, value = -1, time_stamp = event.time_stamp},
		[18]={item = 132,  value = 1, time_stamp = event.time_stamp},
		
		--[[ Osc 1 Functions ]]
		--[[ Osc 1 Wave ]]
		[50]={item = 133, value = -1, time_stamp = event.time_stamp},	
		[58]={item = 133,  value = 1, time_stamp = event.time_stamp},
		--[[ Osc 1 Octave ]]
		[51]={item = 134, value = -1, time_stamp = event.time_stamp},
		[59]={item = 134,  value = 1, time_stamp = event.time_stamp},
		--[[ Osc 1 Semitone ]]
		[52]={item = 135, value = -1, time_stamp = event.time_stamp},
		[60]={item = 135,  value = 1, time_stamp = event.time_stamp},
		--[[ Osc 1 Fine Tune ]]
		[53]={item = 136, value = -1, time_stamp = event.time_stamp},
		[61]={item = 136,  value = 1, time_stamp = event.time_stamp},
			
		--[[ Osc 2 Functions ]]
		--[[ Osc 2 Wave ]]
		[34]={item = 137, value = -1, time_stamp = event.time_stamp},
		[42]={item = 137,  value = 1, time_stamp = event.time_stamp},
		--[[ Osc 2 Octave ]]
		[35]={item = 138, value = -1, time_stamp = event.time_stamp},
		[43]={item = 138,  value = 1, time_stamp = event.time_stamp},
		--[[ Osc 2 Semitone ]]
		[36]={item = 139, value = -1, time_stamp = event.time_stamp},
		[44]={item = 139,  value = 1, time_stamp = event.time_stamp},
		--[[ Osc 2 Fine Tune ]]
		[37]={item = 140, value = -1, time_stamp = event.time_stamp},
		[45]={item = 140,  value = 1, time_stamp = event.time_stamp},
			
	}
}

local color =
{      
	--[[
		Hex color table for used colors (from the Launchpad Pro dev manual
		Note: These are not traditional RGB 0-255 color definitions.
			  These are set by device specific byte outputs.
			  There's a normal entry (D) and a bright entry (B).
			  An additional variant (V) vibrant is available for some colors.
			  An additional variant (W) whitened is available for some colors.
		
   Color    Color Hex  Bright Hex             ]]
	grey = {D = "02",  B = "03"},
	gry2 = {D = "47",  B = "46"},
	gry3 = {D = "75",  B = "77"},
	grbl = {D = "5C",  B = "5B"},
	 red = {D = "79",  B = "78", V = "05", W = "04"},
	lime = {D = "10",  B = "49"},
	 grn = {D = "12",  B = "19", V = "4C"},
	turq = {D = "27",  B = "24"},
	viol = {D = "31",  B = "51"},
	pink = {D = "38",  B = "39"},
	rorg = {D = "3C",  B = "54"},
	wood = {D = "53",  B = "54"},
	orng = {D = "54",  B = "05"},
	blue = {D = "2F",  B = "2D"},
	ylow = {D = "61",  B = "6D"},
	
}

local sys_msg = 
{
--[[
  || Table for storing sysx messages, some available normally while holding the 'Setup' button 
  || RBAs for each of the 4 modes (excluding LIVE mode) follow
  || There are 4 more RBAs that appear when using the Setup button.  
  || When you put the device into Standalone (sysx) mode, the device appears to default to the note screen.
  ]]
   
	auto_note = sysx_hdr.."2C 00 "..sysx_trm,
	auto_drum = sysx_hdr.."2C 01 "..sysx_trm,
	auto_fade = sysx_hdr.."2C 02 "..sysx_trm,
	auto_prog = sysx_hdr.."2C 03 "..sysx_trm,
	
	auto_sysx = sysx_hdr.."21 01 "..sysx_trm,
	
	--[[ Sets the side/front LED color ]]
	side_ledc = sysx_hdr.."0A 63 "..color.grn.B..sysx_trm,
	side_ledd = sysx_hdr.."0A 63 "..color.red.B..sysx_trm,
	side_lede = sysx_hdr.."0A 63 "..color.blue.B..sysx_trm,
	
	
--[[ 
  || When a user manually changes the mode using the 'setup' key, these sysx messages are delivered
  || When any of the auto RBAs are issued as midi, these are the modes the device sends as a midi event. 
  || You can use these to control IO accordingly. 
  ]]
	manu_note = sysx_hdr.."2F 00 "..sysx_trm,
	manu_drum = sysx_hdr.."2F 01 "..sysx_trm,
	manu_fade = sysx_hdr.."2F 02 "..sysx_trm,
	manu_prog = sysx_hdr.."2F 03 "..sysx_trm,
	
}


local set_mode =
{	
	--[[ Short-hand table for setting a mode using make_midi ]]
	
	sysx = remote.make_midi(sys_msg.auto_sysx),
	note = remote.make_midi(sys_msg.auto_note),
	drum = remote.make_midi(sys_msg.auto_drum),
	fade = remote.make_midi(sys_msg.auto_fade),
	prog = remote.make_midi(sys_msg.auto_prog),
 
}

local btn_state =
{
--[[ 
  || This table is an indexed field for button states. [x][y] where:
  || [x] = button index
  || [y] = state, where:
  ||     [1] = default -----|
  ||     [2] = bright  -----|-|
  ||     [3] = off----------| | --> corresponds to a button press
  ||     [4] = on  -----------|
  ||
  || A typical reference to a button would be: 
  || btn_state[3][1] -- btn.left in the down btn_state.
  || btn_state[3][2] -- btn.left in the up btn_state.
  || btn_state[3][3] -- btn.left full off  (00)
  || btn_state[3][4] -- btn.left full on   (7F)
  ]]

--[[01
  ]]{btn.up     ..color.viol.D, btn.up     ..color.viol.B, btn.up     ..off, btn.up     ..on},  
    {btn.down   ..color.viol.D, btn.down   ..color.viol.B, btn.down   ..off, btn.down   ..on}, 
    {btn.left   ..color.turq.D, btn.left   ..color.turq.B, btn.left   ..off, btn.left   ..on}, 
    {btn.right  ..color.turq.D, btn.right  ..color.turq.B, btn.right  ..off, btn.right  ..on}, 
    {btn.session..color.gry3.D, btn.session..color.ylow.B, btn.session..off, btn.session..on}, 
    {btn.note   ..color.gry3.D, btn.note   ..color.blue.B, btn.note   ..off, btn.note   ..on}, 
    {btn.device ..color.gry3.D, btn.device  ..color.grn.B, btn.device ..off, btn.device ..on}, 
    {btn.user   ..color.gry3.D, btn.user   ..color.pink.B, btn.user   ..off, btn.user   ..on}, 
--[[09                                                                
  ]]{btn.group1 ..color.wood.D, btn.group1 ..color.wood.B, btn.group1 ..off, btn.group1 ..on}, 
    {btn.group2 ..color.wood.D, btn.group2 ..color.wood.B, btn.group2 ..off, btn.group2 ..on}, 
    {btn.group3 ..color.wood.D, btn.group3 ..color.wood.B, btn.group3 ..off, btn.group3 ..on}, 
    {btn.group4 ..color.wood.D, btn.group4 ..color.wood.B, btn.group4 ..off, btn.group4 ..on}, 
    {btn.group5 ..color.wood.D, btn.group5 ..color.wood.B, btn.group5 ..off, btn.group5 ..on}, 
    {btn.group6 ..color.wood.D, btn.group6 ..color.wood.B, btn.group6 ..off, btn.group6 ..on}, 
    {btn.group7 ..color.wood.D, btn.group7 ..color.wood.B, btn.group7 ..off, btn.group7 ..on}, 
    {btn.group8 ..color.wood.D, btn.group8 ..color.wood.B, btn.group8 ..off, btn.group8 ..on}, 
--[[17                                                            
  ]]{btn.stop   ..color.rorg.D, btn.stop   ..color.rorg.B, btn.stop   ..off, btn.stop   ..on}, 
    {btn.send   ..color.grey.D, btn.send   ..color.grey.B, btn.send   ..off, btn.send   ..on}, 
    {btn.pan    ..color.grey.D, btn.pan    ..color.grey.B, btn.pan    ..off, btn.pan    ..on}, 
    {btn.vol    ..color.grey.D, btn.vol    ..color.grey.B, btn.vol    ..off, btn.vol    ..on}, 
    {btn.solo   ..color.lime.D, btn.solo   ..color.lime.B, btn.solo   ..off, btn.solo   ..on}, 
    {btn.mute   ..color.pink.D, btn.mute   ..color.pink.B, btn.mute   ..off, btn.mute   ..on}, 
    {btn.trk_sel..color.grey.D, btn.trk_sel..color.grey.B, btn.trk_sel..off, btn.trk_sel..on}, 
    {btn.rec_arm..color.rorg.D, btn.rec_arm..color.rorg.B, btn.rec_arm..off, btn.rec_arm..on}, 
--[[25                                                              
  ]]{btn.rec     ..color.red.D, btn.rec     ..color.red.B, btn.rec    ..off, btn.rec    ..on}, 
    {btn.dbl    ..color.grey.D, btn.dbl    ..color.grey.B, btn.dbl    ..off, btn.dbl    ..on},               
    {btn.dupe   ..color.grey.D, btn.dupe   ..color.grey.B, btn.dupe   ..off, btn.dupe   ..on}, 
    {btn.quant  ..color.orng.D, btn.quant  ..color.orng.B, btn.quant  ..off, btn.quant  ..on}, 
    {btn.del    ..color.viol.D, btn.del    ..color.viol.B, btn.del    ..off, btn.del    ..on}, 
    {btn.undo   ..color.viol.D, btn.undo   ..color.viol.B, btn.undo   ..off, btn.undo   ..on}, 
    {btn.click  ..color.turq.D, btn.click  ..color.turq.B, btn.click  ..off, btn.click  ..on}, 
    {btn.shift  ..color.turq.D, btn.shift  ..color.turq.B, btn.shift  ..off, btn.shift  ..on},
	
}

local pad_state = 
{
	--[[ Pads work differently than buttons on the main screen, in that some can be toggles instead of 
	     sends, depending on the device selected ]]
	toggle =
	{	
		{pad.p11..off, pad.p11..on},
		{pad.p21..off, pad.p21..on},
		{pad.p31..off, pad.p31..on},
		{pad.p41..off, pad.p41..on},
		{pad.p51..off, pad.p51..on},
		{pad.p61..off, pad.p61..on},
		{pad.p71..off, pad.p71..on},
		{pad.p81..off, pad.p81..on},
								   
		{pad.p12..off, pad.p12..on},
		{pad.p22..off, pad.p22..on},
		{pad.p32..off, pad.p32..on},
		{pad.p42..off, pad.p42..on},
		{pad.p52..off, pad.p52..on},
		{pad.p62..off, pad.p62..on},
		{pad.p72..off, pad.p72..on},
		{pad.p82..off, pad.p82..on},
								   
		{pad.p13..off, pad.p13..on},
		{pad.p23..off, pad.p23..on},
		{pad.p33..off, pad.p33..on},
		{pad.p43..off, pad.p43..on},
		{pad.p53..off, pad.p53..on},
		{pad.p63..off, pad.p63..on},
		{pad.p73..off, pad.p73..on},
		{pad.p83..off, pad.p83..on},
								   
		{pad.p14..off, pad.p14..on},
		{pad.p24..off, pad.p24..on},
		{pad.p34..off, pad.p34..on},
		{pad.p44..off, pad.p44..on},
		{pad.p54..off, pad.p54..on},
		{pad.p64..off, pad.p64..on},
		{pad.p74..off, pad.p74..on},
		{pad.p84..off, pad.p84..on},
								   
		{pad.p15..off, pad.p15..on},
		{pad.p25..off, pad.p25..on},
		{pad.p35..off, pad.p35..on},
		{pad.p45..off, pad.p45..on},
		{pad.p55..off, pad.p55..on},
		{pad.p65..off, pad.p65..on},
		{pad.p75..off, pad.p75..on},
		{pad.p85..off, pad.p85..on},
								   
		{pad.p16..off, pad.p16..on},
		{pad.p26..off, pad.p26..on},
		{pad.p36..off, pad.p36..on},
		{pad.p46..off, pad.p46..on},
		{pad.p56..off, pad.p56..on},
		{pad.p66..off, pad.p66..on},
		{pad.p76..off, pad.p76..on},
		{pad.p86..off, pad.p86..on},
								   
		{pad.p17..off, pad.p17..on},
		{pad.p27..off, pad.p27..on},
		{pad.p37..off, pad.p37..on},
		{pad.p47..off, pad.p47..on},
		{pad.p57..off, pad.p57..on},
		{pad.p67..off, pad.p67..on},
		{pad.p77..off, pad.p77..on},
		{pad.p87..off, pad.p87..on},
								   
		{pad.p18..off, pad.p18..on},
		{pad.p28..off, pad.p28..on},
		{pad.p38..off, pad.p38..on},
		{pad.p48..off, pad.p48..on},
		{pad.p58..off, pad.p58..on},
		{pad.p68..off, pad.p68..on},
		{pad.p78..off, pad.p78..on},
		{pad.p88..off, pad.p88..on},
	},
	
	default = 
	{
		{pad.p11..color.grey.D, pad.p11..color.grey.B},
		{pad.p21..color.grey.D, pad.p21..color.grey.B},
		{pad.p31..color.grey.D, pad.p31..color.grey.B},
		{pad.p41..color.grey.D, pad.p41..color.grey.B},
		{pad.p51..color.grey.D, pad.p51..color.grey.B},
		{pad.p61..color.grey.D, pad.p61..color.grey.B},
		{pad.p71..color.grey.D, pad.p71..color.grey.B},
		{pad.p81..color.grey.D, pad.p81..color.grey.B},
				 
		{pad.p12..color.grey.D, pad.p12..color.grey.B},
		{pad.p22..color.grey.D, pad.p22..color.grey.B},
		{pad.p32..color.grey.D, pad.p32..color.grey.B},
		{pad.p42..color.grey.D, pad.p42..color.grey.B},
		{pad.p52..color.grey.D, pad.p52..color.grey.B},
		{pad.p62..color.grey.D, pad.p62..color.grey.B},
		{pad.p72..color.grey.D, pad.p72..color.grey.B},
		{pad.p82..color.grey.D, pad.p82..color.grey.B},
				
		{pad.p13..color.grey.D, pad.p13..color.grey.B},
		{pad.p23..color.grey.D, pad.p23..color.grey.B},
		{pad.p33..color.grey.D, pad.p33..color.grey.B},
		{pad.p43..color.grey.D, pad.p43..color.grey.B},
		{pad.p53..color.grey.D, pad.p53..color.grey.B},
		{pad.p63..color.grey.D, pad.p63..color.grey.B},
		{pad.p73..color.grey.D, pad.p73..color.grey.B},
		{pad.p83..color.grey.D, pad.p83..color.grey.B},
				     
		{pad.p14..color.grey.D, pad.p14..color.grey.B},
		{pad.p24..color.grey.D, pad.p24..color.grey.B},
		{pad.p34..color.grey.D, pad.p34..color.grey.B},
		{pad.p44..color.grey.D, pad.p44..color.grey.B},
		{pad.p54..color.grey.D, pad.p54..color.grey.B},
		{pad.p64..color.grey.D, pad.p64..color.grey.B},
		{pad.p74..color.grey.D, pad.p74..color.grey.B},
		{pad.p84..color.grey.D, pad.p84..color.grey.B},
				
		{pad.p15..color.grey.D, pad.p15..color.grey.B},
		{pad.p25..color.grey.D, pad.p25..color.grey.B},
		{pad.p35..color.grey.D, pad.p35..color.grey.B},
		{pad.p45..color.grey.D, pad.p45..color.grey.B},
		{pad.p55..color.grey.D, pad.p55..color.grey.B},
		{pad.p65..color.grey.D, pad.p65..color.grey.B},
		{pad.p75..color.grey.D, pad.p75..color.grey.B},
		{pad.p85..color.grey.D, pad.p85..color.grey.B},
			
		{pad.p16..color.grey.D, pad.p16..color.grey.B},
		{pad.p26..color.grey.D, pad.p26..color.grey.B},
		{pad.p36..color.grey.D, pad.p36..color.grey.B},
		{pad.p46..color.grey.D, pad.p46..color.grey.B},
		{pad.p56..color.grey.D, pad.p56..color.grey.B},
		{pad.p66..color.grey.D, pad.p66..color.grey.B},
		{pad.p76..color.grey.D, pad.p76..color.grey.B},
		{pad.p86..color.grey.D, pad.p86..color.grey.B},
					
		{pad.p17..color.grey.D, pad.p17..color.grey.B},
		{pad.p27..color.grey.D, pad.p27..color.grey.B},
		{pad.p37..color.grey.D, pad.p37..color.grey.B},
		{pad.p47..color.grey.D, pad.p47..color.grey.B},
		{pad.p57..color.grey.D, pad.p57..color.grey.B},
		{pad.p67..color.grey.D, pad.p67..color.grey.B},
		{pad.p77..color.grey.D, pad.p77..color.grey.B},
		{pad.p87..color.grey.D, pad.p87..color.grey.B},
		      
		{pad.p18..color.grey.D, pad.p18..color.grey.B},
		{pad.p28..color.grey.D, pad.p28..color.grey.B},
		{pad.p38..color.grey.D, pad.p38..color.grey.B},
		{pad.p48..color.grey.D, pad.p48..color.grey.B},
		{pad.p58..color.grey.D, pad.p58..color.grey.B},
		{pad.p68..color.grey.D, pad.p68..color.grey.B},
		{pad.p78..color.grey.D, pad.p78..color.grey.B},
		{pad.p88..color.grey.D, pad.p88..color.grey.B},
	},
	
	subtractor = 
	{
		[0033]={pad.p11..color.turq.D, pad.p11..color.turq.D}, --[[ Border ]]
		[0034]={pad.p21..color.turq.D, pad.p21..color.turq.D}, --[[ Border ]]
		[0035]={pad.p31..color.turq.D, pad.p31..color.turq.D}, --[[ Border ]]
		[0036]={pad.p41..color.turq.D, pad.p41..color.turq.D}, --[[ Border ]]
		[0037]={pad.p51..color.turq.D, pad.p51..color.turq.D}, --[[ Border ]]
		[0038]={pad.p61..color.turq.D, pad.p61..color.turq.D}, --[[ Border ]]
		[0039]={pad.p71..color.turq.D, pad.p71..color.turq.D}, --[[ Border ]]
		[0040]={pad.p81..color.turq.D, pad.p81..color.turq.D}, --[[ Border ]]  
	    
		[0131]={pad.p12..color.turq.D, pad.p12..color.turq.B}, --[[ Pitch Bend Rng Down *encoder*]]
		[0132]={pad.p22..color.turq.D, pad.p22..color.turq.B}, --[[ Polyphony Down      *encoder*]]
		[0043]={pad.p32..color.gry2.D, pad.p32..color.grey.B}, --[[ LFO 1 Waveform      ]]
		[0044]={pad.p42..color.gry2.D, pad.p42..color.grey.B}, --[[ LFO 1 Destination   ]]
		[0045]={pad.p52..         off, pad.p52..         off},
		[0046]={pad.p62..color.gry2.D, pad.p62..color.grey.B}, --[[ LFO 2 Destination   ]]
		[0047]={pad.p72..         off, pad.p72..         off},
		[0048]={pad.p82..         off, pad.p82..         off}, 
		
		[7131]={pad.p13..color.turq.B, pad.p13..color.turq.D}, --[[ Pitch Bend Range Up *encoder*]]
		[7132]={pad.p23..color.turq.B, pad.p23..color.turq.D}, --[[ Polyphony Up        *encoder*]]
		[0051]={pad.p33.. color.red.W, pad.p33.. color.red.B}, --[[ LFO 1 Sync          ]]
		[0052]={pad.p43..         off, pad.p43..         off},
		[0053]={pad.p53..         off, pad.p53..         off},
		[0054]={pad.p63..color.gry2.D, pad.p63..color.gry2.B}, --[[ Mod Env Destination ]]
		[0055]={pad.p73..         off, pad.p73..         off},
		[0056]={pad.p83..         off, pad.p83..         off},
		 
		[0057]={pad.p14..color.gry2.D, pad.p14..color.grey.B}, --[[ Ext. Mod            ]]
		[0058]={pad.p24.. color.red.W, pad.p24.. color.red.B}, --[[ Noise Toggle        ]]
		[0059]={pad.p34..         off, pad.p34..         off},
		[0060]={pad.p44.. color.red.W, pad.p44.. color.red.B}, --[[ Osc1 Kbd. Track     ]]
		[0061]={pad.p54.. color.red.W, pad.p54.. color.red.B}, --[[ Osc2 Kbd. Track     ]]
		[0062]={pad.p64.. color.red.D, pad.p64..color.grey.B}, --[[ Mod Env Invert      ]]
		[0063]={pad.p74.. color.red.D, pad.p74..color.grey.B}, --[[ Filter Env Invert   ]]
		[0064]={pad.p84..         off, pad.p84..         off},
	
		[0065]={pad.p15..color.gry2.D, pad.p15..color.gry2.B}, --[[ Osc 2 Mode          ]]
		[0137]={pad.p25..color.turq.D, pad.p25..color.turq.B}, --[[ Osc 2 Waveform Down *encoder*]]
		[0138]={pad.p35..color.turq.D, pad.p35..color.turq.B}, --[[ Osc 2 Octave Down   *encoder*]]
		[0139]={pad.p45..color.turq.D, pad.p45..color.turq.B}, --[[ Osc 2 Semi Down     *encoder*]]
		[0140]={pad.p55..color.turq.D, pad.p55..color.turq.B}, --[[ Osc 2 Cent Down     *encoder*]]
		[0070]={pad.p65.. color.red.W, pad.p65.. color.red.B}, --[[ Ring Mod Toggle     ]]
		[0071]={pad.p75..         off, pad.p75..         off},
		[0072]={pad.p85..         off, pad.p85..         off},
	     
		[0073]={pad.p16.. color.red.W, pad.p16.. color.red.B}, --[[ Osc 2 Enable        ]]
		[7137]={pad.p26..color.turq.B, pad.p26..color.turq.D}, --[[ Osc 2 Waveform Up   *encoder*]]
		[7138]={pad.p36..color.turq.B, pad.p36..color.turq.D}, --[[ Osc 2 Octave Up     *encoder*]]
		[7139]={pad.p46..color.turq.B, pad.p46..color.turq.D}, --[[ Osc 2 Semi up       *encoder*]]
		[7140]={pad.p56..color.turq.B, pad.p56..color.turq.D}, --[[ Osc 2 Cent Up       *encoder*]]
		[0078]={pad.p66..         off, pad.p66..         off},
		[0079]={pad.p76..         off, pad.p76..         off},
		[0080]={pad.p86..         off, pad.p86..         off},
					                	
		[0081]={pad.p17..color.gry2.D, pad.p17..color.gry2.B}, --[[ Osc 1 Mode          ]]
		[0133]={pad.p27..color.turq.D, pad.p27..color.turq.B}, --[[ Osc 1 Waveform Down *encoder*]]
		[0134]={pad.p37..color.turq.D, pad.p37..color.turq.B}, --[[ Osc 1 Octave Down   *encoder*]]
		[0135]={pad.p47..color.turq.D, pad.p47..color.turq.B}, --[[ Osc 1 Semi Down     *encoder*]]
		[0136]={pad.p57..color.turq.D, pad.p57..color.turq.B}, --[[ Osc 1 Cent Down     *encoder*]]
		[0086]={pad.p67..         off, pad.p67..         off},
		[0087]={pad.p77..color.gry2.D, pad.p77..color.grey.B}, --[[ Filter 1 Type       ]]
		[0088]={pad.p87..         off, pad.p87..         off},
		                            
		[0089]={pad.p18..color.gry2.D, pad.p18..color.grey.B}, --[[ Note Mode           ]]
		[7133]={pad.p28..color.turq.B, pad.p28..color.turq.D}, --[[ Osc 1 Waveform Up   *encoder*]]
		[7134]={pad.p38..color.turq.B, pad.p38..color.turq.D}, --[[ Osc 1 Octave Up     *encoder*]]
		[7135]={pad.p48..color.turq.B, pad.p48..color.turq.D}, --[[ Osc 1 Semi up       *encoder*]]
		[7136]={pad.p58..color.turq.B, pad.p58..color.turq.D}, --[[ Osc 1 Cent Up       *encoder*]]
		[0094]={pad.p68..         off, pad.p68..         off},
		[0095]={pad.p78.. color.red.W, pad.p78.. color.red.B}, --[[ Filter Link         ]]
		[0096]={pad.p88.. color.red.W, pad.p88.. color.red.B}, --[[ Filter 2 Toggle     ]]
	},
	
	malstrom = 
	{
		{pad.p11..color.grn.D, pad.p11..color.grn.B},
		{pad.p21..color.grn.D, pad.p21..color.grn.B},
		{pad.p31..color.grn.D, pad.p31..color.grn.B},
		{pad.p41..color.grn.D, pad.p41..color.grn.B},
		{pad.p51..color.grn.D, pad.p51..color.grn.B},
		{pad.p61..color.grn.D, pad.p61..color.grn.B},
		{pad.p71..color.grn.D, pad.p71..color.grn.B},
		{pad.p81..color.grn.D, pad.p81..color.grn.B},
				  
		{pad.p12..color.grn.D, pad.p12..color.grn.B},
		{pad.p22..color.grn.D, pad.p22..color.grn.B},
		{pad.p32..color.grn.D, pad.p32..color.grn.B},
		{pad.p42..color.grn.D, pad.p42..color.grn.B},
		{pad.p52..color.grn.D, pad.p52..color.grn.B},
		{pad.p62..color.grn.D, pad.p62..color.grn.B},
		{pad.p72..color.grn.D, pad.p72..color.grn.B},
		{pad.p82..color.grn.D, pad.p82..color.grn.B},
			
		{pad.p13..color.grn.D, pad.p13..color.grn.B},
		{pad.p23..color.grn.D, pad.p23..color.grn.B},
		{pad.p33..color.grn.D, pad.p33..color.grn.B},
		{pad.p43..color.grn.D, pad.p43..color.grn.B},
		{pad.p53..color.grn.D, pad.p53..color.grn.B},
		{pad.p63..color.grn.D, pad.p63..color.grn.B},
		{pad.p73..color.grn.D, pad.p73..color.grn.B},
		{pad.p83..color.grn.D, pad.p83..color.grn.B},
				
		{pad.p14..color.grn.D, pad.p14..color.grn.B},
		{pad.p24..color.grn.D, pad.p24..color.grn.B},
		{pad.p34..color.grn.D, pad.p34..color.grn.B},
		{pad.p44..color.grn.D, pad.p44..color.grn.B},
		{pad.p54..color.grn.D, pad.p54..color.grn.B},
		{pad.p64..color.grn.D, pad.p64..color.grn.B},
		{pad.p74..color.grn.D, pad.p74..color.grn.B},
		{pad.p84..color.grn.D, pad.p84..color.grn.B},
				 
		{pad.p15..color.grn.D, pad.p15..color.grn.B},
		{pad.p25..color.grn.D, pad.p25..color.grn.B},
		{pad.p35..color.grn.D, pad.p35..color.grn.B},
		{pad.p45..color.grn.D, pad.p45..color.grn.B},
		{pad.p55..color.grn.D, pad.p55..color.grn.B},
		{pad.p65..color.grn.D, pad.p65..color.grn.B},
		{pad.p75..color.grn.D, pad.p75..color.grn.B},
		{pad.p85..color.grn.D, pad.p85..color.grn.B},
				
		{pad.p16..color.grn.D, pad.p16..color.grn.B},
		{pad.p26..color.grn.D, pad.p26..color.grn.B},
		{pad.p36..color.grn.D, pad.p36..color.grn.B},
		{pad.p46..color.grn.D, pad.p46..color.grn.B},
		{pad.p56..color.grn.D, pad.p56..color.grn.B},
		{pad.p66..color.grn.D, pad.p66..color.grn.B},
		{pad.p76..color.grn.D, pad.p76..color.grn.B},
		{pad.p86..color.grn.D, pad.p86..color.grn.B},
			
		{pad.p17..color.grn.D, pad.p17..color.grn.B},
		{pad.p27..color.grn.D, pad.p27..color.grn.B},
		{pad.p37..color.grn.D, pad.p37..color.grn.B},
		{pad.p47..color.grn.D, pad.p47..color.grn.B},
		{pad.p57..color.grn.D, pad.p57..color.grn.B},
		{pad.p67..color.grn.D, pad.p67..color.grn.B},
		{pad.p77..color.grn.D, pad.p77..color.grn.B},
		{pad.p87..color.grn.D, pad.p87..color.grn.B},
		           
		{pad.p18..color.grn.D, pad.p18..color.grn.B},
		{pad.p28..color.grn.D, pad.p28..color.grn.B},
		{pad.p38..color.grn.D, pad.p38..color.grn.B},
		{pad.p48..color.grn.D, pad.p48..color.grn.B},
		{pad.p58..color.grn.D, pad.p58..color.grn.B},
		{pad.p68..color.grn.D, pad.p68..color.grn.B},
		{pad.p78..color.grn.D, pad.p78..color.grn.B},
		{pad.p88..color.grn.D, pad.p88..color.grn.B},
	}

}

local fdr_state =
{
	default = 
	{
		sysx_hdr.."2B 00 00 "..color.grey.B,
		sysx_hdr.."2B 01 00 "..color.grey.B,
		sysx_hdr.."2B 02 00 "..color.grey.B,
		sysx_hdr.."2B 03 00 "..color.grey.B,
		sysx_hdr.."2B 04 00 "..color.grey.B, 
		sysx_hdr.."2B 05 00 "..color.grey.B, 
		sysx_hdr.."2B 06 00 "..color.grey.B, 
		sysx_hdr.."2B 07 00 "..color.grey.B, 
	},
	
	subtractor =
	{ --[[ Fader definitions by group. note the sysx_trm lines, those aren't used in the group. ]]
		g1 =
		{
			sysx_hdr.."2B 00 00 "..color.turq.D,
			sysx_hdr.."2B 01 00 "..color.turq.D,
			sysx_hdr.."2B 02 00 "..color.turq.D,
			sysx_hdr.."2B 03 00 "..color.turq.D,
			sysx_hdr.."2B 04 00 "..color.turq.B,
			sysx_hdr.."2B 05 00 "..color.turq.B,
			sysx_hdr.."2B 06 00 "..color.turq.B,
			sysx_hdr.."2B 07 00 "..color.turq.B,			
		},
		
		g2 = 
		{
			sysx_hdr.."2B 00 00 "..color.turq.B,
			sysx_hdr.."2B 01 00 "..color.turq.B,
			sysx_hdr.."2B 02 00 "..color.turq.B,
			sysx_hdr.."2B 03 00 "..color.turq.B,
			sysx_hdr.."2B 04 01 "..color.blue.D,
			sysx_hdr.."2B 05 00 "..color.red.D..on..sysx_trm,
			sysx_hdr.."2B 06 00 "..color.red.D..on..sysx_trm,
			sysx_hdr.."2B 07 00 "..color.red.D..on..sysx_trm,
		},
		g3 = 
		{
			sysx_hdr.."2B 00 00 "..color.blue.D,
			sysx_hdr.."2B 01 00 "..color.blue.D,
			sysx_hdr.."2B 02 00 "..color.blue.D,
			sysx_hdr.."2B 03 00 "..color.blue.D,
			sysx_hdr.."2B 04 01 "..color.blue.B,
			sysx_hdr.."2B 05 00 "..color.red.D..on..sysx_trm,
			sysx_hdr.."2B 06 00 "..color.red.D..on..sysx_trm,
			sysx_hdr.."2B 07 00 "..color.red.D..on..sysx_trm,
		},
	},
	
}

--[[-------------]]
--[[  Functions  ]]
--[[-------------]]

function remote_init()

    local controls=
    {   
        --[[ 
          || Buttons in this section are arranged such that moving clockwise around the outside of the keyboard will 
          || give you the following descending sequence of controls. 
          ]]      

    --[[01  
      ]]{name="up",       input="button"}, 
        {name="down",     input="button"}, 
        {name="left",     input="button"}, 
        {name="right",    input="button"}, 
        {name="session",  input="button"}, 
        {name="note",     input="button"}, 
        {name="device",   input="button"}, 
        {name="user",     input="button"}, 
    --[[09
      ]]{name="group1",   input="button"}, 
        {name="group2",   input="button"}, 
        {name="group3",   input="button"}, 
        {name="group4",   input="button"}, 
        {name="group5",   input="button"}, 
        {name="group6",   input="button"}, 
        {name="group7",   input="button"}, 
        {name="group8",   input="button"}, 
    --[[17
      ]]{name="stop",     input="button"}, 
        {name="send",     input="button"}, 
        {name="pan",      input="button"}, 
        {name="vol",      input="button"}, 
        {name="solo",     input="button"}, 
        {name="mute",     input="button"}, 
        {name="trk_sel",  input="button"}, 
        {name="rec_arm",  input="button"},
    --[[25
      ]]{name="rec",      input="button"}, 
        {name="dbl",      input="button"}, 
        {name="dupe",     input="button"}, 
        {name="quant",    input="button"}, 
        {name="del",      input="button"}, 
        {name="undo",     input="button"}, 
        {name="click",    input="button"}, 
        {name="shift",    input="button"},
        
        --[[ 
            The entire pad grid is mapped to 64 separate buttons with names that correspond to their relative X,Y coordinates. 
            Since the keyboard keys can also register as control buttons, they are mapped. 
            To ease confusion, the button naming standard begins from 1,1 instead of 0,0. 
          ]]
 
    --[[33
      ]]{name="p11",      input="button", output="value"}, 
        {name="p21",      input="button", output="value"}, 
        {name="p31",      input="button", output="value"}, 
        {name="p41",      input="button", output="value"}, 
        {name="p51",      input="button", output="value"},
        {name="p61",      input="button", output="value"},
        {name="p71",      input="button", output="value"}, 
        {name="p81",      input="button", output="value"}, 
    --[[41
      ]]{name="p12",      input="button", output="value"}, 
        {name="p22",      input="button", output="value"}, 
        {name="p32",      input="button", output="value"}, 
        {name="p42",      input="button", output="value"}, 
        {name="p52",      input="button", output="value"}, 
        {name="p62",      input="button", output="value"}, 
        {name="p72",      input="button", output="value"}, 
        {name="p82",      input="button", output="value"}, 
    --[[49
      ]]{name="p13",      input="button", output="value"}, 
        {name="p23",      input="button", output="value"}, 
        {name="p33",      input="button", output="value"}, 
        {name="p43",      input="button", output="value"}, 
        {name="p53",      input="button", output="value"}, 
        {name="p63",      input="button", output="value"}, 
        {name="p73",      input="button", output="value"}, 
        {name="p83",      input="button", output="value"}, 
    --[[57
      ]]{name="p14",      input="button", output="value"}, 
        {name="p24",      input="button", output="value"}, 
        {name="p34",      input="button", output="value"}, 
        {name="p44",      input="button", output="value"}, 
        {name="p54",      input="button", output="value"}, 
        {name="p64",      input="button", output="value"}, 
        {name="p74",      input="button", output="value"}, 
        {name="p84",      input="button", output="value"}, 
    --[[65
      ]]{name="p15",      input="button", output="value"}, 
        {name="p25",      input="button", output="value"}, 
        {name="p35",      input="button", output="value"}, 
        {name="p45",      input="button", output="value"}, 
        {name="p55",      input="button", output="value"}, 
        {name="p65",      input="button", output="value"}, 
        {name="p75",      input="button", output="value"}, 
        {name="p85",      input="button", output="value"}, 
    --[[73
      ]]{name="p16",      input="button", output="value"}, 
        {name="p26",      input="button", output="value"}, 
        {name="p36",      input="button", output="value"}, 
        {name="p46",      input="button", output="value"}, 
        {name="p56",      input="button", output="value"}, 
        {name="p66",      input="button", output="value"}, 
        {name="p76",      input="button", output="value"}, 
        {name="p86",      input="button", output="value"}, 
    --[[81
      ]]{name="p17",      input="button", output="value"}, 
        {name="p27",      input="button", output="value"}, 
        {name="p37",      input="button", output="value"}, 
        {name="p47",      input="button", output="value"}, 
        {name="p57",      input="button", output="value"}, 
        {name="p67",      input="button", output="value"}, 
        {name="p77",      input="button", output="value"}, 
        {name="p87",      input="button", output="value"}, 
    --[[89
      ]]{name="p18",      input="button", output="value"}, 
        {name="p28",      input="button", output="value"}, 
        {name="p38",      input="button", output="value"}, 
        {name="p48",      input="button", output="value"}, 
        {name="p58",      input="button", output="value"}, 
        {name="p68",      input="button", output="value"},
        {name="p78",      input="button", output="value"},
        {name="p88",      input="button", output="value"},
		
	--[[97
	  ]]{name="kboard",   input="keyboard"},	
	  
	--[[98
	  ]]{name="device_name",       output="text"},  	
	  
 	    --[[ 
            This set of definitions uses the 'fader' mode on the device.
            This allows you to have 8 surrogate faders mapped to the 64 pads in the center of the device.
			The fader mode appears to be hard-coded into the device's firmware, as all 64 pads
			only register to 8 midi buttons not used in any other mode.
			They are defined below from the left of the device to the right
          ]] 
    --[[99
      ]]{name="fdr01",      input="value", output="value", min=0 , max=127},
        {name="fdr02",      input="value", output="value", min=0 , max=127},
        {name="fdr03",      input="value", output="value", min=0 , max=127},
        {name="fdr04",      input="value", output="value", min=0 , max=127},
        {name="fdr05",      input="value", output="value", min=0 , max=127},
        {name="fdr06",      input="value", output="value", min=0 , max=127},
        {name="fdr07",      input="value", output="value", min=0 , max=127},
        {name="fdr08",      input="value", output="value", min=0 , max=127},
		
	--[[107	
      ]]{name="fdr09",      input="value", output="value", min=0 , max=127},
        {name="fdr10",      input="value", output="value", min=0 , max=127},
        {name="fdr11",      input="value", output="value", min=0 , max=127},
        {name="fdr12",      input="value", output="value", min=0 , max=127},
        {name="fdr13",      input="value", output="value", min=0 , max=127},
        {name="fdr14",      input="value", output="value", min=0 , max=127},
        {name="fdr15",      input="value", output="value", min=0 , max=127},
        {name="fdr16",      input="value", output="value", min=0 , max=127},
		
	--[[115	
      ]]{name="fdr17",      input="value", output="value", min=0 , max=127},
        {name="fdr18",      input="value", output="value", min=0 , max=127},
        {name="fdr19",      input="value", output="value", min=0 , max=127},
        {name="fdr20",      input="value", output="value", min=0 , max=127},
        {name="fdr21",      input="value", output="value", min=0 , max=127},
        {name="fdr22",      input="value", output="value", min=0 , max=127},
        {name="fdr23",      input="value", output="value", min=0 , max=127},
        {name="fdr24",      input="value", output="value", min=0 , max=127},
		
	--[[123	
      ]]{name="fdr25",      input="value", output="value", min=0 , max=127},
        {name="fdr26",      input="value", output="value", min=0 , max=127},
        {name="fdr27",      input="value", output="value", min=0 , max=127},
        {name="fdr28",      input="value", output="value", min=0 , max=127},
        {name="fdr29",      input="value", output="value", min=0 , max=127},
        {name="fdr30",      input="value", output="value", min=0 , max=127},
        {name="fdr31",      input="value", output="value", min=0 , max=127},
        {name="fdr32",      input="value", output="value", min=0 , max=127},
		
	--[[131
	  ]]{name="sub_enc_pitch",         input="delta", output="value", min=0  , max=24},
	    {name="sub_enc_poly",          input="delta", output="value", min=1  , max=99},
		{name="sub_enc_wave_1",        input="delta", output="value", min=0  , max=31},
	    {name="sub_enc_oct_1",         input="delta", output="value", min=0  , max=9 },
		{name="sub_enc_semi_1",        input="delta", output="value", min=0  , max=12},
	    {name="sub_enc_cent_1",        input="delta", output="value", min=-50, max=50},	
		{name="sub_enc_wave_2",        input="delta", output="value", min=0  , max=31},
	    {name="sub_enc_oct_2",         input="delta", output="value", min=0  , max=9 },		
		{name="sub_enc_semi_2",        input="delta", output="value", min=0  , max=12},
	    {name="sub_enc_cent_2",        input="delta", output="value", min=-50, max=50},

    } 
    
--[[
	This btn_statement instantiates the controls in the table for IO.
  ]]
    remote.define_items(controls)

end

function to_hex(dec)

	local hex = string.format("%X", dec)
	if (string.len(hex) < 2) then
		hex = "0"..hex
	end
	
    return (hex)	
end

function math.mod(p1,p2)

	local out = p1-math.floor(p1/p2)*p2
	
	return (out)
end

function set_prog()

	local prog_midi = {}

	local v

	if (devc_name == "subtractor") then
	
		for i,x in pairs(pad_state.subtractor) do

			if (i < 41) then
			
				table.insert(prog_midi, remote.make_midi(x[1]))
				
			elseif (41 <= i and i <= 96) then
			
				v = remote.get_item_value(i)
				table.insert(prog_midi, remote.make_midi(x[v+1]))
				
			elseif (131 <= i and i <= 140) then
			
				table.insert(prog_midi, remote.make_midi(x[1]))
			
			end
		end
		
	else

		for i = 1,64 do
			table.insert(prog_midi, remote.make_midi(pad_state.toggle[i][1]))
		end
	
	end
	
	return (prog_midi)
	
end

function set_fade()

	local k
	local fade_midi = {}
	
	if (devc_name == "subtractor") then
		
		for i = 1,8 do

			if (current_group == 9) then
			
				k = to_hex(remote.get_item_value(98+i)).." "
				table.insert(fade_midi, remote.make_midi(fdr_state.subtractor.g1[i]..k..sysx_trm))
				
			elseif (current_group == 10) then
			
				if (i <= 5) then
					k = to_hex(remote.get_item_value(106+i)).." "
					table.insert(fade_midi, remote.make_midi(fdr_state.subtractor.g2[i]..k..sysx_trm))
				elseif (i > 5) then
					table.insert(fade_midi, remote.make_midi(fdr_state.subtractor.g2[i]))
				end
				
			elseif (current_group == 11) then
			
				if (i <= 5) then
					k = to_hex(remote.get_item_value(114+i)).." "
					table.insert(fade_midi, remote.make_midi(fdr_state.subtractor.g3[i]..k..sysx_trm))
				elseif (i > 5) then
					table.insert(fade_midi, remote.make_midi(fdr_state.subtractor.g3[i]))
				end
				
			end
		end
		
	else
		--[[ Before uncommenting, add default controls, otherwise an error will throw.
		for i = 1,8 do
			k = to_hex(remote.get_item_value(98+i)).." "
			table.insert(prep_fade, remote.make_midi(fdr_state.default[i]..k..sysx_trm))
		end
		]]
	end	
	
	return (fade_midi)
	
end

function devc_switch()
	--[[ This function controls a display that mirrors which device is the active one in Reason.
		 
		 Each device layout (subtractor, malstrom, etc) is set using a 
		 table with each pad referenced.
	  ]]
	  
	local switch_midi = {}
	
	if (current_mode == sys_msg.auto_prog) then
	
		switch_midi = set_prog()
		
		
	elseif (current_mode == sys_msg.auto_fade) then
	
		switch_midi = set_fade()
		
	end

	return (switch_midi)
	
end

function mode_switch(midi)
--[[ This function, depending on the incoming midi message, will switch modes on the Launchpad.
	 
	 When a layout change request is received while a fader is still moving, the Launchpad stops the
     fader movement and selects the new layout.
  ]]
	local switch_midi = {}
	
	if (midi == btn_state[5][4] and current_mode ~= sys_msg.auto_drum) then
	
		current_mode = sys_msg.auto_drum
		table.insert(switch_midi, set_mode.drum)
	 
	elseif (midi == btn_state[6][4] and current_mode ~= sys_msg.auto_note) then
	
		current_mode = sys_msg.auto_note
		table.insert(switch_midi, set_mode.note)
	
	elseif (midi == btn_state[7][4] and current_mode ~= sys_msg.auto_prog) then
	
		current_mode = sys_msg.auto_prog
		table.insert(switch_midi, set_mode.prog)
		table.insert(switch_midi, remote.make_midi(sys_msg.side_ledc))	
		
		
	elseif (midi == btn_state[8][4] and current_mode ~= sys_msg.auto_fade) then
	
		current_mode = sys_msg.auto_fade
		table.insert(switch_midi, set_mode.fade)	
		
	end
	
	if (current_mode == sys_msg.auto_prog) then
	
		local get_midi = set_prog()
		for i = 1,table.getn(get_midi) do
			table.insert(switch_midi, get_midi[i])
		end
			
	elseif (current_mode == sys_msg.auto_fade) then
		--[[ Set the fader colors to match the currently selected device, even if switched away from the mode
			 and the group changes.
	      ]]
		local get_midi = set_fade()
		for i = 1,table.getn(get_midi) do
			table.insert(switch_midi, get_midi[i])
		end
		
	end
	
	--[[ Set all modes except for the current one to the default color,
	     then set the current mode light. 
	  ]]
	for i = 9,16 do
		if (btn_state[i][2] ~= btn_state[current_group][2]) then
			table.insert(switch_midi, remote.make_midi(btn_state[i][1]))
		end
	end
	table.insert(switch_midi, remote.make_midi(btn_state[current_group][2]))
	
	if (table.getn(switch_midi) > 0) then
		return (switch_midi)
	end
	
end

function group_select(midi)

	local group_midi = {}
	--[[ A simple function that takes input from the group buttons and sets the current group. 
	     This function also sets 'last_group' to control the lights turning off]]

	for i = 9,16 do
		if (midi == btn_state[i][4]) then
			last_group = current_group
			current_group = i
		end
	end

	if (current_mode == sys_msg.auto_fade) then
		local get_midi = set_fade()
		for i = 1,table.getn(get_midi) do
			table.insert(group_midi, get_midi[i])
		end
	end		
			
	return (group_midi)
	
end

function tblprint (tbl, indent)
	local output = ''
	if not indent then indent = 0 end
	if type(tbl) == "table" then
		 for k, v in pairs(tbl) do
			formatting = string.rep("  ", indent) .. k .. ": "
			if type(v) == "table" then
				output = output..'\n'..formatting ..'\n'..
				tblprint(v, indent+1)
			elseif type(v) == 'boolean' then
				output=output..formatting .. tostring(v)		
			else
				output=output..formatting .. tostring(v) ..'\n'
			end
		 end

	end	
	return output
end

function remote_process_midi(event)
--[[ It appears the ONLY reason we have this handle_input code is to let 
	 the application know the input was handled. Special cases can exist
	 across modes, i.e. having the keyboard separate from the pads
			  
	 Additional functions will use "out_midi", set by the 'if' statements.
	 That will contain the most recent midi function
  ]]
	
	local l_note = event[2] --[[Gets the note from the 'event']]
	local l_vel  = event[3] --[[Gets the velocity from the 'event']]
	local action
	local idx = nil
	
	--[[ Validate input from they keyboard in certain modes only
	      We have 90 yy 00 first sinze zz could mean any number. We only want 00 to mean off. 
	  ]]
	if (current_mode == sys_msg.auto_note or
		current_mode == sys_msg.auto_drum) then
		if (remote.match_midi("9? yy 00", event) ~= nil) then

			--[[ Set the message handler for Reason, including which note (velocity not important on release)]]
			msg = {item = 97, value = 0, note = l_note, time_stamp = event.time_stamp}
			remote.handle_input(msg)
			return (true)

		elseif (remote.match_midi("9? yy zz", event) ~= nil)  then

			--[[ Set the message handler for Reason, including which note and at what velocity ]]
			msg = {item = 97, value = 1, note = l_note, velocity = l_vel, time_stamp = event.time_stamp}
			remote.handle_input(msg)
			return (true)
		end
	
	elseif (current_mode == sys_msg.auto_prog) then
	
		for i = 1,64 do --[[ Loop 64 times for 64 pads, but break when i is found ]]
			if ((remote.match_midi(pad_state.toggle[i][2],event) ~= nil)) then
				idx = i
				action = "press"
				break
			elseif ((remote.match_midi(pad_state.toggle[i][1],event) ~= nil)) then
				idx = i
				action = "release"
				break
			end
		end
		
		if (idx ~= nil and action == "press") then 

		--[[ If any pad is pressed in programmer mode ]]
			
			out_midi = pad_state.toggle[idx][2]
			
			--[[ Validation by Device ]]	
			
			--[[ Subtractor ]]
			if (devc_name == "subtractor") then
			
				if (devc_actions.subtractor[idx] ~= nil) then
				
					remote.handle_input(devc_actions.subtractor[idx])
					return (true)
			
				else --[[ Handle the rest of the pads automatically.]]

					msg = {item = 32+idx, value = 1, time_stamp = event.timestamp}
					
					--[[This is where the magic happens, and by magic, i mean infinite death. ]]
					remote.handle_input(msg)

					return (true)
					
				end
				
			else --[[ Validate input from any pad if no other specific case match ]]
				
				msg = {item = 32+idx, value = 1, time_stamp = event.timestamp}
				remote.handle_input(msg)
				return (true)
	
			end
				
		elseif (idx ~= nil and action == "release") then --[[ If any pad is released ]]
			
			out_midi = pad_state.toggle[idx][1]
			msg = {item = 32+idx, value = 0, time_stamp = event.timestamp}
			remote.handle_input(msg)
			return (true)

		end
		
	elseif (current_mode == sys_msg.auto_fade) then
		
		--[[ Validate input from any fader, depending on the group]]	
		for i = 1,8 do
		
			if (remote.match_midi(fdr[i].."??",event) ~= nil) then
				if (current_group == 9) then
					msg = {item = 98+i, value = tonumber(event[3]), time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
				elseif (current_group == 10) then
					msg = {item = 106+i, value = tonumber(event[3]), time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
				elseif (current_group == 11) then
					msg = {item = 114+i, value = tonumber(event[3]), time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
					
				elseif (current_group == 12) then
					msg = {item = 122+i, value = tonumber(event[3]), time_stamp = event.time_stamp}
					remote.handle_input(msg)
					return (true)
				end
			end	
		end	
	end
	
	--[[ Validate input from any button in any mode]]
	if (remote.match_midi("B? yy zz", event) ~= nil) then
		
		for i = 1,32 do
			if (remote.match_midi(btn_state[i][4],event) ~= nil) then
				action = "press"
				idx = i
				break
			elseif (remote.match_midi(btn_state[i][3],event) ~= nil) then
				action = "release"
				idx = i
				break
			end
		end	
	
		if (idx ~= nil and action == "press") then
		
			out_midi = btn_state[idx][4]
			msg = {item = idx, value = 1, time_stamp = event.time_stamp}
			remote.handle_input(msg)
			return (true)
		
		elseif (idx ~= nil and action == "release") then
		
			out_midi = btn_state[idx][3]
			msg = {item = idx, value = 0, time_stamp = event.time_stamp}
			remote.handle_input(msg)
			return (true)
		end
		
	end

	
	--[[ Clear out_midi so that it isn't accidentally used elsewhere.
	     In other words, out_midi is only set when used in RDM
	  ]]
	out_midi = nil

	return (false)
	
end

function remote_set_state(ci)
	
	local get_midi = {}

	--[[count = count + 1
	table.insert(errors, ci)
	
	if count == 100 then error(tblprint(errors, 3)) end]]

	if (table.getn(ci) ~= 0) then
		
		for i,index in ipairs(ci) do	
			
			if (index == 98 and remote.get_item_text_value(index) ~= devc_name) then --[[ If the device changed ]]
				last_devc_name = devc_name
				devc_name = remote.get_item_text_value(index)
				devc_switch()
			end
			
		end	
	
		if (current_mode == sys_msg.auto_prog) then
			for i,index in ipairs(ci) do
			
				if (devc_name == "subtractor") then
					if ((41 <= index and index <= 96) and remote.is_item_enabled(index) == true) then --[[ If the pad/button changed ]]
						local k = index
						local v = remote.get_item_value(index)
						table.insert(state_midi, remote.make_midi(pad_state.subtractor[k][v+1]))

					elseif ((131 <= index and index <= 140) and remote.is_item_enabled(index) == true) then --[[ If the encoders changed ]]
						local d = index
						local u = index+7000
						table.insert(state_midi, remote.make_midi(pad_state.subtractor[d][1]))
						table.insert(state_midi, remote.make_midi(pad_state.subtractor[u][1]))
					end
					
				else
				end
				
			end
		
		elseif (current_mode == sys_msg.auto_fade) then	
		
			for i,index in ipairs(ci) do
			
				local k
				local v
			
			    if (99 <= index and index <= 130) then
				
					k = math.mod(index-99,8)+1 --[[ 1 - 8 from any group based on the index ]]
					v = remote.get_item_value(index)
					
				end
				
				if ((99 <= index and index <= 106)
				 and current_group == 9
     			 and remote.is_item_enabled(index) == true) then
				 
					table.insert(state_midi, remote.make_midi(fdr[k]..to_hex(v)))
					
				elseif ((107 <= index and index <= 114)
				 and current_group == 10
     			 and remote.is_item_enabled(index) == true) then
				 
					table.insert(state_midi, remote.make_midi(fdr[k]..to_hex(v)))
					
				elseif ((115 <= index and index <= 122)
				 and current_group == 11
     			 and remote.is_item_enabled(index) == true) then
				 
					table.insert(state_midi, remote.make_midi(fdr[k]..to_hex(v)))
					
				elseif ((123 <= index and index <= 130)
				 and current_group == 12
     			 and remote.is_item_enabled(index) == true) then
				 
					table.insert(state_midi, remote.make_midi(fdr[k]..to_hex(v)))
					
				end
			end
			
		end
		
	end
end

function remote_deliver_midi()
--[[ remote_deliver_midi, or RDM, delivers messages to the surface.
     RDM returns a table of events which get interpreted by the Launchpad Pro as displays.
	 
	 There's a distinction that must be recognized here:
		The surface will ALWAYS send data to Reason when you push something on it.
		How this is interpreted is up to the mapping file. When you set up inputs with masks,
		you determine which input goes to which Reason device's knob/button/fader/etc.
	    RDM is ONLY for setting the surface. 
  ]]
	local events = {}
	local action
	local idx
	
	--[[Don't process anything if out_midi is nil.]]
	if (out_midi ~= nil) then
	

		--[[ Button logic ]]
		if (string.match(out_midi, "B.*") ~= nil) then
		
			for i = 1,32 do
				if (out_midi == btn_state[i][4]) then
					action = "press"
					idx = i
					break
				elseif (out_midi == btn_state[i][3]) then
					action = "release"
					idx = i
					break
				end
			end	
			
			if (action == "press" and hold ~= true) then --[[ If any button is pressed ]]
				
				hold = true
							
				--[[ If the button is one of the designated mode switching buttons,
					 execute the function to return midi to switch the mode ]]
				if 
				 (  out_midi==btn_state[05][4] 
				 or out_midi==btn_state[06][4]
				 or out_midi==btn_state[07][4]
				 or out_midi==btn_state[08][4]) then
					
					events = mode_switch(out_midi)
					table.insert(events, remote.make_midi(btn_state[idx][2]))
				
				--[[ If a group button is pressed to change the current group,
					 execute the function to switch groups, then set the lights
				  ]]
				elseif 
				 (( out_midi==btn_state[09][4]
				 or out_midi==btn_state[10][4]
				 or out_midi==btn_state[11][4]
				 or out_midi==btn_state[12][4]
				 or out_midi==btn_state[13][4]
				 or out_midi==btn_state[14][4]
				 or out_midi==btn_state[15][4]
				 or out_midi==btn_state[16][4])) then
					
					
					events = group_select(out_midi)
					table.insert(events, remote.make_midi(btn_state[current_group][2]))

				end

			elseif (action == "release" and hold ~= false) then --[[ If a button is released ]]
			
				hold = false
				if (out_midi == btn_state[current_group][3]) then
				
					if (current_group ~= last_group) then
						table.insert(events, remote.make_midi(btn_state[last_group][1]))
					end
					
				end
			end	
			
		end
		
	end
	
	if (table.getn(state_midi) ~= 0) then
		
		prev_state_midi = state_midi
		for i = 1,table.getn(state_midi) do
			table.insert(events, state_midi[i])
		end
		midi_from_state = true
		state_midi = {}
		
	end
	--[[
	count = count + 1
	table.insert(errors, events)
	if count == 20 then error(tblprint(errors, 3)) end
	]]
	out_midi = nil
	
	return (events)
	
end


function remote_prepare_for_use()

    --[[ Initialize the control surface for use by
         setting the color (and type in some instances) of controls in all modes
      
	     To reduce clutter, we build a new table and append here on each mode. 
		 each table.insert statement puts a "remote.make_midi" in the table "prepare".
	  ]]
	local prepare = {}
	
	table.insert(prepare, set_mode.sysx)	
	--[[ Setting note mode button colors is currently unsupported by Novation :(  ]]
	
	table.insert(prepare, set_mode.note)
		for i = 1,32 do
			if (btn_state[i] ~= (
			                     btn_state[01] or
								 btn_state[02] or
								 btn_state[03] or
								 btn_state[04] or
								 btn_state[06] or
								 btn_state[32]
								))
			then
				table.insert(prepare, remote.make_midi(btn_state[i][1]))
			end
		end	
	  	
	--[[ Set mode to drum and skip the directional buttons. Then loop through btn_state
         and set the color for each button]]
	table.insert(prepare, set_mode.drum)
		for i = 1,32 do
			if (btn_state[i] ~= (
								 btn_state[1] or
								 btn_state[2] or
								 btn_state[3] or
								 btn_state[4]
								))
			then					   
				table.insert(prepare, remote.make_midi(btn_state[i][1]))
			end
		end	
		
	--[[ Set mode to fade, set 4 faders and 4 pans, then set the outer buttons. ]]
	table.insert(prepare, set_mode.fade)
		for i = 1,8 do
			table.insert(prepare, remote.make_midi(fdr_state.default[i].."00 F7"))
			table.insert(prepare, remote.make_midi(btn_state[i][1]))
		end
		for i = 9,32 do
			table.insert(prepare, remote.make_midi(btn_state[i][1]))
		end
		
	--[[ The simplest layout, set the outer buttons. The good news is that they all send
         the same signal regardless of which screen you're on. 
	  ]]	
	table.insert(prepare, set_mode.prog)
		for i = 1,32 do 
			table.insert(prepare, remote.make_midi(btn_state[i][1]))
			table.insert(prepare, remote.make_midi(pad_state.toggle[i][1]))
		end
			table.insert(prepare, remote.make_midi(btn_state[7][2]))
			
		for i = 33,64 do
		
			table.insert(prepare, remote.make_midi(pad_state.toggle[i][1]))

		end
		
		table.insert(prepare, remote.make_midi(btn_state[9][2]))
	
	--[[ Set the current mode to programmer. 
	     This should always be changed when switching modes.
	  ]]
	current_mode = sys_msg.auto_prog
	
	table.insert(prepare, remote.make_midi(sys_msg.side_ledc))
	
    return (prepare)

end

function remote_release_from_use()
	
    --[[ Release control of the surface and 'zero out' color. ]]
	--[[ To reduce clutter, we build a new table and append here on each mode. ]]
	
	local release = {}
	
	--[[ Setting note mode button colors is currently unsupported by Novation ]]
	table.insert(release, set_mode.note)
		for i in btn_state do
			if (btn_state[i] ~= (
			                     btn_state[01] or
						         btn_state[02] or
						         btn_state[03] or
						         btn_state[04] or
						         btn_state[06] or
						         btn_state[32]
						        ))
			then
				table.insert(release, remote.make_midi(btn_state[i][3]))
			end
		end
		
	--[[ Release drum mode ]]
	table.insert(release, set_mode.drum)
		for i in btn_state do
			if (btn_state[i] ~= (
						         btn_state[1] or
						         btn_state[2] or
						         btn_state[3] or
						         btn_state[4] 
						        ))
			then
				table.insert(release, remote.make_midi(btn_state[i][3]))
			end
		end
		
	--[[ Release fader mode ]]
	table.insert(release, set_mode.fade)
		for i = 1,32 do
			table.insert(release, remote.make_midi(btn_state[i][3]))
		end
		
		for i = 1,8 do
			table.insert(release, remote.make_midi(fdr_state[i]))
		end
		
	--[[ Release programmer mode ]]
	table.insert(release, set_mode.prog)
		for i = 1,32 do
			table.insert(release, remote.make_midi(btn_state[i][3]))
		end
		
		for i = 1,64 do
			table.insert(release, remote.make_midi(pad_state.toggle[i][1]))
		end
	
	--[[ Might be specific to my device, but sometimes this pad is stuck on the lit position after close 
	table.insert(release, remote.make_midi(pad.p57..off)) ]]
	
	--[[ Return release table ]]
    return(release)
	  
end



--[[ Notes
		
	TODO:
		
		Add an else catch-all in remote_deliver_midi so that other buttons at least light up when pressed.
			The issue with this right now lies with the group buttons. we don't want those turning off.
		
		Done: Get group functionality working (according to group, use different input items)
		`````
		Done: Use get_item_state to determine whether or not a certain device is selected, instead of the arrow keys.
		`````
		Consider adding a default layout that covers some of Reason's main controls.

		Add more Devices.
		
  ]]