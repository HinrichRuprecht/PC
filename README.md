# PC
Play card games (trick-taking games) via internet

Currently 3 games are implemented: Bridge, Doppelkopf, and OhHell.

An (Apache) HTTP Server is needed to run the program(s).
The html files and the image directories should be put in a sub-directory
of the server's directory used for html files, while the perl program 
(PC.pl) and the packages (PC.pm, <game>.pm) must be put under the 
server's directory used for cgi-bin files, with the same sub-directory 
name.
A configuration file is for every game table has to be created in 
sub-directory restricted below the sub-directory for the programs.
These files hold the current game status.
File names are restricted/<game><tableName>.cfg
The template.cfg file should be used as an initial setup. After a game,
a table file can be reset to the initial state, using PC.pl.
