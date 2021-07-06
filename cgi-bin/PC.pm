use strict; 
use warnings;

my %games; 
$games{'Oh'}="OhHell"; $games{'Ts'}="OhHell";
$games{'Doko'}="Doppelkopf"; $games{'Dk'}="Doppelkopf";
$games{'Br'}="Bridge";

package PC;
# Subroutines for PC.pl
use URI::Escape qw( uri_unescape );
use File::Copy;
# variables used independent of table(s):
my $logOpt=0; my $test=5;
# use constant {
my    $LOCK_EX=2; #   => 2,
my    $LOCK_UN=8; #   => 8,
my    $LOCK_NB=4; #   => 4,
my    $SEEK_END=2; #  => 2,
#    };

sub tables {
    my $o   = shift;
    my $tables = {};
    bless($tables,$o);
    return($tables);

    } # tables

sub setupTable0 {
    my ($tableName)= @_;
    return PC->table($tableName);
    } # setupTable0

sub setupTable { # create new table
    my $o   = shift;
    my ($tableName, $mode)= @_; # ignore uppercase/lowercase if $mode=S

    my $status = {};
    my (%config, %new, %clientOut);
    $tableName="" unless defined($tableName);
    my $mainDir = "restricted/"; # 
    $mainDir="$FindBin::Bin/".$mainDir if -d "$FindBin::Bin/".$mainDir;
    $status->{'MAINDIR.X'}=$mainDir;
    my $tableFile=$mainDir.$tableName.".cfg";
    my $msg="";
    if (!-e $tableFile) {
	$msg="** $tableFile not found";
	if ($mode eq "S") {
	    my $tableName_=findTable($mainDir,$tableName);
	    if ($tableName_) {
		$msg=""; 
		$tableName=$tableName_; 
		print STDOUT "** Using table $tableName\n";
		$tableFile=$mainDir.$tableName_.".cfg";
		}
	    }
	}
    if ($msg eq "" && !-w $tableFile)
	{ $msg="** $tableFile not writable"; }
    if ($msg ne "") {
	$@=$msg;
	print STDOUT $msg,"\n";
	print STDERR $msg,"\n";
	return undef;
	}
    my $gamesExp=join("|",values %games)."|".join("|",keys %games);
    my $game;
    if ($tableName=~/^($gamesExp)([\w\d]+)$/) { $game=$1; }
    #if ($tableName=~/^([A-Z][a-z]+)([A-Z]\w*)$/) { $game=$1; }
    else {
	my $msg="** Table name '$tableName' does not conform to 'GameName'\n";
	print STDOUT $msg; print STDERR $msg;
	return undef;
	}
    $game=$games{$game} if $games{$game};
    if (!eval("require $game")) {
	print STDERR "*** 'require $game' failed\n";
	return undef;
	}
    $status={
	name  => $tableName,
	# GAME  => $game, # set later to send to clients
	game  => $game,
	config => \%config, 
	newState => \%new,	# keys show new or changed entries
	clientOut => \%clientOut, # file handles for clients: {fh}=player
    
    # other parts will be initialized later

    # Options: >=1:do ..., 0:don't
	test     => 0,	# print test/debug information (=1:all files,>1:dirs)
	verbose  => 0,	# print some information about returned files

    # Internals:
	mode  => '',	# (from $rOptions) : S:server, F:file
	fh    => undef, # file handle for tableFile
	fhOut => undef,	# file handle for out (stdout)
	fhLog => undef,	# file handle for logfile
	selW  => IO::Select->new, # write queue : waiting for change 
	};
    #my $pNameN=($0=~/\D(\d+)\.\w+$/ ? $1 : "");

    $status->{'TABLEFILE..'}=$tableFile;
    $status->{fh}=openStatus($tableFile);
    #setConfig(\%config,$game);
    
    bless($status,$o);
    return($status);
    } # setupTable

sub findTable {
    my ($dir, $table) = @_;
    
    my @files=glob($dir."*.cfg");
    my @tablesFound;
    foreach my $file (@files) {
	next unless $file=~/\/($table)\.cfg$/i;
	push(@tablesFound,$1);
	}
    if (scalar @tablesFound==1) { return $tablesFound[0]; }
    else {
	print STDERR "* $table found ",scalar @tablesFound," times\n";
	return "";
	}
    } # findTable

sub showAll {
    my $table=shift;
    foreach my $key (sort keys %{$table}) 
	{ print $key,"=",$table->{$key},"\n" if $table->{$key}; }
    } # showAll

sub gameSub { # call game specific subroutine
    my $table=shift;
    my ($subName,$param) = @_;
    $param="" unless defined($param);

    my $game=$table->get('GAME') || "";
    my $gameSubName=$game.'::'.$subName;
    #$table->printOut("*gameSub($subName,$param) g=$game");
    my $tmp=$table->get($gameSubName) || "";
    #print "*gameSub: $gameSubName ($tmp)\n";
    return undef if $tmp; # undefined subroutine
    $@=""; 
    my $res=eval("no strict 'refs'; use warnings; &$gameSubName(\$table,\$param)");
    #$@="" if $@=~/undefined subroutine/i;
    if ($@ ne "") {
	$table->printLog("ERR=[* $gameSubName : $@]\n");
	print STDERR "ERR=[* $gameSubName : $@]\n";
	print STDOUT "ERR=[* $gameSubName : $@]\n";
	$table->set($gameSubName,"X"); # do not call again
	return undef;
	}
    return $res;
    } # gameSub
    
sub joinTable {
    my $table=shift;
    my ($player,$language,$fhOut) = @_; # $player: id or name
    # result: player number
# ??? no SetStatus here, changes will not write $tableFile !!!

    my $game=$table->get('GAME'); # game=abbreviation, GAME=full name
    die "*** unknown game\n" unless $game;

    if (!$table->{'JitsiRoom.X'}) { # create "random" room name
	my $tableFile=$table->{'TABLEFILE..'};
	$table->set('JitsiRoom.X',$table->{name}."-"
		.substr((lstat($tableFile))[9],2,6));
	}
    my $config=\%{$table->{config}};
    $config->{'JitsiRoom'}=$table->{'JitsiRoom.X'};
    my $tmp="";
    foreach my $confKey (sort keys %{$config}) {
	my $val=$config->{$confKey}; $val="" unless defined($val);
	#my $valT=$table->{$confKey};
	#    $valT=$table->{$confKey.".X"} unless defined($valT);
	my $valT=$table->{$confKey.".X"};
	    $valT=$table->{$confKey} unless defined($valT);
	$val=$valT if defined($valT); # override by table value
	if ($confKey=~/^[a-zA-Z\.\-\d]+$/) {
	# do not move this part to 'table' 
	# (would use set for each call with mode=F)
	    $table->set($confKey,$val,-1); # -1 : don't overwrite previous value¸
		#if # !defined($table->get($confKey)) && # don't overwrite: -1
		  #  index($confKey,'#')<0; # #=placeholder for player number
	    $tmp.='$'.$confKey."=".$val."\t";
	    print $fhOut "%".$confKey."=".$val,"\n" 
		if index($confKey,'.X')<0; # ??there should not be a .X in config
	    }
	elsif ($confKey=~/^\w+$/ || $confKey=~/^\w+(\_|\-).*$/) {
	    print $fhOut "%".$confKey."=".$val."\n"; 
	    $tmp.=$confKey."=".$val."\t";
	    }
	elsif (substr($confKey,0,1) eq ":") { # used only on client side
	    print $fhOut $confKey.'='.$val,"\n";
	    }
	#else { 
	}
    $table->printLog("*keys sent:".$tmp."\n");

    $table->setMessages($language,$game,$fhOut);

    my $NP=$table->{'NP'} || 0;
    my $P=0;
    foreach my $i (1..$NP) { # already joined ?
	my $name=$table->{"N$i"}; 
	if (!$name) { # free position
	    $P=$i unless $P>0;
	    next; 
	    } 
	$table->printLog("[P$i=$name]\n",$logOpt) if $table->{test};
	my $id=$table->{"I.$i"};
	if ($id eq $player) { # 
	    $table->printLog("ERR=[$player : id already defined]\n",$logOpt) 
		if $table->{test};
	    return $i; 
	    }
	if ($name=~/^$player$/i) {
		    # re-entry with same name, only with XXX
	    my $tmp=($table->{"XXX.X"} ? "($i)" : "");
	    print "ERR=[&alreadyPlaying($name,$tmp)]\n"; 
	    return $i if $table->{"XXX.X"}; 
	    return ""; 
	    }
	}
    if ($P==0) { # not found : new
	if ($table->{"MAXRP"} && $NP>=$table->{"MAXRP"}) {
	    print "ERR=[&fullTable()]\n";
	    return "";
	    }
	$P=$NP+1;
	## set later: $table->set('NP',$P,2);
	}
    return -$P; # <0 : to setup
    } # joinTable

sub setMessages {
    my $table=shift;
    my ($language, $game, $fhOut) = @_;

    my %msg;
    $msg{'gameLogo'}=$game;
    $msg{'alreadyPlaying'}='"$1" is already playing $2';
    $msg{'fullTable'}='no more players (full)';
    $msg{'noTABLEFILE'}='TABLEFILE not defined';
    $msg{'noStepBack'}='not possible (not enough stop points';
    $msg{'leftOverCards'}='still cards to deal. might try ';
    $msg{'tooFew'}='too few players';
    $msg{'exactlyOnce'}='specify each exactly once';
    $msg{'isTrump'}='$1[ is trump]';
    $msg{'newPlayer'}='new player ($1)';
    $msg{'toServe'}='$1 to serve';
    $msg{'jitsi1'}='embedded Jitsi window or "cancel" and\n get Jitsi as "PopUp window" with click on "Jitsi-Link" in lower right corner';
    $msg{'jitsi2'}='on laptop or PC a Jitsi video conference should open in a new tab\nSamrtphones/tablets need the Jitsi-App)\nalternatively: Ctl-Click on "Jitsi-Link" below\nClick "i" on the right for further information.';
    $msg{'jitsi3'}='release space reservered for Jitsi\nLogout first!';
    $msg{'showCards'}='cards of $1 at $2';
    
    $table->gameSub("setMsg",\%msg);
    
    my $langDir="$FindBin::Bin/";
    my $nMsg=0;
    foreach ("PC",$game) {
	my $langFile=$langDir."$_-$language.txt";
        if (!-r $langFile) {
	    print STDERR "* Can't read $langFile\n";
	    next;
	    }
	# print STDERR "* Language file: $langFile\n";
	open(LFILE,$langFile) || next;
	while (my $line=<LFILE>) {
	    next if $line=~/^\s*\#/;
	    chomp($line);
	    if ($line=~/^(.+)\;(.*)$/)
		{ $msg{$1}=$2; }
	    }
	close(LFILE);
	}
    foreach my $k (keys %msg) 
	{print $fhOut '%Msg_'.$k."=".$msg{$k}."\n"; }
    return;
    } # setMessages

