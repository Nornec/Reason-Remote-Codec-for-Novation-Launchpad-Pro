--[[___________________________________________________________________________________________________
  || Novation Launchpad Pro -- Propellerhead "Remote" Codec                                          ||
  || Developed by -- James "Nornec" Ratliff                                                          ||
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
  |---------------------------------------------------------------------------------------------------|
  || To Install                                                                                      ||
  ||   Windows:                                                                                      ||
  ||   Merge the "Codecs" and "Maps" folders with the ones located in:                               ||
  ||   %appdata%\Roaming\Propellerhead Software\Remote\                                              ||
  ```````````````````````````````````````````````````````````````````````````````````````````````````]] 
