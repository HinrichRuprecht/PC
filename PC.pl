#!/usr/bin/perl -w
#.=	Playing cards server program (includes client connector)
#
#	Usage/call:
#	   via http : ?PAR=VAL&... (for parameters see below)
#		a) with 'mode=C' : client connector, send parameters to server
#		b) server mode : handles one request and exits
#	   start from command line with 'mode=S': 
#		server handles all requests using socket
#		with client connector
#
# 	'-w' and 'use warnings;' produce warnings like 
#	    'Variable ... will not be shared at' : 
#		upper level variables used within sub
#	     and 'Subroutine ... redefined at' :
#	   	relate to the reuse of server processes for subsequent calls.
#
use warnings;
#  Perl Skript © 2020-2021 H. Ruprecht : usable according to GNU public license

use strict;
# ?? avoid 'Variable "%status" will not stay shared at' 
#	and 'Subroutine checkTrick redefined at '
    # use warnings;

use File::Copy;
use URI::Escape;
use IO::Select;
#use Fcntl;

use FindBin;               # locate this script
use lib "$FindBin::Bin/";  # and use its directory as source of packages

use PC;

#?? use IO::Handle;
#?? $TABLE->flush();
my    $LOCK_UN=8; #   => 8,

my (%tables);

my ($parMode,%query) = PC::getQuery();

print STDOUT "Content-Type: text/html; charset=utf-8\n\n";

my $progDir="$FindBin::Bin";

my $port=5000+($0=~/(\d)\/PC.*$/ || $progDir=~/(\d)$/ ? $1 : 0);
print STDERR "* $progDir $0\n";
print STDERR "* Using port $port\n" if $port!=5000;

my ($input, $selR); # for sockets
my $mode=$query{'mode'} || $parMode;
my $test = $query{'test'} || 0;
$|=1 if $test;
my $logOpt=1 if $test>3;
 #   $selW = IO::Select->new; # only for write 
if ($mode eq "S") { # server with socket
    die "* start via command line\n" if $parMode eq "Q" && $test==0;
    # !!! OR check credentials : connection must be kept open (how???) !!!
    print PC::timeStr(1),"* get new socket $port " if $test;
    $input=PC::newSocket('localhost',$port,1); # ,1 : new socket
    $selR = IO::Select->new; # only for read 
    $selR->add($input);
    print PC::timeStr(1)," done\n" if $test;
    }
elsif ($mode eq "C") { # client connector using socket
    my $line=""; my $n=0; my $undef="";
    foreach (keys %query) {
	my $k=$_; my $v=$query{$k}; 
	if (!defined($v)) { $v=""; $undef.=" ".$k; }
	$line.="$k=".$v."\t" if $k ne 'mode';
	}
    my $ipAddr=$ENV{'REMOTE_ADDR'}; # server can only get connector ip addr
    $line.="REMADDR=".$ipAddr if $ipAddr;
    print STDERR "**C->S: ",$line," undef=",$undef,".\n" if $test>0;
    my $socket=PC::newSocket('localhost',$port); # connect to existing socket
    if ($socket) {
	print $socket $line,"\n";
	while (<$socket>) { print STDOUT $_; $n++; }
	print STDERR PC::timeStr(1),"**S->C $n lines out (",$line,")\n" 
	    if $test>0;
	$socket->close();
	exit;
	}
    # socket creation failed: switch to file mode
    $mode="F";
    print STDOUT "mode=F\n";
    }
#print STDOUT "Content-Type: text/html; charset=utf-8\n*\n";

my $TS=1; # send all info (w/o hand of others) when called with T=0
my $sep = $query{'sep'} || "\n";

my $sleepSecs=1; my $maxSleep=300;
my $out=\*STDOUT;

my $category = $query{"C"} || ""; 
if ($category eq "close") {
	# http://...?P=TABLE-USER&I=PASS&C=close[&SP=n]
    my $playerId = $query{"P"} || "-"; # 1st call: <table>-<player name> 
    my ($tableName, $player) = split("-",$playerId);
    my $table=PC::setupTable("PC",$tableName,$mode);
    exit unless $table;
    my $tableFile=$table->{"TABLEFILE.."};
    my $cardId = $query{"I"} || "";
    my $fhTableFile=PC::createTableFile
		($tableFile,$playerId,$cardId,$test); 
    close($fhTableFile) if $fhTableFile;
    exit if $mode ne "S";
    $query{"I"}=""; $query{"P"}="";
    }

