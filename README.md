# PC
Play card games (trick-taking games) via internet

Currently 3 games are implemented: Bridge, Doppelkopf, and OhHell.
See 'PChelp-<i>language</i>.html' for general usage information
(<i>language</i> = de|en).

An HTTP Server (e.g. Apache) is needed to run the program(s).
The html files and the image directories should be put in a sub-directory
of the server's directory used for html files, while the perl program 
('PC.pl') and the packages ('PC.pm', '<i>Game</i>.pm') must be put under the 
server's directory used for cgi-bin files, with the same sub-directory 
name.<br>
A configuration file for every game table has to be created in 
sub-directory 'restricted' below the sub-directory for the programs.
These files hold the current game status.<br>
File names are: 'restricted/<i>GameTablename</i>.cfg'<br>
The 'template.cfg' file should be used as an initial setup. <br>
After a game, the configuration file for the table can be reset to the 
initial state, with <br>
&nbsp;&nbsp;
'perl PC.pl P=<i>GameTablename-Mgr</i> I=<i>Mgrpassword</i> C=close'
or via internet with<br>
&nbsp;&nbsp;
'http://...?P=<i>GameTablename-Mgr</i>&I=<i>Mgrpassword</i>&C=close'
<br>
where <i>Mgrpassword</i> and <i>Mgr</i> are the password and the manager name 
as defined in the table-specific configuration file.<br>
It is not possible to create tables via internet. Access to the 
configuration files is restricted to users logged in to the server.
This should assure, that users can only play on pre-defined tables. 
<br>
See also the section about 'Background information' in 
'PChelp-<i>language</i>.html'.
