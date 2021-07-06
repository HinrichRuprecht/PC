use strict; 
use warnings;

package OhHell; # https://en.wikipedia.org/wiki/Oh_Hell
		# https://de.wikipedia.org/wiki/Stiche-Raten (Teufelsskat)
		# https://www.spielwiki.de/Stiche-Raten
		# https://www.pagat.com/de/exact/ohhell.html
# Subroutines for PC.pl

sub getConfig { # Create playing card symbols 
    my $table=shift;
# Configuration subroutine for playing cards with PC.pl and PC.html
    #my ($conf) = @_; # reference to configuration hash
    my $conf=$table->{config};

    $conf->{'game'}='OhHell'; #Teufelsskat,Whist,Ansagen,...
    # Variables with a-zA-z only, optionally with - or _ plus any characters
    # will be shared with PC.html.
    # Variables with _XX (X=any character) denote playing cards and other
    # symbols, which are displayed with UTF codes, have a help (title) text, 
    # and are normally clickable.
#
    $conf->{'lastIsHigher'}=".."; # (regex) same cards in trick: last is higher
    $conf->{'maxCPP'}=7;
    $conf->{'addCPP'}=1;
    $conf->{'nDecks'}=2;
    $conf->{'CPA'}=1;	# =1: announcements (in T=0) only from current player
    $conf->{':SUMM'}='POS0:PC:&games()'; # do not show other optional parts
	# show at 0 position of summary (variable:help)
    $conf->{'AUTO'}=''; # nothing automatically
    $conf->{'cardValues'}=0;
    $conf->{'checkAnn'}=1;

    # Card specification with UTF code for the html part
    # carId;hex UTF code;help text;color#comment
    #		(color : optional, default 0=black)
    # Announcements: # circled 0..9
    $conf->{'Ann_A0'}='1F10B;0 &tricks()';
    $conf->{'Ann_A1'}='02460;1 &trick()';
    foreach my $i (2..9) { $conf->{'Ann_'."A$i"}="0246".($i-1).";$i &tricks()"; }
    # Master buttons (special setup)
    my $buttons="CpCm";
    $conf->{'Master_Cp'}='2295;plus 1 card;3'; # circled + : sets 'addCPP'
    $conf->{'Master_Cm'}='2296;minus 1 card;3'; # circled -
    foreach my $i (1..9) {
	$conf->{'Master_'."C$i"}="24F".sprintf("%1X",($i+4)).";$i &cards();3"; 
	$buttons.="C$i"; # sets 'CPP' (and 'maxCPP' if CPP > maxCPP
	}
    $conf->{'masterButtons'}.=$buttons; # sepcial buttons for table master
    # Trump colors:
    $conf->{'Symbol_S0'}='2660;&spades();0';
    $conf->{'Symbol_S1'}='2665;&hearts();1';
    $conf->{'Symbol_S2'}='2666;&diamonds();2';
    $conf->{'Symbol_S3'}='2663;&clubs();3';
    # Result:
    $conf->{'Symbol_G1'}='1F47A;as announced;0'; # japanese goblin
    $conf->{'Symbol_G0'}='1F479;&(wrong);0';
    # Miscellaneous:
    $conf->{'Local_uu'}='1F0D1;change utf/image card presentation;3'; # club ace
    $conf->{'Symbol_gm'}='1F479;OhHell'; # japanese ogre
    #print "++++++++++++++++\n";
  } # getConfig

sub setMsg {
    my $table=shift;
    my ($msg) = @_;
    
    $msg->{'change1'}='you may only change by +/- 1';
    
    } # setMsg

sub announcement { 
    # returns: undef : error / no change, 1 : -> "ok", 0 : -> next player
    my $table=shift;
    my ($param) = @_; # "$cardId $myP"
    
    my ($cardId,$myP)=split(" ",$param);
    my $prevA=$table->get("A$myP") || "";
    if ($prevA) {
	my $diff=substr($prevA,1,1)-substr($cardId,1,1);
	if ($diff>1 || $diff<-1) {
	    $table->set("M.$myP","[&change1()]");
	    return -1;
	    }
	$prevA.="/";
	}
    $table->set("A$myP",$prevA.$cardId); 
    if ($prevA ne "") { # 2nd announcement of 1st player
	return 2;
	}
    else { return 0; }
    } # announcement