my $tables=PC::tables("PC");
$tables->{":test"}=$test; # 'global' test option
#if ($query{'P'}) { 
#    PC::setupPlayer( $tables,\%query,$out); # open 1st table
#    my $category=$query{'C'} || "";
#    exit if $category eq "close";
#    }

my ($client_socket) ; # file handles : 65outside main loop !
my ($myP, $player, $tmp); # ??? in $status ???

my $nRuns=0; my $table; my $nTS;

while (1) { # server with sockets : loop, exit for mode!=S by 'last' at end
    # while ($query{'mode'} eq "S" || $nRuns==0) or do [[ }} while did not work
    # main loop do {{ }} while :{} around the do-while loop enable last and next

    my $changed=0;
    $nRuns++; 
    if ($mode eq "S") { 
	print PC::timeStr(1)."**Start #$nRuns:\n" if $test;
	my @ready = $selR->can_read(); # result can only be $input file handle
	$client_socket = $input->accept(); # 
	$out=$client_socket;
	# !!! add to table !!!
	($parMode,%query) = PC::getQuery( $client_socket); 
	}
    
    if ($test) { 
	print STDOUT PC::timeStr(1),"* new request ($mode/$parMode) <br>\n"; 
	foreach my $k (keys %query) 
	    { print STDOUT "*$k=",($query{$k} || 'undef')," \n"; } 
	}
    
    my $lastRead = $query{"FS"} || "";
    my $lastnTS;
    ($lastRead,$lastnTS)=split(":",$lastRead);
    $lastnTS=0 unless $lastnTS;
    $lastRead=0 unless $lastRead;
    my $playerId = $query{"P"} || "-"; # 1st call: <table>-<player name> 
	# (join table), further calls: <table>-<Id>
    my $regexIds='(\w+)(\-.*)$';	# '([A-Z][a-z]+)([A-Z]\w*)(\-.*)$';
    
    if ($playerId!~/$regexIds/) {
	print $out "ERR=[Spieler nicht verifiziert ($playerId)]\n"; 
	if ($mode ne "S") { exit; }
	else { $client_socket->close(); next; }
	}
    my ($tableName, $player) = split("-",$playerId);
    $table=$tables->{$tableName}; # $tables{$tableName};
    if (!$table && $mode eq "S") { # ignore upper/lowercase
	foreach my $t (keys %tables) {
	    if ($t=~/^$tableName$/i) { $table=$tables->{$t}; last; }
	    }
	}
    if (!$table) { # only with mode=F or newly opened table
	$table=PC::setupTable("PC",$tableName,$mode);
	if (!$table) {
	    print $out "ERR=[Spieltisch nicht verifiziert ($tableName)]\n"; 
	    if ($mode ne "S") { exit; } 
	    else { $client_socket->close(); next; }
	    }
	$tableName=$table->{name};
	$tables->{$tableName}=$table;
	if ($test) {
	    my $log;
	    if ($test>1) {
		my $game=$table->{game};
		if (!$game || !$table->{'MAINDIR.X'}) {
		    my $tmp=$table->{'MAINDIR.X'} || "unknown";
		    print "** ?? g=$game main=",$tmp,"\n";
		    }
		else { open($log,">>".$table->{'MAINDIR.X'}.$game.".log")
			|| print "HINT=[logfile err ($game.log): $!]\n"; 
		    }
		}
	    $table->{test}=$query{"test"} || $tables->{":test"};
	    $table->{mode}=$mode;
	    $log=\*STDERR unless defined($log);
	    $table->{fhLog}=$log;
	    #$table->printOut("* new table $tableName\n");
	    $table->printLog("* new table $tableName\n",1);
	    $table->set('GAME',$table->get('game'));
	    #|| print STDERR timeStr(1)," error log: $!\n";
	    }
	$nTS=$table->readStatus($lastRead);
	$table->setConfig();
	}
    $table->set('GAME',$table->get('game'));
    my $tableFile=$table->{"TABLEFILE.."};
    $table->{fhOut}=$out;
    if ($mode ne "S" && PC::upToDate($table->{"SOURCEDIR.X"})==0) 
	{ $table->printOut("ERR=[not latest version]\n"); }

    $category = $query{"C"} || ""; 
	# The or (||) results in empty string if C=0 !
    #	= "S" : status, join table with name, if Id is undefined
    #	= "A" : make announcement 
    my $cardId = $query{"I"} || "";

    if (-s $tableFile!=$lastRead)
	{ $nTS=$table->readStatus($lastRead); }
#    my $nNew=scalar (keys %{$table->{newState}});
#    if ($nNew>0) { # $nTS>0 ??
#	$table->sendStatus($out,$table->{newState},"=",1); # to current player
#	$table->{newState}={}; 
#	}

   # my $specialGame=$query{"SP"} || 0; # @specialGame (below) to deal for testing
    #if ($test && ($test>1 || substr($cardId,0,1) ne "r")) {
	#my $tmp=""; 
	#foreach (sort keys %query) { $tmp.=$_."=".$query{$_}.";"; }
	#$table->printLog("#query:".$tmp." /FS=$lastRead\n",$logOpt);
	#}
    $table->{'test'}=$tables->{':test'} || $test; # 'global' test option

  if ($category eq 'N') { # join table (new player)
	my $language=$query{"LANG"} || "en"; 
	my $myP=$table->joinTable($player,$language,$out);
	if (!$myP) {
	    $table->printLog("*$player not joined\n");
	    if ($mode ne "S") { exit; }
	    else { $client_socket->close(); next; }
	    #return undef;
	    }
	elsif ($myP<0) { 
	    $myP=-$myP;
	    $table->newPlayer($myP,$player); 
	    $table->set("IPADDR..$player",$query{'REMADDR'} || "")
		unless $table->get("IPADDR..$player");
	    }
	my $playerName=$table->{"N$myP"} || $player;
	$player=$table->{"I.$myP"} || "";
	my $game=$table->{'game'} || "";
	my $tmp="myP=$myP\n:ID=$tableName-$player\nmyName=$playerName\n"
	    ."game=$game\n";
	$table->printLog($tmp);
	print $out $tmp;
	$changed=1;
	}
  else { 
	#$myP=$table->{"P..$player"}; }

    $myP=$table->{"P..$player"};
    if (!defined($myP)) {
	my $ipAddr=$query{'REMADDR'} || $ENV{'REMOTE_ADDR'} || "*noIP*";
	print "ERR=[$mode unknown]\n"; 
	print STDERR PC::timeStr(1),"*NoID($playerId/$ipAddr)/$mode\n" if !$myP;
	if ($table->{test}) {
	    $table->showAll();
	    }
	if ($mode ne "S") { exit; }
	else { $client_socket->close(); next; }
	}

    if ($mode ne "S") { $table->{selW}->add($out); }
    else { $table->{selW}->add($client_socket); }
    $table->{clientOut}->{$out}=$player;

    if (substr($cardId,0,2) eq "wc" && -s $tableFile==$lastRead) {
	$cardId="wc"; # parameter of wc only for testing
	# do not wait with $mode eq "S" (socket server)
	next if $mode eq "S";
	# wait for file size to grow beyond $lastRead
	my $secs=0; 
	while ($secs<$maxSleep && -s $tableFile==$lastRead) {
	    sleep($sleepSecs);
	    $secs+=$sleepSecs;
	    $table->printOut("*") if $test;
	    }
	if ($secs>0) { $table->printOut("\n") if $test; }
	else { $table->printOut("*nowait\n") if $test; }
	if ($secs>=$maxSleep) { $table->printLog("*$player: wait $secs\n"); }
	}

    $table->printLog("\n*rstatus(1st)\n",$logOpt) if $test>2;
    if (-s $tableFile<$lastRead) # after step back
	{ $lastRead=0; $lastnTS=0; }
    elsif ($mode eq "S") { seek($table->{fh},$lastRead,0); }
    else { $lastnTS=0; }
    my $nTS=$lastnTS+$table->readStatus($lastRead);

    my $NP=$table->{'NP'} || $table->{'NCP'} || 2;

    if ($test) { $table->printLog("*MSG: $category $cardId\n",$logOpt); }

    $table->printLog("*myP=$myP \n",$logOpt) if $test;
    #if ($myP eq "") { if ($mode eq "S") { next; } else { last; } }

#$tmp=scalar (keys %{$table->{newState}});
#if ($tmp>0) {
#    $table->printLog("send $tmp new states to ".$table->{"N$myP"}."\n",
#	$logOpt);
    # if ($category eq "S") { sendStatus($fhTableFile,\%newState); }
#    $table->sendStatus($out,$table->{newState},"=",$myP);
#    $tmp=$table->sendStatus($fhTableFile,\%{$table->{newState}},"\t"); # -3
#    if ($tmp>0) { 
#	$nTS++;
#	$table->printLog("save $tmp new states\n",$logOpt);
#	}
#    $table->{newState}=();
#    }

    $table->set("M.$myP","") if $cardId ne "wc"; # send message only once

    if ($cardId=~/^..[OP]/) { # cardID+1st character of id (clicked for partner?)
	my $cardId2=substr($cardId,2,1);
	$cardId=substr($cardId,0,2);
	my $P=$table->get('P') || "";
	$myP=$table->asPartner($myP,$cardId2,$1,$2) 
	    if $P && $P=~/^(.*)$myP(.*)$/; # Own or Partner
	}
    if ($category eq "P") { # play own card 
	$changed=$table->categoryP($cardId,$myP);
	}
    elsif ($category eq "S") { # server request
	if ($cardId=~/^Sc(.*)$/) { # 'Sc' : chat message or '> name=val' -> set
	    my $param=$1; 
	    if ($param=~/^\>\s*(\w[\w\d\-\_\.]*)\s*\:\s*(.*)$/ 
		&& $table->get("MASTER.X") eq $table->get("N$myP")) {
		my $name=$1; my $val=$2;
		if ($name=~/\.X$/)
		    { print $out "ERR=[.X nicht erlaubt!]\n"; }
		else {
		    $table->set($name,$val);
		    $table->set("##",$param);
		    if (defined($table->{config}->{$name})) {
			#$table->{config}->{$name}=$val;
			$table->setConfig();
			$table->{config}->{$name}=$val;
			}
		    }
		}
	    else {
		my $msg=$table->{"MSG"}."/[§$myP : $param]";
		$msg=substr($msg,1) if substr($msg,0,1) eq "/";
		$table->set("MSG",$msg);
		}
	    }
	else {
	    $changed=$table->serverReq($cardId, $myP);
	    }
	}
    elsif ($category eq "A") { # announcements
	if ($cardId ne "wc") { $changed=$table->categoryA($cardId, $myP); }
	}
    elsif ($category eq "M") { # 'master' intervention
	$changed=$table->categoryM($cardId, $myP);
	}
    }

my $nNew=scalar (keys %{$table->{newState}});
if ($nNew>0) { # $changed>=-1) {
    my $POS=$table->get('POS');
    $myP=$table->get("P..$player"); # might have changed by setRandomPos
    #$table->showLearner($out,$table->{"L.X"},$myP) if $table->{"L.X"};
    $table->printOut("HINT=[]\n");
#    if ($nNew>0) #  || $lastRead<=1) {
	$table->printLog("save $nNew new states (myP=$myP)\n",$logOpt);
	$nTS++ if $table->sendStatus($table->{fh},$table->{newState},"\t",2)>0; 
#	}
    $table->sendStatus($out,$table->{newState},"=",1); # to current player
    if ($myP>0) {
	}
    my @readyW; 
    if ($mode eq "S") { 
	@readyW=$table->{selW}->can_write(1); 
	$table->printLog("**writeQ=".scalar @readyW."\n",$logOpt) if $test;
	}
    else { @readyW=($out); }
    $table->printLog("**writeQ=".scalar @readyW." (m=$mode)\n",$logOpt) if $test;
    foreach my $fhOut (@readyW) {
	my $tmpPlayer=$table->{clientOut}->{$fhOut} || "XXX";
	my $nCP=$table->get("P..$tmpPlayer") || -1;
	if ($mode ne "S" || $fhOut->connected()) {
	    print $fhOut "TS=$TS\n"; # not in sendStatus for client
	    my $sendOpt=($nCP>=0 ? 200+$nCP : 2);
	    $table->sendStatus($fhOut,$table->{newState},"=",$sendOpt);  
	    #??catch { print STDERR "Fehler bei write $_ $!\n"; };
	    $table->sendOwn($nCP,$fhOut);
	    my $posFH=-s $tableFile; # tell($table->{fh}); # file size
	    print $fhOut "FS=$posFH:$nTS\n";
	    }
	else {
	  $table->printLog("** $fhOut ($nCP) is disconnected\n",$logOpt)
	    if $test;
	  }
	if ($mode eq "S") { $table->{selW}->remove($fhOut); $fhOut->close(); }
	}
    $client_socket->close() if $client_socket; 
    $table->{newState}={}; $table->{clientOut}={};
    }
elsif ($mode eq "S") {
    $table->{selW}->remove($client_socket); $client_socket->close(); 
    }
$table->printLog("$playerId : end$changed/new=$nNew ($myP) $category $cardId\n",
		$logOpt)
    if $table->{"TEST.X"} || $test;
last if $mode ne "S";
}
print "****\n";
flock($table->{fh},$LOCK_UN) if $table->{fh}; # close ?? close($table->{fh}); 
$table->printLog("*exit($mode,$nRuns) $0\n",$logOpt) if $table;