sub setConfig {
    my $table=shift;
    
    print "*setConfig\n" if $test>0;
    my $conf=$table->{config};
    my $game=$table->{game};

# Only variables in $conf should be sent to and accepted by clients
    $conf->{'GAME'}=$game;	# name of game
    $conf->{'maxImg'}=2;# card images from directories img (utf), img2 ... 
    $conf->{'CPP'}="";	# number of cards per player
    $conf->{'HINT'}="";	# hint for current player
    $conf->{'MSG'}="";	# message to all
    $conf->{'NP'}=0;	# number of registered players 
    $conf->{'NCP'}=0;	# number of currently playing players (0: use 'NP')
    $conf->{'MAXRP'}=9;	# maximum number of registered players
    $conf->{'MAXCP'}=8;	# maximum number of current players
    $conf->{'MINCP'}=2;	# minimum number of current players
    $conf->{'R'}=0;	# round number (0=not started)
    $conf->{'PC'}=0;	# play counter
    $conf->{'F'}=0;	# =<#> current forehand (1st trick)
    $conf->{'N'}=0;	# =<#> player to play his card
    $conf->{'X'}=0;	# = <#> next player to play his card
    $conf->{'T'}=-1;	# trick number in play
    $conf->{'NC'}=0;	# number of cards in trick
    $conf->{'C'}="";	# =<contract card>:<#> current contract
    $conf->{'LT'}="";	# last trick (to be shown on demand)
    $conf->{'CP'}="";	# players that may play card
    $conf->{'CPA'}=0;	# =1: announcements (in T=0) only from current player
    $conf->{'CT'}="";	# current trick (concat T0..)
    $conf->{'SORT'}='std'; 
    $conf->{'GP'}='';	# game points
    $conf->{':ID'}='';	# playerId
    $conf->{'OWNHAND'}='';
    $conf->{'myP'}=0;
    $conf->{'POS'}='';	# positions of players at table
    $conf->{'STOP'}='';	# used to stop recurrent waits (wc)
    $conf->{'TS'}=0;	# timestamp
    $conf->{'FS'}=0;	# file size (of table file)
    $conf->{'T0B'}='';	# buttons for use before 1st (zero) trick
    $conf->{'TxB'}='';	# buttons for use after zero trick
    $conf->{'cardValues'}=1;	# use cardPoints to add trick's card values
# per player number: (currently not checked !)
    $conf->{'N#'}="";	# name of player at position #
    $conf->{'G#'}="";	# gross points of player
    $conf->{'W#'}="";	# number of tricks won by <#> or last points
    $conf->{'A#'}="";	# announcements of player <#>
    $conf->{'T#'}="";	# card of <#> in current trick
    $conf->{'P#'}="";	# special trick points of <#>
    $conf->{'L#'}="";	# used in learner mode
    # variables with .# will only be sent to player #
    $conf->{'H.#'}="";	# hand of player <P>
    $conf->{'B.#'}="";	# special buttons
# used at client side:
    $conf->{':SUMM'}='GT,POS0:R:Runde'; # GT: line for grand total
	# POS0:variable:help counter shown at 0 position of summary
    $conf->{'AUTO'}='LAST,POINTS'; 
	# last trick is played automatically
	# do not ask for points (otherwise 1st player gets button)
    # Miscellaneous:
    $conf->{'Local_uu'}='1F0D1;change utf/image card presentation;3'; # ace of clubs
    $conf->{'Symbol_gm'}='L-KrPiHeKa.png;Card Games'; # 

# Symbols and buttons for all games.
#   $conf->{'CATEGORY_XX'}='HEXUTF;HELPTEXT;COLOR'; 
#	CATEGORY
#	    Symbol=only for display
#	    Server=to be handled in serverReq
#	    Local=handled on client-side (localAct)
#	    Ann=announcements (categoryA), handled game-specific
#	    Pc=playing cards (categoryP)
#	    Master=game-specific settings by master player 
#		click appends XX to 'masterOpt', and calls gameSub("master")
#	XX : 2-character abbreviation (1st character=uppercase reservered for
#	    game-specific symbols and buttons
#	HEXUTF : hexadecimal UTF code
#	HELPTEXT : shown when mouseOver
#	COLOR : 0.. as defined on client side (colorNames)

    $conf->{'masterButtons'}='Rd,pi';
# re-deal: use in masterButtons 
#   or set RD to re-deal option in configuration file (see @reDeal in checkCards)
    $conf->{'Server_Rd'}='267A;re-deal'; # recycling (re-deal)
# Misc symbols:
    $conf->{'Symbol_a2'}='2606;bids;1'; # star (not used)
    $conf->{'Server_nt'}='2600;you lead;1'; #sun
# result symbols:
    $conf->{'Symbol_G1'}='1F3C6;won;6'; # trophy
    $conf->{'Symbol_m1'}='2212;minus;1'; #
# request server actions;
    $conf->{'Server_ok'}='2611;ok/acknowledge/start;3'; #check (o.k.)
    $conf->{'Server_bk'}='2B05;1 step back '
	.'(double-klick : 2 steps)\n'
	.'(it may be necessary for all players to reload=ctl-R);1';
    # back one step: bk counts its clicks and sends BK(# steps) after 300 msec
    $conf->{'Server_hl'}='24C1;show my cards at player ...;3'; #L=learner
    $conf->{'Server_p1'}='2295;add player;4'; #circled plus
    $conf->{'Server_pi'}='1F522;set player positions;0'; # 1234
    $conf->{'Server_pt'}='2684;manual input of points'; #die face-5 points
			# used to specify game points
# needed to start the html screen:
    $conf->{'Symbol_tw'}='1F0A0;# of tricks won (last points);0'; 
	# back of card (won tricks)
    $conf->{'Symbol_nn'}='1F0CF;player'; # 'black joker'
    $conf->{'Symbol_cc'}='1F0F4;cards;0'; # 'playing card trump-20'
    $conf->{'Symbol_qq'}='3F;input required'; #?
    $conf->{'Symbol_xx'}='1F0B0;place holder (something missing?);1'; # 
    $conf->{'Symbol_00'}='1F0A0;place holder;0'; # back of card
    $conf->{'Server_rl'}='27F3;reload'; #open circle (reload)
    #local actions:
    $conf->{'Local_ji'}='Logo_Jitsi.svg.png;switch jitsi handling';
    $conf->{'Local_li'}='1F6C8;info;0'; #circled information source
    $conf->{'Local_lc'}='1F5AE;chat'; #keyboard
    $conf->{'Local_lg'}='2699;change configuration'; #gear
    $conf->{'Local_lt'}='3F;test'; #??
    $conf->{'Local_ls'}='1F6D1;stop busy wait;1'; #stop busy wait wc
    $conf->{'Local_gt'}='2680;score'; #die face-1 (Würfel) grand total
    $conf->{'Local_an'}='2609;bids;1'; # sun (also to (not) show grand total)
    
    $conf->{'Symbol_r0'}='270D;receiving'; #writing hand
    $conf->{'Symbol_r1'}='26D4;currently no entry'; #no entry
    $conf->{'Symbol_wc'}='231B;hourglass/wait'; #hourglass /alt: 23F3
    $conf->{'Symbol_rC'}='2944;server communicates via sockets'; #arrows
    $conf->{'Symbol_rF'}='1F5CE;server communication via file'; #Document
    
    $conf->{'cardSequence'}='AKQJ1987'; #Ace,King,Queen,Jack,10,9,8,7,...
	    # changed in 'gameSub'
    $conf->{'trumpsStd'}='S0';
    $conf->{'colorNames'}='&spades(),&hearts(),&diamonds(),&clubs()';
    $table->gameSub("getConfig","");
    #print "** game=$game\n";
    #$@=""; 
    #my $gameSub=$game."::getConfig";
    #my $res=eval("no strict 'refs'; $gameSub(\$conf);");
    #$@="" if $@=~/undefined subroutine/i;

  # Priority for definitions in $table:
    foreach my $k (keys %$conf) {
	$conf->{$k}=$table->{$k} if defined($table->{$k});
	}

    $table->createCards(); # pc_CC (color,card), trumps/sorted-..., cardDeck
  # Now take from conf:
    foreach my $k (keys %$table) {
	$table->set($k,$conf->{$k}) 
	    if defined($conf->{$k}) && $table->{$k} ne $conf->{$k};
	}
    } # setConfig

