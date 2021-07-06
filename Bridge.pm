use strict; 
use warnings;

package Bridge; # https://de.wikipedia.org/wiki/Bridge_%28Kartenspiel%29

# Subroutines for PC.pl
my $test=1;

sub getConfig { # Create playing card symbols 
    my $table=shift;
# Configuration subroutine for playing cards with PC.pl and PC.html
    #my ($conf) = @_; # reference to configuration hash
    my $conf=$table->{config};

    $conf->{'game'}='Bridge'; 
    # Variables with a-zA-z only, optionally with - or _ plus any characters
    # will be shared with PC.html.
    # Variables with _XX (X=any character) denote playing cards and other
    # symbols, which are displayed with UTF codes, have a help (title) text, 
    # and are normally clickable.
#
    #$conf->{'lastIsHigher'}=".."; # (regex) same cards in trick: last is higher
    #$conf->{'nDecks'}=2;
    $conf->{'CPA'}=1;	# =1: announcements (in T=0) only from current player
    $conf->{':SUMM'}='POS0:PC:&games()'; # do not show other optional parts
	# show at 0 position of summary (variable:help)
    $conf->{'AUTO'}=''; # nothing automatically
    $conf->{'cardValues'}=0; # do not add trick's card values
    $conf->{'cardval-A'}=4; # used to add High-Card-Points (HCP)
    $conf->{'cardval-K'}=3;
    $conf->{'cardval-Q'}=2;
    $conf->{'cardval-J'}=1;
    $conf->{'MAXRP'}=4;	# maximum number of registered players
    $conf->{'MAXCP'}=4;	# maximum number of current players
    $conf->{'MINCP'}=4;	# minimum number of current players
    $conf->{'CPP'}=13;	# number of cards per player
    $conf->{'checkAnn'}=1;
    $conf->{'cardSequence'}='AKQJ198765432'; #Ace,King,Queen,Jack,10,9,8,7,...
    $conf->{'stdTrump'}="Sn"; # no trump
    $conf->{'SORT'}="Sn";
    # Card specification with UTF code for the html part
    # carId;hex UTF code;help text;color#comment
    #		(color : optional, default 0=black)
    # Miscellaneous:
    $conf->{'Local_uu'}='1F0A1;change utf/image card presentation'; # ace of spades
    $conf->{'Symbol_gm'}='1F309;Bridge';
    # Announcements: #  1-7
    $conf->{'Ann_Nx'}='261E;pass;0'; # => hand
    $conf->{'Ann_Ko'}='2694;double;1'; # red crossing swords
    $conf->{'Ann_Re'}='2694;redouble;6'; # blue crossing swords
    $conf->{'colorNames'}.=',&noTrump()';
    my @brCol=split(",",$conf->{'colorNames'});
    my $bidButtons="NxKoRe";
    my @bidCols=(3,2,1,0,4);
    my $tmpMsg="";
    foreach my $i (1..7) { 
	$bidButtons.="/";
	my $tricks=$i+6;
	my $t=($i==1 ? "X" : "$i");
	$tmpMsg.=join("",@bidCols)." i$i,t$t:";
	foreach my $col (@bidCols) { # foreach (3,2,1,0,4) does not work !
	    my $brCol=$brCol[$col]; my $uCol=substr("ABCDn",$col,1);
	    $tmpMsg.="$col$uCol";
	    my $col_=($uCol eq "n" ? 0 : $col);
	    $conf->{'Ann_'."$uCol$t"}="I1F0$uCol$t-$col_.png;"
		."&nTricks($tricks,$brCol)";
	    $bidButtons.="$uCol$t";
	    }
	}
    $conf->{'bidButtons'}=$bidButtons;
    print "*Br: bidButtons=$bidButtons $tmpMsg\n" if $test;
    return 1;
  } # getConfig