sub setContract { # to be called in dealCards
    my $table=shift;
    
    my $masterOpt=$table->get('masterOpt') || "";
    $table->set('NCP',$table->get('NP'));
    # number of cards to deal
	my $PC=$table->get('PC') || 1;
	my $CPP=$table->get('CPP') || $PC;
	my $maxCPP=$table->get('maxCPP') || $table->get('maxCPP.X') || 7;
	$CPP=1 if $PC==1;
	if ($masterOpt) {
	    my @tmp=(split(",",$masterOpt));
	    do { $masterOpt=shift(@tmp); } until $masterOpt || scalar @tmp==0;
	    }
	if ($masterOpt=~/C(\d)/) { 
	    $CPP=$1; 
	    $table->set('maxCPP',$CPP) if $CPP>$maxCPP;
	    }
	else {
	    if ($masterOpt=~/C([mp])/) 
		{ $table->set('addCPP',($1 eq "m" ? -1 : 1),2); }
	    if ($CPP>$maxCPP) 
		{ $CPP=$maxCPP-1; $table->set('addCPP',-1); }
	    elsif ($CPP<=0)
		{ $CPP=1; $table->set('addCPP',1); }
	    else { $CPP+=$table->get('addCPP'); }
	    }
	$table->set('CPP',$CPP);
	my $bidButtons="A0";
	for my $i (1..$CPP) { $bidButtons.="A$i"; }
	$table->set('T0B',$bidButtons);
    # set random trump
	my @tmp=PC::shuffle(4); 
	my $trumpCol=$tmp[0]-1;
	$table->set('MSG',".&isTrump(S$trumpCol)",2); # .=add to MSG
	$table->set('SORT',"S$trumpCol");
	$table->set('TM',"S$trumpCol");
    # test settings:
    if ($table->{test}==2) {
	$table->set('VIS',"2:134"); # test (1,1) 
	$table->set('P',"12!"); # test : 1 must play for 2
	}
    print STDOUT "*setContract: PC=$PC CPP=$CPP Tr=$trumpCol m=$masterOpt\n";
    $table->set('masterOpt',"") if $masterOpt;
    } # setContract

sub checkContract { # called with 'ok'
    my $table=shift;
    
    my $POS=$table->get('POS') || "";
    my $msg="";
    foreach my $P (split("",$POS)) {
	my $A=$table->get("A$P") || "";
	$msg.=",".$table->get("N$P") if $A!~/A\d/;
	}
    if ($msg ne "") {
	$table->set('MSG..',"[ERR=&toBid(".substr($msg,1).")]");
	return -1;
	}
    return 1;
    } # checkContract

sub checkOK { # called when all have placed
    my $table=shift;
    my ($param) = @_; 
    
    my ($cardId,$myP,$N)=split(" ",$param); # N=next player
#    my $a=$table->get("A$N");
#    if ($a && $a=~/A(\d)$/) { # last announcement
#	my $a=$1;
#	my $bidButtons="A$a";
#	my $CPP=$table->get('CPP');
#	if ($a<$CPP) { $bidButtons.="A".($a+1); }
#	if ($a>0) { $bidButtons="A".($a-1).$bidButtons; }
#	$table->set('T0B',$bidButtons,2);
#	$table->set("B.$myP","ok");
#	}
    $table->set("M.$N","[&pleaseCheckOrChange()!]");
    return 1;
    } # checkOK

sub gamePoints {
    my $table=shift;
    
    my $POS=$table->get('POS') || "";
    my $gp=""; my $right=""; my $wrong="";
    foreach my $P (split("",$POS)) {
	$gp.=",$P:";
	my $w=$table->get("W$P") || 0; 
	my $a=$table->get("A$P");
	my $name=$table->get("N$P");
	if ($a && $a=~/A$w$/) { # last announcement
	    $gp.="1$w:(1$w)";
	    $right.=",$name";
	    }
	else { $gp.="0:(--$w)"; $wrong.=",$name"; }
	}
    my $msg=($right ? "G1[".substr($right,1)."]/" : "");
    if (!$msg && $wrong) { $msg.="G0[".substr($wrong,1)."]"; }
    $table->set('MSG',$msg);
    return substr($gp,1);
    } # gamePoints

1;