sub createCards { 
    my $table=shift;
    # remove cards or create other deck in gameSub("getConfig")
    my $conf=$table->{config};
    # Cards: 2 characters CC=ColorCard 
    #	Color=0..3=spades,hearts,diamonds,clubs
    #	Card=7,8,9,1=10,J=jack,Q=queen,K=king,A=ace
    my $cardSequence=$table->{'cardSequence'}
	    || $table->{'cardSequence.X'} || $conf->{'cardSequence'};
    $conf->{'sorted-..'}=",.".join(",.",split("",$cardSequence)); 
	# avoid 1st character "." meaning append to previous value in set()
	#'.A,.K,.Q,.J,.1,.9,.8,.7,.6,.5,.4,.3,.2,';
# card values:
    my %cVal; $cVal{'A'}=11; $cVal{'K'}=4; $cVal{'Q'}=3; 
    $cVal{'J'}=2; $cVal{'1'}=10; 
    $cVal{'9'}=9; # set('cardval-9',0) in Doppelkopf
    if ($conf->{'cardValues'}) {
	# 2..8 take value of 9 (if 0) or 2..8
	for (my $i=0; $i<length($cardSequence); $i++) {
	    my $cc=substr($cardSequence,$i,1);
	    if (!defined($conf->{'cardval-'.$cc}))
		{ $conf->{'cardval-'.$cc}=$cVal{$cc} || 0; }
	    }
	}
    foreach (0..3) { $conf->{'color-'.$_}='S'.$_; }
    my @helpCol=split(",",$conf->{'colorNames'});
	# @helpCol=('Pik','Herz','Karo','Kreuz'); 
    my @uCol=('A','B','C','D'); # u : utf
    my @cd=split("",substr("AKQJ198765432",0,length($cardSequence))); 
    my @uCd=split("",'1EDBA');
    my @helpCard=('&ace()','&king()','&queen()','&jack()','10'); 
    my $deck=''; my @trumps;
    $conf->{'trumps-Sn'}="";
    for my $col (3,0,1,2) {
	my $trumps='';
	foreach my $cd (0..(scalar @cd-1)) { 
	    my $cc="$col".$cd[$cd];
	    $trumps.=$cc.",";
	    $deck.=$cc.",";
	    next if $conf->{"Pc_$cc"}; # already defined
	    my $uCd=$uCd[$cd] || $cd[$cd];
	    $conf->{"Pc_$cc"}=
		'1F0'.$uCol[$col].$uCd.";"
		.$helpCol[$col]." ".($helpCard[$cd] || $cd[$cd]).";"
		.$col; 
	    }
	$conf->{'trumps-S'.$col}=$trumps unless $conf->{'trumps-S'.$col};
	$trumps[$col]=$conf->{'trumps-S'.$col};
	} 
    $conf->{'cardDeck'}=$deck;
    my $stdSort=$conf->{'sorted-..'} || "";
    $stdSort=substr($stdSort,1) if substr($stdSort,0,1) eq ",";
    foreach my $key (keys %{$conf}) {
	if ($key=~/^trumps\-(.*)$/) {
	    my $trumpId=$1; my $sorted=$conf->{$key}." ";
	    next if $conf->{'sorted-'.$trumpId};
	    for my $col (0..3) {
		my $sortCol=$stdSort;
		$sortCol=~s/\./$col/g;
		$sorted.=$sortCol.",";
		}
	    $conf->{'sorted-'.$trumpId}=$sorted;
	    }
	}
    my $std=$conf->{'stdTrump'};
    if ($std) {
	$conf->{'trumps-std'}=$conf->{'trumps-'.$std};
	$conf->{'sorted-std'}=$conf->{'sorted-'.$std};
	}
    if ($test>0) {
	print "*** cardDeck=$deck\n";
	foreach (sort keys %{$conf}) {
	    print "*** $_=",$conf->{$_},"\n" if $_=~/(trump|sort)/i;
	    }
	}
    } # createCards

sub readStatus { 
    my $table = shift;
    # read from filehandle into %status (and %newState)
    my ($lastFS,$tgtTS,$mode) = @_; 
    # $fh	file handle
    # $lastFS	put also in %newState if timestamps are after $lastFS (>0)
    # $tgtTS	(optional) timestamp number: truncate before that timestamp
    #		used to get back to a previous state
    # $mode (default from $table->{mode} =S : just set %newState 
    #			(%status should be up-to-date in server mmode
    
    my $fh=$table->{fh};
    if (!$fh) {
	my $file=$table->{'TABLEFILE..'};
	if (!$file) { print "ERR=[&noTABLEFILE()]\n"; return undef; }
	$fh=openStatus($file);
	$table->{fh}=$fh;
	}
    $lastFS=0 unless defined($lastFS);
    $tgtTS=0 unless defined($tgtTS);
    $mode=$table->{mode} || "" unless $mode;
    if ($lastFS<0) { $mode=""; $lastFS=0; }
    if ($mode ne "S") {
	my $n=scalar (keys %{$table->{newState}});
	print STDERR "***readStatus: newState #keys=$n (write first?)\n" if $n>0;
	}
    my $nTS=0; my $chg=0; my $setStatusOpt=0; my @TS; my $lenTS=0; my $lenLine;
    if ($tgtTS!=0 || $lastFS==0) { seek($fh, 0, 0); }
    # already done in main program: else { seek($fh,$lastFS,0); }
    my $posFH=tell($fh); 
    $table->printLog("#readStatus($lastFS,$tgtTS,$mode) at $posFH\n",$logOpt)
	if $table->{test};
    while (my $line=<$fh>) {
	$table->printLog("*status($setStatusOpt): ".$line,$logOpt) 
	    if $table->{test}>10;
	$lenLine=length($line);
	chomp($line);
	next if $line eq "";
	my ($name, $val) = split("\t",$line);
	$table->printLog("* no tab in $line\n",$logOpt)
	    if !defined($val);
	if ($name eq "TS") { # timestamp
	    #$setStatusOpt=1 if $lastFS>0 && $val>$lastFS;
	    $lenTS=$lenLine;
	    if ($chg>0) { # disregard, if next is also TS
		$chg=0; $nTS++; 
		push(@TS,tell($fh)) if $tgtTS!=0;
		last if $tgtTS==$nTS;
		} 
	    }
	else { $chg=1; }
	my $oldVal=$table->{$name};
	$table->{$name}=$val;
	next if $table->{newState}->{$name} 
	     && $table->{newState}->{$name}>1; # >1: already marked for all
	print  "* $name=$val\n" if $table->{test}==9;
	#if (!defined($oldVal)) { 
	 #   $table->{newState}->{$name}=2; # send to all
	  #  }
	#els
	if ($posFH>=$lastFS) {
	    if ($lastFS>0 && $table->{test}>3) {
		# || "";
		my $tmp=$oldVal || "undef";
		print STDOUT "* $name=$val (new>lastFS,old=$tmp)\n";
		}
	    $table->{newState}->{$name}=1; # send to current player only
	    }
	#$table->{$name}=$val if $mode ne "S" || !defined($oldVal);
	$posFH=tell($fh);
	}
    if ($tgtTS!=0) {
	if ($tgtTS<0) { # counted from last TS in file
	    $tgtTS=$nTS+$tgtTS;
	    return $nTS if $tgtTS<1;
	    $nTS=$tgtTS;
	    $posFH=$TS[$tgtTS];
	    }
	if ($nTS==$tgtTS) {
	    $posFH-=$lenTS if $posFH>$lenLine; # before *TS timestamp'
	    $table->printLog("#truncate at $posFH. TS# $nTS \n",$logOpt);
	    seek($fh,$posFH,0) # avoid to stand behind new EOF
		|| $table->printLog("# seek $posFH,0 failed : $!\n",$logOpt);
	    truncate($fh,$posFH) 
		|| $table->printLog("# truncate ($posFH) failed : $!\n",$logOpt);
	    print $fh "#back	$tgtTS\n";
	    $nTS--; # last TS was deleted^
	    }
	}
    return $nTS;
    } # readStatus

sub set { # also saves new data
    my $table=shift;
    my ($name, $val, $new) = @_; 
	# $new=0 : don't write new
	#     =1 : do write, if changed (default) (sets newState(name)=2)
	#     =2 : do write
	#     =-1 : do not override existing value (if changed, set newState)
#	#     =3 : write into tableFile (used in player setup phase, when
#	#	   only the player receives newState) (not joinTable,newPlayer)
    # '§$NUM' (1..$NP) or '§$NUM' (0..3, current player) in $val 
    #  will be replaced by player name from N_ or C resp.
    $new=1 unless defined($new); # write ($new=1) is default
    my $oldVal=$table->{$name};
    if (defined($oldVal)) { 
	if ($new<0) 
	    { print "*set($name) skipped$new\t" if $table->{test}>3; return; }
	}
    else { $oldVal=""; }
    $val=$oldVal unless defined($val);
    while ($val=~/^\s+(.*)$/ || $val=~/^(.*)\s+$/) { $val=$1; }
    while ($val=~/^(.*)\§(\d)(.*)$/) { # replace §P by name of splayer P
	$val=$1.$table->get("N$2").$3;
	} 
    #$val.="[ ($name §??)]" if index($val,"§")>=0;
    my $c0=substr($val,0,1); # append $val if prefixed with '.'
    if ($c0 eq "." && $val ne "..") { $val=$oldVal.substr($val,1); }
    elsif ($new<2 && $c0 ne "." && $val eq $oldVal) {
	$table->printLog("*nochange: $name=$val\n",$logOpt) 
	    if $table->{test}>9; 
	return; 
	}
    $table->{$name}=$val;
    print "*set $name=leer\n" if $test && "$val" eq "";
    #if ($name eq "TS") { # timestamp
	#$table->printLog("*TS=$TS -> $val (last=$oldVal)\n",$logOpt) if $table->{test}>5;
	#$TS=$val;
	#}
    if ($new>1 || ($new!=0 && $val ne $oldVal)) {
	    $table->{newState}->{$name}=2; # =$new; 
	    $table->printLog("*set: $name=$val($oldVal)\n",0) 
		if $table->{test}>0;
	    #my $fh=$table->{fh};
	    #print $fh $name,"\t",$val,"\n" if $new>3;
	}
    } # set

sub get {
    my $table=shift;
    my ($key) = @_;
    return $table->{$key};
    } # get

sub nextPlayer { 
# returns player number after/before player $pNum (0 if $pNum not in 'POS')
    # $pNum : player number in 'POS'
    # $add  : >0 (default): forwward in list, < 0 : backwards
    my $table=shift;
    my ($pNum,$add) = @_;
    $pNum=0 unless $pNum;
    $add=1 unless defined($add);
    
    my $res=0;
    my $POS=$table->get('POS') || "";
    if ($POS) {
	my $iPos=index($POS,$pNum);
	$res=($iPos<0 ? 0 : substr($POS,($iPos+$add)%length($POS),1));
	}
    $table->printLog("*nextPlayer($pNum,$add)=$res pos=$POS\n",$logOpt)
	if $table->{test}>3;
    return $res;
    } # nextPlayer