sub setMsg {
    my $table=shift;
    my ($msg) = @_;
    
    $msg->{'toBid'}='still to bid $1';
    $msg->{'nTricks'}='$1 tricks ($2)';
    
    } # setMsg

sub checkCards { # returns buttons or info about the cards
    my $table=shift;
    my ($POS) = @_;
    
    foreach my $P (split("",$POS)) {
	my $cards=$table->get("H.$P") || "";
	my $cardPoints=$table->cardPoints($cards);
#	foreach ('A:4','K:3','Q:2','J:1') {
#	    my ($card,$pts)=split(":",$_);
#	    $cardPoints+=PC::cardIsIn(".$card",$cards,0)*$pts;
#	    }
#	#if ($cardPoints>0) {
	    $table->set("B.$P","[$cardPoints HCP]");
#	 #   }
	print "*checkCards: $cards : $cardPoints\n";
	}
    return 1;
    } # checkCards

sub announcement {
    my $table=shift;
    my ($param) = @_; # "$cardId $myP"
    
    my ($cardId,$myP)=split(" ",$param);
    $table->set("A$myP","./".$cardId); 
    return 0 if $cardId eq "Nx"; # pass
    my $T0B0=$table->{'T0B'};
    $table->set('C',$param);
    my ($T0B,$tmp)=split("/",$T0B0); # 1st line: pass, ...
    $T0B.="/".substr($T0B0,index($T0B0,$cardId)+2);
    $T0B=~s/\/\//\//g; # replace double slash by slash
    $table->set('T0B',$T0B);
    return 0;
    } # announcement

sub setContract { # to be called in dealCards
    my $table=shift;
    
    my $masterOpt=$table->get('masterOpt') || "";
    $table->set('NCP',$table->get('NP'));
	#$table->set('CPP',13);
    my $bidButtons=$table->{'bidButtons'};
	$table->set('T0B',$bidButtons);
	$table->set('TxB',"");
    $table->set('masterOpt',"") if $masterOpt;
    $table->set('VIS',""); 
    $table->set('P',"");
    #$table->set('P',0); # partner
    return 1;
    } # setContract

sub checkContract { # called with 'ok'
    my $table=shift;
    
    my $NCP=$table->get('NCP') || $table->get('NP') || 1;
    my $msg="";
    for (my $P=1; $P<=$NCP; $P++) {
	my $A=$table->get("A$P") || "";
	$msg.=" ".$table->get("N$P") if $A eq "";
	}
    if ($msg ne "") {
	$table->set('MSG..',"ERR=[&toBid(".substr($msg,1).")]");
	return -1;
	}
    my $C=$table->get('C') || $table->get('highestA');
    my ($highest,$lead)=split(" ",$C);
    my $X=($lead)%4+1;
    $table->set('X',$X);
    $table->set('TM',$highest);
    my $trump=substr($highest,0,1);
    $trump=substr("0123n",index("ABCDn",$trump),1);
    $table->set('SORT',"S$trump");
    my $partner=($lead+1)%4+1;
    $table->set('P',"$lead$partner!");
    $table->set('VIS',"(1,1) $partner:1234");
    $table->set('SUBS',"$partner:$lead"); # lead plays as substitute for partner
    return 1;
    } # checkContract

sub gamePoints {
    my $table=shift;
    
    my $POS=$table->get('POS') || "";
    my $C=$table->get('C'); my $P_=$table->get('P');
    my $tricksWon=0;
    foreach my $P (split("",$POS)) {
	next unless index($P_,$P)>=0;
	my $w=$table->get("W$P") || 0; 
	$tricksWon+=$w;
	}
    my $tgt=substr($C,1,1);
    $tgt=1 if $tgt eq "X";
    my $diff=$tricksWon-6-$tgt;
    my $msg=substr($C,0,2)."[<b>";
    $msg.="+" if $diff>0;
    $msg.="$diff</b>]";
    $table->set('MSG',$msg);
    return "";
    } # gamePoints

1;