sub checkTrick {
    my $table = shift;
    my ($cardId,$myP) = @_;

    my $T=$table->{'T'};
    if (!$T) {
	if ($table->get('CPA')) { # 'CP','N' ...
	    }
	return 1; 
	} 
    return 1 if substr($cardId,0,1)!~/[0123]/; # not a card 
    my $myCards=$table->{"H.$myP"};
    $table->printOut("HINT=".$cardId."[ wird geprüft]\n");
    if ($table->{test}>0) { $table->printLog("*msg=myC:$myCards\n",$logOpt); }
    if (!defined($myCards=cardIsIn($cardId,$myCards,1))) {
	$table->printOut("HINT=[Du hast die Karte nicht: ]$cardId\n");
	return 0;
	}
    if ($table->{test}>0) { $table->printLog("*msg=myC:$myCards\n",$logOpt); }
    my $CT=$table->{'CT'} || "";
    my $winner=($CT eq "" ? 0 : $table->checkCard($cardId,$CT,$myCards));
    if ($winner<0) {
	print "*checkCard: returns -1=error\n" if $test>1;
	return 0; # checkCard return -1 on error
	}
    $table->set('MSG',$cardId."[ von §$myP]");
    $CT.=$cardId;
    $table->set('CT',$CT);
    my $nc=($table->get('NC') || 0)+1;
    $table->set('NC',$nc);
    $table->set("H.$myP",$myCards);
    # next player / winner->playerId
    $table->set("T$myP",$cardId);
    my $CPP=$table->get('CPP');
    my $X=$table->get('X') || -1;
    my $NCP=$table->get('NCP') || $table->get('NP');
    
    my $winP=$table->nextPlayer($X,$winner); # -> player number
    my $N=$table->nextPlayer($table->get('N')) || 0;
    $table->set('N',$N); # next player
    if ($N==$X) { # trick is complete
	my $tmp=$table->{"TRICKS..$winP"} || 0;
	$table->set("TRICKS..$winP",$tmp+1);
	my $cardPoints=0;
	if ($table->{'cardValues'}) {
	    $cardPoints=$table->cardPoints($CT);
	    $tmp=$table->{"POINTS..$winP"} || 0;
	    $table->set("POINTS..$winP",$tmp+$cardPoints);
	    }
	$tmp=$table->{"W$winP"} || 0;
	$table->set("W$winP",$tmp+1);
	$table->set('LT',"[ §$X :]".$CT."[>>§$winP]");
	$table->set('MSG',"[§$winP bekommt den Stich]");
	$table->set('X',$winP);
	$table->set('N',($T=$CPP ? 0 :$winP));
	$table->set("B.$winP",".,nt"); # button to nextTrick
	$table->set("T$winP",".,/nt"); 
	$table->set('CP',"X"); # no player : wait for nt
	$table->gameSub("completeTrick","$winP,$CT,$X,$cardPoints");
	}
    else {
	$table->set('CP',"$N");
	}
    return 1;
    } # checkTrick

sub cardPoints { 
    my $table = shift;
    my ($cards) = @_; 
    # add card values of $cards (current trick )
    # returns $cardPoints

    my $cardPoints=0;
    my $cv9=$table->get('cardval-9'); $cv9=0 unless defined($cv9) && $cv9 ne "";
#    my ($pointCode,@specCode)=split(";",$spCode);
    my $cards_=$cards; my $msg="*cardPoints($cards):";
    while ($cards_ ne "") {
	if (substr($cards_,0,1) =~ /[\s\,]/)
	    { $cards_=substr($cards_,1); next; }
	my $card=substr($cards_,0,2); $cards_=substr($cards_,2);
	my $cc=substr($card,1,1);
	my $cardVal=$table->get('cardval-'.$cc) || $cv9;
	if (!defined($cardVal)) {
	    $table->printLog("**invalid cardVal for $card\n",1);
	    }
	else { 
	    $cardVal=$cc if $cc=~/[2-8]/ && $cardVal==9;
	    $cardPoints+=$cardVal; 
	    $msg.=" $cc=$cardVal";
	    }
	}
    $table->printLog($msg."\n") if $table->{test}>3;
    return $cardPoints;
    } # cardPoints

sub nextTrick { # show points or start next trick
    my $table = shift;
    
    my $CP=$table->{'CP'} || ""; my $CT=$table->{'CT'} || "";
    my $T=$table->{'T'} || 0; my $CPP=$table->get('CPP') || 0;
    $table->printLog("*nextTrick: T:$T CPP:$CPP CP=$CP CT=$CT\n",$logOpt);
    return 0 if $CP ne "X"; # ?? || !$CT;

    my $POS=$table->get('POS');
    foreach my $P (split("",$POS))
	{ $table->set("T$P",""); }
    if ($T>=$CPP) {
	# points for the trick?
	$table->set('T',$CPP+1); # show result, until ok ??
	$table->set('CP',"");
	my $automatic=$table->get('AUTO') || "";
	my $gp=$table->gameSub("gamePoints",$POS);
	if ($gp) {
	    $table->set('GP..',$gp,2); # always write
	    $table->addGamePoints($gp) if index($automatic,'POIN')>=0;
	    }
	elsif (index($automatic,'POIN')<0) 
	    { $table->set('MSG',"./[Ggf. Punkteeingabe über]pt"); }
	}
    elsif ($T>=0) {
	$table->startTrick(0,"nT"); 
	}
    return 1;
    } # nextTrick

sub checkCard { # returns winner of trick (up to cuurent card)
    my $table = shift;
    my ($cardId, $CT, $myCards) = @_;
    
#    my $trumps=$table->{'TRUMPS'} || $table->get('trumps-std');
#    my $cardSequence=$table->get('cardSequence'); # A1KQJ9 : Ace,10,K,Q,Jack,9
    my $sort=$table->get('SORT') || 'std';
    my $sortedCards=$table->get('sorted-'.$sort) || $table->get('sorted-std') 
		|| "";
	# trumps until first space
    my $posNonTrump=index($sortedCards," ");
    my $trumps=substr($sortedCards,0,$posNonTrump);
    
    my $highCard=substr($CT,0,2); # start with 1st card in current trick
    my $posCard=index($sortedCards,$cardId);
    my $posHigh=index($sortedCards,$highCard);
#    my $cardColor=(cardIsIn($cardId,$trumps) ? -1 : substr($cardId,0,1));
    my $cardColor=($posCard<$posNonTrump ? -1 : substr($cardId,0,1));
#    my $leadColor=(cardIsIn($highCard,$trumps) ? -1 : substr($highCard,0,1));
    my $leadColor=($posHigh<$posNonTrump ? -1 : substr($highCard,0,1));
    if ("$cardColor" ne "$leadColor") { # lead not followed (trumped?)
	if ("$leadColor" eq "-1") { # trump
	    if (cardIsIn($myCards,$trumps)>0) {
		$table->printLog("$cardId T !/$trumps/$myCards");
		$table->printOut("HINT=[Du musst Trumpf bedienen, statt ]"
				.$cardId."\n",1);
		return -1;
		}
	    }
	else {
	    foreach my $card (split(",",$myCards)) {
		next unless $card;
		next if index($sortedCards,$card)<$posNonTrump;
		if (substr($card,0,1) eq "$leadColor") {
#//	    if (substr($sortedCards,$posNonTrump)=~/$leadColor[^\,\s]/) {
#	    for (my $c=0; $c<length($cardSequence); $c++) {
#		my $card="$leadColor".substr($cardSequence,$c,1);
#		if (cardIsIn($card,$myCards)>0 && cardIsIn($card,$trumps)==0) {
		    $table->printLog
			("**$cardId $leadColor !/$trumps/$myCards($card)")
			if $table->{test};
		    $table->printOut("HINT=[Du musst ]"
			.$table->get("color-$leadColor")."[ bedienen statt ]"
			.$cardId."\n",1);
		    return -1;
		    }
		}
	    }
	}
    $CT.=$cardId;
    my $highColor=$leadColor;
    if ($table->{test}>3) {
	$table->printLog(
	    "TMP=myC=$myCards high=$highCard cCol=$cardColor lCol=$leadColor\n",
	    $logOpt);
	}
    my $winner=0; # position in current trick
    for (my $pos=2; $pos<length($CT); $pos+=2) {
	my $card=substr($CT,$pos,2);
	$posCard=index($sortedCards,$card);
#	$cardColor=(cardIsIn($card,$trumps) ? -1 : substr($card,0,1));
	$cardColor=($posCard<$posNonTrump ? -1 : substr($card,0,1));
	$table->printLog("*check: card=$card/$cardColor/$posCard"
		." high=$highCard/$highColor/$posHigh\n",$logOpt) 
		if $table->{test}>2;
	if ($highColor<0) { # trump
	    next if "$cardColor" ne "-1" || $posCard>$posHigh;
#		    || !higherCard($card,$highCard,$trumps,$cardSequence);
	    }
	elsif ("$cardColor" eq "$highColor") { # followed non-trump suit
	    next if $posCard>$posHigh;
#	    next if !higherCard($card,$highCard,"$cardColor",$cardSequence); 
	    }# not trumped
	elsif ("$cardColor" ne "-1" && "$cardColor" ne "$highColor") 
	    { next; } # not followed suit
	if ($posCard==$posHigh) {
	    my $lastIsHigher=$table->get('lastIsHigher') || "";
	    next unless $card=~/($lastIsHigher)/;
	    }
	$highCard=$card; $highColor=$cardColor; 
	$posHigh=index($sortedCards,$highCard);
	$winner=$pos/2;
	}
    return $winner;
    } # checkCard

sub higherCardObs { # returns 1 if $card is higher than $highCard, else 0
    my ($card, $highCard, $trumpsOrColor,$cardSequence) = @_;
    
    my $res;
    if (length($trumpsOrColor)>1) { # trumps
	if ($card eq $highCard 
	    && substr($trumpsOrColor,index($trumpsOrColor,$card)+2,2) eq $card)
	    { $res=1; } # card is twice in trumps => 2nd is higher
	else 
	  { $res=index($trumpsOrColor,$card)<index($trumpsOrColor,$highCard); }
	}
    else { 
	#$table->printLog("*seq=$cardSequence ",$logOpt) if $table->{test}>2;
	$res=(substr($card,0,1) ne substr($highCard,0,1) ? 0
	     : index($cardSequence,substr($card,1,1))
	      <index($cardSequence,substr($highCard,1,1)));
	}
#    if ($table->{test}>2) 
#	{ $table->printLog("HC($card,$highCard,$trumpsOrColor)=$res\n",$logOpt); }
    return $res;
    } # higherCard

sub cardIsIn {
    my ($chkCards, $cards, $remove) = @_;
	# $remove=0: returns number of occurrences of $chkCards in $cards
	#		(assumes no doubles in $chkCards)
	#        =1: returns $chkCards w/o first occurrence of $cards
	#		undefined, if not in $chkCards
	#	 =2: .. number of occurrences, once per card in $chkCards
	#	 =3: returns $cards w/o all occurrences, once per ...
	# In case of $remove=1 or =2, also the removed cards are returned.
	# Use ($removedCards,$newCards)=... (to get both), or $newCards=...
    $remove=0 unless defined($remove);
    
    #$table->printLog("*cardIsIn: $chkCards; $cards\n",$logOpt) if $table->{test}>2;
    
    my $res=0; my $l=length($cards); my $removed="";
    while ($chkCards ne "") {
	if ($chkCards=~/^[\,\;\ ]/) 
	    { $chkCards=substr($chkCards,1); next; }
	my $card=substr($chkCards,0,2); $chkCards=substr($chkCards,2);
	my $pos=0; 
	while ($pos<=$l-2) {
	    if (substr($cards,$pos,1)=~/[\ \,]/) { $pos++; }
	    else {
		my $card2=substr($cards,$pos,2);
		if ($card2 =~ /$card/) {
		    $res++;
		    if ($remove>0) { 
			$removed.=$card.",";
			$cards=substr($cards,0,$pos).substr($cards,$pos+2);
			$cards=~s/\,\,+/,/g;
			if ($remove==1) { return ($removed,$cards); }
			elsif ($remove==3) { $l=length($cards); next; }
			else { last; }
			}
		    }
		$pos+=2;
		}
	    }
	}
    if ($remove==1) { return; } # undefined
    elsif ($remove==3) { return ($removed,$cards); }
    else { return $res; }
    } # cardIsIn

sub playersToAct {
    my $table = shift;
    my $CP=""; my $toAct="";
    for my $P (0..3) {
	if ($table->{"T$P"} eq "qq" || $table->{"T$P"} eq "") { $CP.="$P"; }
	elsif ($table->{"T$P"} eq "?2") { $toAct.=",§$P"; }
	}
    $table->set('CP',$CP);
    if ($CP eq "" && $toAct ne "") {
	my $msg="[Bitte ]?2[ konkretisieren (".substr($toAct,1).")]";
	$table->set('MSG',"$msg");
	$CP="9";
	}
    return $CP;
    } # playersToAct

sub startTrick {
    my $table = shift;
    my ($startP,$origin) = @_; 
    # $startP : if defined, start with that player, otherwise 'X'
    
    $startP=$table->get('X') unless $startP;
    $table->printLog("*startTrick $startP $origin\n",$logOpt) 
	if $table->{test}>3;
    $table->set('X',$startP);
    my $T=$table->{'T'} || 0;
    $table->set('T',0) if $T<0; # not necessary if T starts at 0
    $table->set('CP',"$startP");
    $table->set('N',$startP); # next player
    $table->set('CT',""); # current trick
    my $pos=$table->get('POS');
    foreach my $P (split("",$pos)) {
	$table->set("T$P",""); # if $P!=$startP;
	$table->set("B.$P","");
	if (!$table->{'T'}) {
	    #my $P_=substr($pos,$P,1); # position of current player $P
	    $table->set("W$P",0); # # of tricks won
	    # remove ok, special (game) from player's status (A$P)
	    my $tmp=$table->{"A$P"} || ""; 
	    $tmp=~s/\?.//g; $table->set("A$P",$tmp);
	    }
	}
    $table->set('T',($table->{'T'} || 0)+1);
    $table->set('NC',0);
    $table->set("T$startP","qq");
    } # startTrick

sub setCurrentPlayers {
    my $table = shift;
    my ($shift) = @_;
    # optionally shift players by +-1 (default) and start next round, when F=1,
    # set positions of players (1..$NP/$NCP) at table in $POS
#??, and also in P..<id>,
    
    my $paused=$table->get('PAUSED') || ""; # set manually via chat field (>...)
    my $F=$table->{'F'} || 0;
    my $lastF=$F;
    my $NP=$table->{'NP'};
    my $MAXCP=$table->{'MAXCP'} || $NP; # MAXCP may be less than NP (e.g. @DK =4)
    if ($shift) { $F=nextPos($F,$shift,$NP); }
    elsif ($F<=0) { $F=1; }
    while ($paused=~/$F/) { $F=nextPos($F,$shift,$NP); last if $F==$lastF; }
    if ($F==1 && $lastF!=1) 
	{ my $R=$table->{'R'} || 0; $table->set('R',$R+1); }
    my $P=$F; my $POS="$P";
    $shift=(defined($shift) && $shift>=0 ? 1 : -1);
    for (2..$NP) { 
	$P=nextPos($P,$shift,$NP);
	next if $paused=~/$P/;
	$POS.="$P";
	last if length($POS)>=$MAXCP;
	}
    $table->set('F',$F);
    $table->set('N',$F) if index($paused,$table->{'N'})>=0;
    $table->set('X',$F) if index($paused,$table->{'X'})>=0;
    $table->set('POS',$POS,2); # refresh positions on client (html) side
    $table->set('NCP',length($POS));
    foreach $P (split("",$paused)) 
	{ $table->set("A$P",""); $table->set("W$P",""); } 
    
    sub nextPos {
	my ($P,$shift_,$NP) = @_;
	$shift_=1 unless $shift_;
	$P=$P%$NP+$shift_; $P=$NP if $P<=0;
	return $P;
	}
    } # setCurrentPlayers

sub dealCards {
    my $table = shift;
    my ($addCnt,$msg) = @_; 
    # $addCnt : move forehand, and add to play counter
    # $msg    : optional additional message
    $addCnt=1 unless defined($addCnt); # PROBLEM: DK soli should keep forehand
    $msg="" unless defined($msg);

    $table->set('MSG',$msg);
    $table->set('HINT',"");
# first set the standard values, then setContract (which may change them)
    $table->set('T',0); # startTrick adds 1
    $table->set('LT',"");
    $table->set('C',"");
    $table->set('SORT',"std"); 
    $table->set('SP.X',"") if $table->{'SP.X'};
    my $F=$table->get('F');
    if ($addCnt) {
	$F=$table->nextPlayer($F,$addCnt);
	}
    $F=1 unless $F>0;
    $table->set('F',$F);
    $table->set('X',$F);
    $table->set('N',$F);
    my $PC=$table->get('PC') || 0;
    $PC+=$addCnt;
    $table->set('PC',$PC);
    $table->set('CP',($F<0 ? $table->get('POS') : $F));
    $table->set('TM',"cc");

    $table->gameSub("setContract","");
    $table->setCurrentPlayers(0);
    my $sort=$table->get('SORT') || 'std';
    my $sorted=$table->get('sorted-'.$sort) || $table->get('sorted-std') || "";

    $msg=$table->get('MSG');
    my @allCards=split(",",$table->get('cardDeck'));
    if ($table->get('nDecks')) {
	for (2..$table->get('nDecks')) 
	    { push(@allCards,split(",",$table->get('cardDeck'))); }
	}
    my $CPP=$table->get('CPP') || 2;
    my $ncp=$table->get('NCP') || $table->get('NP');
    if ($CPP*$ncp>scalar @allCards) {
	my $tmp="not enough cards to deal $CPP ($ncp*".scalar @allCards.")";
	$table->printLog($tmp."\n");
	$table->set('MSG',".".$tmp);
	$CPP=int(scalar @allCards/$ncp);
	$table->set('CPP',$CPP);
	}
    my $allCards=join(",",@allCards);
    my $specCards=""; my $msgS="";
    if ($table->get('SP.X')) {
	my $tmp=$table->get('specGames..'.$table->get('SP.X')) || "";
	($msgS,$specCards)=split(":",$tmp);
	if ($specCards) { # remove from allCards
	    $allCards=cardIsIn($specCards,$allCards,3);
	    }
	}
    my @rand=shuffle(scalar @allCards);
    $table->set("..","AC $allCards. Sp $specCards. R ".scalar @rand);
    my $iRand=0; my $POS=$table->get('POS');
    foreach my $P (split("",$POS)) {
	my @cards; my $i0=0; 
	if ($specCards ne "" && substr($POS,1,1) eq "$P") {
	    # spec. for 2nd player
	    push(@cards,split(",",$specCards));
	    $i0=scalar @cards;
	    }
	foreach ($i0+1..$CPP) {
	    push(@cards,$allCards[$rand[$iRand]-1]); 
	    $iRand++;
	    }
	my $cards=join(",",@cards);
	$table->set("H.$P",$cards);
	$table->set("M.$P","");
	$table->set("B.$P","");
	#my $P_=$table->{"C$P"};
	$table->set("POINTS..$P",0); # sum of card points
	$table->set("TRICKS..$P",0); # number of tricks won
	$table->set("A$P","");
	#$table->set("P$P",""); 
	$table->set("T$P",""); 
	}
    # Check for special combinations of cards and set buttons
    $table->gameSub('checkCards',$POS);
    my $tmpMsg="[ &newCards() ($msgS $CPP)]";
    if ($msg ne "") { $tmpMsg=$msg."/".$tmpMsg; }
    # ???$tmpMsg="./".$tmpMsg if $table->{'C'}=~/^\-4/; # keep MSG
    $table->set('MSG',$tmpMsg);
    # startTrick($startP);
    return 1;
    } # dealCards

sub eval_ { # evaluate perl statements
    my $table = shift;
    my ($stmts,$myP,$cards) = @_; 
    # &perlStatements or configAbbreviation,... (TAB is separater if found)
    #		where $table->get(configAbbreviation) = perlStatements
    # $C( and $S( in statements are replaced by $table->get( 
    # SS( is replaced by $table->setStatus
    # returns the result of the last statement (to be used with $changed)
    return 0 unless $stmts;
    my $res;
    my @stmts;
    if (substr($stmts,0,1) eq "&") { push(@stmts,substr($stmts,1)); }
    else {
	my $sep=(index($stmts,"\t")>=0 ? "\t" : ",");
	foreach my $abbr (split($sep,$stmts)) {
	    if ($abbr=~/^(.*)\&(.*)$/) { $abbr=$1.eval(repl($2)); }
	    my $stmt=$table->get($abbr);
	    if (defined($stmt)) { push(@stmts,$stmt); }
	    else { $table->printLog("*eval_: $abbr not found\n"); }
	    }
	}
    foreach my $stmt (@stmts) {
	next unless $stmt; # error msg ?
	$stmt=repl($stmt); # replace $C,$S, SS(
	$table->printOut("*eval: ".$stmt."\n") if $table->{test}>=3;
	$@=""; $res=eval($stmt);
	if ($@ ne "") { $table->printLog("ERR=[eval: $stmt : $@]",1); }
	}
    return $res; # only last result
    
    sub repl { # replace $C,$S, SS(
	my $str=shift; my $rep;
	$rep='$table->get('; $str=~s/\$C\(/$rep/g; 
	$str=~s/\$S\(/$rep/g;  # $rep='$table->{'; 
	$rep='$table->set(';
	$str=~s/SS\(/$rep/g;
	return $str;
	}
    } # eval_

sub specButtons { # returns buttons for special combinations of cards
    # e.g. poverty, redeal (5 nines), marriage
    my $table = shift;
    my ($P,$cards,$actions) = @_;
    
    my $buttons="";
    if ($actions) {
	my $nCards=int(length($cards.",")/3);
    
	foreach my $act (split(",",$actions)) {
	    $act=$table->get('button.'.$act);
	    return "" unless $act;
	    my ($button,$help,@statements)=split(";",$act);
	    my $res=eval_("&".join(";",@statements),$P,$cards);
	    if ($res) { $buttons.=",".$button."[$help]"; }
#	    $table->printOut("*specButtons: $act->$res\n") if $table->{test}>4;
	    }
	}
    $buttons=substr($buttons,1) if $buttons=~/^[\/\,]/;
    return $buttons;
    } # specButtons

sub lookFor { # look for card in <x><0..3>, return one $P in 0..3 per hit
    my $table = shift;
    my ($card, $x) = @_;
    my $res="";
    for my $P (0..3) {
	my $n=cardIsIn($card,$table->{$x."$P"});
	while ($n>0) { $res.="$P"; $n--; }
	}
    return $res;
    } # lookFor

sub newPlayer {
    my $table = shift;
    my ($P,$player) = @_;
    
    $table->set('MSG',"[&newPlayer($player)]");
    $table->printLog("*new player $player($P)\n") if $table->{test};
    # New random PLAYERID:
    my $id;
    do { $id=int(rand()*1000)+1; } while defined($table->{"P..$id"});
    $table->set("N$P",$player);
#    $table->set("W$P",0);
    $table->set("I.$P",$id); # internal id of player at $P
    $table->set("P..$id",$P);
    $table->set("P..$player",$P) if $table->{"XXX.X"};
    $table->set("G$P",""); # score of <player> (sum of game points)
    $table->set("IPADDR..$player",$ENV{'REMOTE_ADDR'});
    my $np=1; while ($table->get("N$np")) { $np++; }
    $np--;
    $table->set('NP',$np);
    if ($table->{test}>0) {
	$table->printLog("*newPlayer: P=$P N=$player NP=$np\n");
	my $tmp="*new:";
	foreach (sort keys %{$table->{newState}}) 
	    { $tmp.="\t".$_."=".$table->{$_}; }
	$table->printLog($tmp."\n");
	}
#    my $NP=$table->{'NP'}; my $nFree=0; 
#    foreach my $i (1..$NP) { $nFree++ if !$table->{"N$i"}; }
#    if ($nFree==0 && $table->{'R'}==0) { startTable($NP); }
    return $P;
    } # newPlayer

sub sendStatus {
    my $table = shift;
    my ($fh,$rNew,$sep,$opt) = @_; # print to tableFile or client
    # $fh	filehandle
    # $rNew	reference to a hash of names to print 
    # $sep 	(optional) separater between key and cardValue (default=TAB)
    #		if '=' ($fh of client) keys with a '.' are not printed
    # $opt 	(optional) =1 (default): send only if newState(name)=1 
    #				used for current player
    #		= 200+myP : send only if newState(name)=2
    #			also send xxx.d to d=$myP
    
    $sep="\t" unless $sep;
    $opt=1 unless defined($opt);
    my $myP=-1;
    if ($opt>=100) { $myP=$opt%100; $opt=($opt-$myP)/100; }
    if ($table->{test}>3) {
	my $player=($myP>=0 ? $table->get("N$myP") || "?"
			     : "");
	$table->printLog("*send($sep,$opt,$myP=$player):\n",$logOpt);
	}
    #print $fh "####$sep$opt\n" if $sep ne "=" && $table->{test}>3;
    return 0 if scalar (keys %$rNew)==0;
    my $n=0; my $tmpMsg="";
    foreach my $name (sort keys %$rNew) {
	next if $name eq ""; # || $name!~/^[A-Z]/; # send only with capital letters
	#if (substr($name,0,5) eq "HASH(") # only with %x={}
	 #   { $table->printLog("# $name=".$rNew->{$name}.";\n",$logOpt); next; }
	my $new=$rNew->{$name};
	if ($opt<0 && -$new!=$opt) {
	    $tmpMsg.=" skipped:$name" if $table->{test}>3;
	    next;
	    }
	if ($name eq "TS")
	    { next if $sep eq "\t"; } # already before with current time
	elsif ($sep eq "=" && index($name,".")>=0) { 
	    # secret player info (send separately?)
	    next if $name!~/\w\.(\d)$/ || $1!=$myP;
	    $table->printLog("*send $name to $myP(n=$new/o=$opt)\n",$logOpt) 
		if $opt>=0 && $table->{test}; # && $opt=~/x/i;
	    $new=$opt; # send always
	    }
	next if $new!=$opt;
	if ($n==0 && $sep eq "\t") { # only for tableFile
	    seek($fh, 0, $SEEK_END) or print $fh "#Cannot seek to EOF - $!\n";
	    my $TS=time();
	    print $fh "TS$sep$TS\n";
	    $table->{"TS"}=$TS;
	    }
	my $val=$table->{$name} || ""; # $rNew has only $new from set()
	$table->printLog("* sendStatus($name)=undefined\n") unless defined($val);
	print $fh $name,$sep,$val,"\n";
	$tmpMsg.=" ".$name.":".$new if $table->{test}>3;
	# $tmpMsg.="=".$val if $name eq 'NP'; # && $sep ne "=";
	$n++;
	}
    if ($table->{test}>3) {
	$table->printLog("#end$sep*SendStatus"
		." #items $n ($sep$opt): $tmpMsg\n",$logOpt);
	}
    $fh->flush;
    return $n;
    } # sendStatus

sub startTable { # set round number and deal first cards
    my $table = shift;
    
    my $NP = $table->get('NP');
    $table->rearrangePos($NP,$table->get('POS.X'));
    my $msg="Players";
    for my $i (1..$NP) { $msg.=",".$table->{"N$i"}; }
    $table->set("GP.",$msg,2); # always write to file !
    $table->dealCards(1);
    } # startTable

sub rearrangePos {
    my $table=shift;
    my ($NP,$newPOS) = @_;
    
    if (!$newPOS) { $newPOS=join("",shuffle($NP)); }
    my (@oldI, @oldN, @oldP);
    for my $p (1..$NP) {
	my $P=substr($newPOS,$p-1,1);
	$oldN[$p]=$table->get("N$P");
	$oldI[$p]=$table->get("I.$P");
	}
    for my $P (1..$NP) {
	my $N=$oldN[$P]; my $I=$oldI[$P];
	$table->set("N$P",$N);
	$table->set("I.$P",$I);
	$table->set("P..$N",$P);
	$table->set("P..$I",$P);
	}
    $table->set('MSG',"[geänderte Positionen ($newPOS)]");
    return 1;
    } # rearrangePos

sub shuffle {	# returns 1..$num in random order
    my ($num) = @_;
    srand;
    my @new = ();
    my @old = 1 .. $num;
    for( @old ){
        my $r = rand @new+1;
        push(@new,$new[$r]);
        $new[$r] = $_;
	}
    return @new;
    } # shuffle

sub createTableFile { 
    my ($tableFile,$user,$pass,$test) = @_; 
    # Initialize table file (w/o players)
    # Currently the table's file must already exit. 
    # invoked by: DK.pl P=TABLE-USER I=PASSWORD C=close
    
    $user=$1 if $user=~/.*\-(.+)$/; # TABLE-USER
    $@="";
    if (!-w $tableFile) {
	$@="ERR=[Table file $tableFile not found (or no right to write)]\n";
	print STDERR $@; 
	return undef;
	}
    my $TS=(lstat($tableFile))[9];
    my $fhTableFile=openStatus($tableFile) || die "$tableFile not opened\n";
    my %status; my $saveFile=0; my $msg=""; my $nLines=0;
    while (my $line=<$fhTableFile>) {
	chomp($line);
	$nLines++;
	if ($line=~/^(.*)\t(.*)$/) {
	    my ($name,$val)=($1,$2);
	    if ($name eq "GAME" || $name=~/\w+\.X/) { $status{$name}=$val; }
	    elsif ($name eq "I.1") # at least 1 player
		{ $saveFile=1; }
	    elsif ($name eq "TS") { $TS=$val; }
	    }
	}
    if (!$status{"Mgr.X"} || $status{"Mgr.X"} ne "$user:$pass") {
	$@="* Mgr.X in $tableFile not verified ($user:$pass)\n"
	    .scalar (keys %status)." states ($nLines lines)\n";
	}
    else {
	if ($saveFile) {
	    if (saveFile($tableFile,$TS,$test)) { $msg="save+new"; }
	    }
	else { $msg="new"; }
	if ($@ eq "") {
	    if (seek($fhTableFile,0,0) && truncate($fhTableFile,0)) {}
	    else { $@="* $tableFile seek 0,0 or truncate failed : $!"; }
	    }
	}
    if ($@ ne "") {
	print STDERR $@."\n";
	close($fhTableFile);
	return undef;
	}
    my $nKeys=0;
    foreach (keys %status) {
	print $fhTableFile $_,"\t",$status{$_},"\n"; 
	$nKeys++;
	}
    $msg.=" $nKeys keys";
    print STDERR "* createTableFile : ".$msg."\n";
    
    return $fhTableFile;
    } # createTableFile

sub saveFile { # copy $file to $file-TIME (use directory /save if exists)
    my ($file, $TS, $test) = @_; 
    
    my @rdt=localtime($TS);
    $rdt[4]++; $rdt[5]+=1900; # adjust month, year
    my $timeStr=sprintf("%04d-%02d-%02d-%02d%02d",
		$rdt[5],$rdt[4],$rdt[3],$rdt[2],$rdt[1]); 
    my ($dir_,$file_)=("",$file);
    if ($file=~/^(.*[\\\/])([^\\\/]+)$/) { $dir_=$1; $file_=$2; }
    $dir_.="save/" if -d $dir_."save";
    my $tgt=$dir_.$file_."-".$timeStr;
    if (!copy($file,$tgt) && !$test) {
	$@="** cp '$file' '$tgt' : $!"; 
	print STDERR $@."\n";
	print "Go on w/o saving (N,yes): "; 
	my $tmp=<STDIN>;
	return undef unless $tmp && $tmp=~/^[yj]/i;
	}
    $@="";
    return 1;
    }

sub upToDate {
    my ($sourceDir) = @_;
    return 1 unless $sourceDir;
    my $prog=$0; my ($currDir, $filename, $type);
    if ($prog=~/^(.*[\\\/])([^\\\/]+)(\.\w+)$/) {
	$currDir=$1; $filename=$2; $type=$3;
	my $src=$sourceDir."/".$filename.$type;
	if (!-e $src) 
	    { print "*source $src not found in $sourceDir\n"; return 1; }
	if ((lstat($src))[9]>(lstat($prog))[9]) { 
	    print "*source $src is newer\n";
	    return 0; 
	    }
	# html not yet handled in apache2 
	# (different directories for cgi-bin and html
	$prog=$currDir.$filename.".html"; 
	$src=$sourceDir.$filename.".html";
	if (!-e $src || !-e $prog) 
	    { print "*html source not found in $sourceDir\n"; return 1; }
	if ((lstat($src))[9]>(lstat($prog))[9]) { 
	    print "*source $src is newer\n";
	    return 0; 
	    }
	return 1;
	}
    else { print "*unknown source\n"; }
    return 1;
    } # uptoDate

sub showLearner { # show cards of learner to others
    my $table = shift;
    my ($fh, $pList, $myP) = @_;
    
    my $msg=""; my $POS=$table->{'POS'};
    while ($pList ne "") {
	my $p=substr($pList,0,1);
	$pList=substr($pList,1);
	if (index($POS,$p)<0) # not in current players
	    { $msg.="#$p "; next; }
	if (index($table->{"L$p"},$myP)>=0) {
	    print $fh "H.$p=".$table->{"H.$p"},"\n"; 
	    $msg.="$p ";
	    }
	else { $msg.="-$p($p) "; }
	}
    # $table->set("L..","## $myP L $msg POS:$POS",2) if $msg ne "";
    } # showLearner

sub stepBack { # set file pointer to previous point
    my $table = shift;
    my ($nTS,$nSteps,$myP) = @_;

	$nSteps=1 unless $nSteps;
	$table->printLog("ERR=[$myP : step back $nSteps from $nTS]",
			    $logOpt);
	if ($nTS>0 && $nTS-$nSteps<2) {
	    $table->printOut("ERR=[&noStepBack()]"."\n");
	    return 0;
	    }
    # stepBack to given TS
    $table->readStatus(0,$nTS-$nSteps); # truncates table file at timestamp
    $table->readStatus(0,0,"R"); # to 'reset' to values before timestamp
    $table->printOut("ERR=[&pleaseReload()]rl\n");

    return 1;
    } # stepBack

sub asPartner { # partner action, controoled by 'P' = LeadPartner[!]
    my $table=shift;
    my ($myP, $id2, $P1, $P2) = @_; 
    # id2 = O|P Own or Partner cards
    # P1  = part in P before myP (empty if myP=Lead, otherwise Partner or Lead)
    # P2  = part in P after myP (empty if myP is Partner, otherwise Partner)
    #	    optionally with '!' : Lead must play for Partner, otherwise 'may')
    
    my ($newP, $msg);
    if ($P1) { # P1 is Lead, myP is Partner
	$newP=($P2 ? 0 : $myP); # P2='!' if not empty
	$msg="[§$P1 spielt für Dich!]";
	}
    else { # myP is Lead, P2 is partner
	$newP=($id2 eq "O" ? $myP : substr("$P2",0,1)); # P2 w/o '!'
	}
    $table->printLog("*asPartner($myP,$id2,$P1,$P2)=$newP}\n") if $test;
    $table->set("M.$myP",$msg) if $msg;
    return $newP;
    } # asPartner

sub canPlay { # returns 1 if current player may play a card
    my $table = shift;
    my ($myP,$opt) = @_; # $opt=1 : print msg if not
    
    my $T=$table->{'T'} || 0; my $CPP=$table->get('CPP') || 0; 
    my $N=$table->{'N'} || 0;
    $table->nextTrick() if $T>0 && $table->get('CP') eq "X";
    my $msg=""; 
    if ($T==0 && (my $C=$table->{'C'})) {
	return (substr($C,2)=~/$myP/ ? 2 : 0); # only if part of a contract (Ar)
	}
    elsif ($T<=0)
	    {  $msg="HINT=[&toBid(?) ]ok"; }
    elsif ($T>0 && $N!=$myP) {
    	    $msg="HINT=[&notYet(), ";
	    $msg.=($N>0 ? "&toServe(".$table->get("N$N").")]" 
			: "&pleaseWait() ]rl[?]");
    	    }
    else { return 1; }
    if ($opt) {
	$table->printOut($msg."\n");
	$table->printOut("H.$myP=".$table->{"H.$myP"}."\n") if $myP;
	$table->printLog("* noch nicht: T=$T my=$myP N=$N\n",$logOpt);
	}
    return 0;
    } # canPlay

sub categoryP { # playing cards
    my $table=shift;
    my ($cardId, $myP) = @_;
    my $changed=1;
    my $canPlay=$table->canPlay($myP,1);
    if ($canPlay) { # 3rd par=1 : includes msg if cannot
	$cardId=~s/[\,\ ]//g; $cardId=~s/\%\d\d//g;
	$table->printLog("*check $cardId can=$canPlay\n",$logOpt) if $test>2;
	if ($canPlay==2) { # contract is active -> game-specific
	    $changed=$table->gameSub("checkContract","$cardId $myP");
	    $table->printLog("checkContract->$changed\n",1) if $table->{test}>3;
	    if (defined($changed) && $changed!=1) {
		return $table->dealCards(0,".") if $changed==2;
		if ($changed==3) { # start trick
		    $table->set('CP',"X");
		    $changed=$table->nextTrick();
		    }
		else {
		    my $N=$table->nextPlayer($table->{'N'});
		    $table->set('N',$N); # next player
		    }
		}
	    }
	elsif (!$table->checkTrick($cardId,$myP)) {
	    my $mode=$table->{mode} || "";
	    $changed=($mode eq "S" ? -1 : -99); 
	    } 
	else {
	    $table->set("T$myP",$cardId);
	    #$table->nextPlayer() if $table->{'CP'} eq "X";
	    $changed=1;
	    }
	}
    else {
	$table->printLog("*catP: can=$canPlay\n") if $test>2;
	$changed=-99; # no further action
	}
    return $changed;
    } # categoryP

sub categoryA { # announcements/bids , reload, points
    my $table = shift;
    my ($cardId, $myP) = @_;
    my $a=substr($cardId,0,1);
    my $T=$table->{'T'} || 0; my $N=$table->{'N'} || 0;
    my $param=substr($cardId,2);
    $cardId=substr($cardId,0,2) if $param ne "";
    my $advN=0; my $CPA=$table->get('CPA') || 0;
    if ($T==0 && $CPA) { # CPA=1 : only from current player, afterwards advance
	if ($N!=$myP) {
	    my $tmp=($N>0 ? $table->get("N$N") : "&noboy()");
	    $table->printOut("HINT=[&notYet(), &toServe($tmp)]\n");
	    return -99; 
	    }
	$advN=1;
	}
    my $adv=$table->gameSub('announcement',"$cardId $myP");
    if (!defined($adv)) # subroutine not defined ?
	{ $table->set("A$myP","./".$cardId); } #print "*no ann($myP $cardId)\n";
    elsif ($adv==2) { return $table->serverReq("ok",$myP); }
    elsif ($adv==1 || $adv<0) { return 0; } # stay at current player

    $table->set("T$myP",$cardId) if $T<=0;
    if ($advN) {
	$N=$table->nextPlayer($table->{'N'});
	$table->set('N',$N); # next player
	if ($N==$table->get('X')) { # complete round of announcements
	    $table->gameSub("checkOK","$cardId $myP $N"); 
	    }
	}
    return $adv;
    } # categoryA

sub categoryM { # master intervention
    my $table=shift;
    my ($cardId, $myP) = @_;
    my $changed=1;

    return -99 if $table->get("MASTER.X") ne $table->get("N$myP"); # ignore
    my $prev=$table->get('masterOpt') || "";
    $table->set('masterOpt',",$cardId".$prev);
    $changed=$table->gameSub('master');
    return $changed || -99;
    } # categoryM

sub serverReq {
    my $table=shift;
    my ($cardId, $myP) = @_;
    
    my $chg=0;
    my $PC=$table->get('PC') || 0; my $T=$table->get('T') || 0;
    my $CPP=$table->get('CPP'); my $NP=$table->get('NP') || 0;
    my $param=substr($cardId,2); $cardId=substr($cardId,0,2);
    $table->printLog("* serverReq: $cardId-$param/$myP PC=$PC T=$T\n",$logOpt);
    if ($cardId eq "ok") {
	if ($PC) { # >0
	    if ($T>0) {
		if ($param eq "ok" || $T>$CPP) {
		    my $gp=$table->get('GP..');
		    $table->addGamePoints($gp) if $gp;
		    my $prevC=$table->get('C') || "";
		    my $adv=($prevC=~/^S/ ? 0 : 1); # solo
		    $chg=$table->dealCards($adv); 
		    }
		else { 
		    $table->printOut("ERR=[&leftOverCards()]ok\n");
		    }
		}
	    else {
		$chg=$table->gameSub("checkContract");
		if (defined($chg)) {
		    return $table->dealCards(0,".") if $chg==2;
		    if ($chg<=0) { # not passed
			my $msg=$table->get('MSG..') || "ERR=[&notYet()]";
			$table->printOut($msg."\n");
			return $chg;
			}
		    }
		$table->set('CP',"X");
		$chg=$table->nextTrick();
		}
	    }
	elsif ($NP<$table->get('MINCP')) {
	    $table->printOut("ERR=[&tooFew()]\n");
	    }
	else { $chg=$table->startTable(); }
	}
    elsif ($cardId eq "nt") {
	$chg=$table->nextTrick();
	}
    elsif ($cardId eq "BK") { # triggered by bk
	$chg=$table->stepBack(0,$param,$myP);
	}
    elsif ($cardId eq "pt") { # manual setting of game points
	my $gp=$table->gameSub("convertPoints",$param);
	$gp=$param unless $gp;
	$table->set('GP..',$gp);
	$chg=1;
	}
    elsif ($cardId eq "rl") { # reload
	$table->readStatus(0);
	$chg=0;
	}
    elsif ($cardId eq "pi") { # new positions of players
	my $tmp=join("",split(",",$param));
	my $msg="";
	if (length($tmp)<=$NP) {
	    for (my $i=1; $i<=$NP; $i++) {
		next if index($tmp,"$i")>=0;
		$msg.=",$i &missing()";
		}
	    $msg=substr($msg,1)." &in() $param!" if $msg ne "";
	    }
	else { $msg="$param : &exactlyOnce"; }
	if ($msg ne "")
	    { $table->printOut("ERR=[$msg]\n"); $chg=0; }
	else { $table->rearrangePos($NP,$tmp); $chg=1; }
	}
    elsif ($cardId eq "hl") { # show cards at other player(s)
	my $VIS=$table->get('VIS') || "";
	my @VIS=split(";",$VIS); my $iV;
	for (my $i=0; $i<scalar @VIS; $i++) {
	    next unless $VIS[$i]=~/$myP\:/;
	    $iV=$i;
	    }
	if ($iV) {
	    if ($param eq "") { splice(@VIS,$iV,1); }
	    else { $VIS[$iV]="$myP:$param"; }
	    }
	else { push(@VIS,"$myP:$param"); }
	$VIS=join(";",@VIS);
	$table->set('VIS',$VIS);
	$table->set("A$myP","./hl[$param]");
	$param="niemandem" if $param=~/^\s*$/;
	$table->set('MSG',"./hl[&showCards(§$myP,$param)]");
	$chg=1;
	}
    elsif ($cardId eq 'Rd') { # re-deal
	my $cards=$table->get("H.$myP") || "";
	$table->dealCards(0,"[§$myP:]/".$cards);
	$chg=1;
	}
    else { $table->printLog("*** not handled\n",$logOpt); }
    return $chg;
    } # serverReq

sub addGamePoints {
    my $table=shift;
    my ($gp) = @_;
    
    return if $gp eq "";
    if ($gp!~/^[\d\:\,\(\)\s]+$/) { # form: PLAYERNUM:POINTS:SHOWasW
	my $gpTmp=$table->gameSub("convertPoints",$gp); 
	$gp=$gpTmp if $gpTmp;
	}
    foreach my $pPts (split(",",$gp)) {
	next unless $pPts;
	my ($P,$pts,$showAsW)=split(":",$pPts);
	my $gpP=$table->get("G$P") || 0; 
	$gpP+=$pts;
	$table->set("G$P",$gpP);
	$table->set("W$P",$showAsW) if defined($showAsW);
	}
    $table->set('GP..',""); # avoid multiple add    
    } # addGamePoints

sub openStatus { # returns filehandle of opened $tableFile
    my ($tableFile,$opt,$out) = @_;
    $opt="+<" unless defined($opt);
    $out=\*STDOUT unless $out;
    
    my $fh;
    print "*",timeStr(1),"open $opt $tableFile " if $test>3;
    if (-e $tableFile) { 
	if (!open($fh,$opt,$tableFile)) {
	    print $out "ERR=[$tableFile open error: $!]\n";
	    exit;
	    }
	}
    else { # !fileno($fhTableFile)) { 
	print $out "ERR=[Table not found]\n"; # $tableFile not created $!
	exit;
	}
    if (!flock($fh, $LOCK_EX|$LOCK_NB)) {
	my $tmp=timeStr(1)."* wait for lock\n";
	print STDERR $tmp; print $out $tmp;
	# Show accessing processes:
	my $lsof=`lsof $tableFile`;
	# print "lsof:\n",$lsof,"\n";
	my @lsof=split("\n",$lsof);
	for (my $p=1; $p<scalar @lsof; $p++) {
	    my @lsof0=split(" ",$lsof[0]); my @lsof1=split(" ",$lsof[1]);
	    for (my $i=0; $i<scalar @lsof0; $i++) {
		if ($lsof0[$i] eq "PID") {
		    if ($lsof1[$i] eq $$) { print "-- self\n"; }
		    else { system("ps -f ".$lsof1[$i]); }
		    last;
		    }
		}
	    }
	if (!$test) {
	    flock($fh, $LOCK_EX) or die "Cannot lock $tableFile - $!\n";
	    print timeStr(1)," done\n" if $test>0;
	    }
	else { print "** not locked\n"; }
	}
    else { print "\n" if $test>3; }
    return $fh;
    } # openStatus

sub sendOwn {
    my $table=shift;
    my ($myP, $fhOut) = @_;
    
    if ($myP>0) {
	my $master=$table->get("MASTER.X") || "";
	my $myName=$table->get("N$myP") || "...";
	foreach my $c ("B","I","H","M") { #{ # Buttons, Id, Hand, Message
	    #if ($changed==2 || defined($newState{"$c.$myP"}))
		# print before the others?
	    my $tmp=$table->{"$c.$myP"} || "";
	    next unless defined($tmp);
	    if ($c eq "B" && $master eq $myName) {
		my $buttons=$table->get('masterButtons');
		$tmp.=",/".$buttons if $buttons;
		}
	    next if $tmp eq "";
	    print $fhOut "$c.$myP=".$tmp."\n"; 
	    # ??? print to client ???
	    } 
	    #}
	my $VIS=$table->get('VIS') || "";
	# visability of other's cards: P:O*,... (player P is visable at O)
	# optionally with delay (T,N) (from trick=T, card=N)
	#  e.g. "1:24,2:1" 2 and 4 see 1, 1 sees 2
	my $partner=""; my $P=0;
	if ($VIS=~/^(.*)(\d)\:\d*$myP\d*/) {
	    my $delay=$1; $P=$2;
	    $partner=$table->{"H.$P"} || "";
	    if ($delay && $delay=~/\((\d+)\,(\d+)\)/) {
		my $t=$1; my $nc=$2; 
		my $T=$table->get('T') || 0; my $NC=$table->get('NC') || 0;
		$partner="" if $t>$T || ($t==$T && $nc>$NC);
		print "*VIS d=$delay p=$P tT=$t/$T nc=$nc/$NC ->$partner\n";
		    # if $test;
		}
	    }
	print $fhOut "P.$P=".$partner."\n"; # if $partner ne "#"; 
	}
    } # sendOwn

sub printLog {
    my $table=shift;
    my $fh=$table->{fhLog};
    my ($str,$opt)= @_; # $opt=1 : print on STDOUT
    
    if ($str=~/^\\n/) { $str="\n".timeStr(1).substr($str,1); }
    else { $str=timeStr(1).$str; }
    if (defined($fh) && fileno($fh)) { print $fh $str; }
    if ($opt || !defined($fh)) { print $str; }
    } # printLog

sub printOut { # does not work in calls with gameSub -> use M.$P
    my $table=shift;
    my ($str,$stdout) = @_;
    
    my $fh=$table->{fhOut}; $fh=\*STDOUT unless defined($fh);
    print $fh $str || print "**printOut $str -> Error $!\n";
    print "*",timeStr(1),$str if $stdout && $fh eq $table->{fhOut};
    } # printOut

sub timeStr { # returns time string
    my ($opt, $ts) = @_;
    # $opt: =0 (default: iso format), =1 hh:mm:ss
    # $ts : timestamp (default: now)
    $opt=0 unless $opt;
    $ts=time() unless $ts;
    my ($sec,$min,$hour,$day,$month,$year)=localtime($ts);
    $month++; $year+=1900;
    my $res="";
    if ($opt==0) { $res=sprintf("%04d-%02d-%02d ",$year,$month,$day); }
    $res.=sprintf("%02d:%02d:%02d ",$hour,$min,$sec);
    return $res;
    } # timeStr

sub getQuery { # reads parameters from query, file, or command line
    my ($fh,$sep) = @_; 
    # $fh : (optional) filehandle from which to read parameters
    # reads parameters either 
    #		from file (handle): PAR1=VAL1\tPAR2=VAL2\t...\n (separated by $sep)
    #			file handle must be open for read: open($FH,"FILE")
    #		from query: .../PROG.pl?PAR1=VAL1&PAR2=VAL2 ...
    #		from command line: perl PROG.pl PAR1=VAL1 PAR2=VAL2 ...
    $sep="\t" unless $sep; # (optional) default with filehandle

    my (@par, %params, $mode); my $rPar=\@par;
    my $queryStr=$ENV{QUERY_STRING};
    if (defined($fh)) {
	{ do { 
	    $queryStr=<$fh>; last unless defined($queryStr);
	    $queryStr="" if (!defined($queryStr));
	    chomp($queryStr);
	    push(@par,split($sep,$queryStr));
	    }
	    while ($sep eq "\n"); # read one parameter per line if $sep=\n
	$mode="F"; # file mode
	} }
    elsif (defined($queryStr)) {
	if (index($queryStr,"%")>=0) {
	    $queryStr=uri_unescape($queryStr);
	    }
	@par=split(/&/,$queryStr);
	$mode="Q"; # query via http
	}
    else { 
	$rPar=\@ARGV;
	$mode="P"; # parameter (test mode)
	}
    foreach (@$rPar) {
	my @tmp=split("=",$_);
	$params{$tmp[0]}=$tmp[1];
	#print "Par= ",join(":",@tmp),"\n" if $params{'test'};
	}
    print timeStr(1),"*Query:",join(";",@$rPar),"\n" if $params{'test'};
    return ($mode,%params);
    } # getQuery

sub newSocket {
    my ($host,$port,$CS) = @_; # $CS=1 server, =0 client
    
    require IO::Socket::INET;
    # creating object interface of IO::Socket::INET modules which internally does 
    # socket creation, binding and listening at the specified port address.
my $socket;
    if ($CS) {
	$socket = new IO::Socket::INET (
	    LocalHost => $host,
	    LocalPort => $port,
	    Proto => 'tcp',
	    Listen => 8,
	    Reuse => 1,
	    ) or die "ERROR in Server Socket Creation for port $port: $!\n";
	}
    else {
	$socket = IO::Socket::INET->new (
	    #Domain => AF_INET,
	    #Type => SOCK_STREAM,
	    proto => 'tcp',
	    PeerPort => $port,
	    PeerHost => $host,
	    Reuse => 1,
	    );
	if (!$socket) {
	    print STDERR "Can't open client socket $port: $!\n";
	    } # return undefined below
    }

    return $socket;
    } # newSocket

1;
