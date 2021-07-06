use strict; 
use warnings;

package Doppelkopf; # https://en.wikipedia.org/wiki/Doppelkopf

# Subroutines for PC.pl
use FindBin;               # locate this script
use lib "$FindBin::Bin/";  # and use its directory as source of packages

use PC;
my $test=1;

sub getConfig { # Create playing card symbols 
    my $table=shift;
# Configuration subroutine for playing cards with PC.pl and PC.html
    #my ($conf) = @_; # reference to configuration hash
    my $conf=$table->{config};

    $conf->{'game'}='Doppelkopf'; 
    # Variables with a-zA-z only, optionally with - or _ plus any characters
    # will be shared with PC.html.
    # Variables with _XX (X=any character) denote playing cards and other
    # symbols, which are displayed with UTF codes, have a help (title) text, 
    # and are normally clickable.
#
    $conf->{'CPP'}=12;
    # KrBube(Karlchen),Fuchs,H10,>=40 card points
    $conf->{'rkBonus'}="+2"; # bonus for 're' and 'kontra'
    $conf->{'EXCHG..'}=""; # used to exchange cards for Armut
    $conf->{'NCP'}=4;
    $conf->{'nDecks'}=2;
    $conf->{'cardSequence'}='A1KQJ9'; #Ace,10,King,Queen,Jack,9
    $conf->{'cardval-9'}=0; # other values in PC.pm (default is 9)
    my $stdTrumps='11,3Q,0Q,1Q,2Q,3J,0J,1J,2J,';
    $conf->{'trumps-S2'}=$stdTrumps.'2A,21,2K,29,'; # Std. H10...
    $conf->{'trumps-S3'}=$stdTrumps.'3A,31,3K,39,'; # ... Clubs
    $conf->{'trumps-S0'}=$stdTrumps.'0A,01,0K,09,'; # ... Spades
    $conf->{'trumps-S1'}=$stdTrumps.'1A,1K,19,'; # ... Hearts
    $conf->{'trumps-SQ'}='3Q,0Q,1Q,2Q,'; # Queens
    $conf->{'trumps-SJ'}='3J,0J,1J,2J,'; # Jacks
    $conf->{'trumps-SN'}=''; # Trump solo / fleischlos -> no trump
    $conf->{'stdTrump'}='S2';
    $conf->{'sorted-..'}=',.A,.1,.K,.Q,.J,.9,'; # do not start with "." !!!
    $conf->{'CPA'}=1;	# =1: announcements (in T=0) only from current player
    $conf->{':SUMM'}='POS0:PC:&games()'; # do not show other optional parts
	# show at 0 position of summary (variable:help)
    # from PC.pm: $conf->{':AUTO'}=''; # ='' : nothing automatically
    $conf->{'help-pt'}="";
    $conf->{'checkAnn'}=1;
    $conf->{'Pc_11'}='1F0BA;2nd hearts-10 higher than 1st ?;1';
    $conf->{'Pc_3J'}='1F0DB;Charlie ?;3';
    $conf->{'Pc_2A'}='1F0C1;Fox;2';
    my $RD=$table->{'RD'} || 0;
    my $cardSequence=$table->{'cardSequence'}
	    || $table->{'cardSequence.X'} || $conf->{'cardSequence'};
    $RD=1 if !$RD && index($cardSequence,"9")<0;
    my @reDeal=('5 &nines():5:09,19,29,39', # 5 nines
	    '5 &kings():5:0K,1K,2K,3K', # 5 kings
	    '3 &nonTrump() &kings():3:0K,1K,3K');   # 3 non-trump kings
    my $RD_=$reDeal[$RD] || "";
    my ($rdMsg,$tmp)=split(":",$RD_);
    $conf->{'Server_Rd'}='267A;new cards '.$rdMsg;
    $conf->{'RD..'}=$RD_;
    $conf->{'rules'}="11,3J,2A,Dk,Rd";
    $conf->{'lastIsHigher'}="11"; # (regex) (effective only with 'rules')

    # Card specification with UTF code for the html part
    # carId;hex UTF code;help text;color#comment
    #		(color : optional, default 0=black)
# Announcements:
    $conf->{'Ann_HZ'}='26AD;marriage;4'; # marriage symbol
    $conf->{'Symbol_Hz'}='26AD;marriage partner;5';
    $conf->{'Ann_AR'}='2639;poverty;4'; # frowning (poverty)
    $conf->{'Ann_Ar'}='263A;poverty partner;4'; # smiling (rich part of poverty)
    $conf->{'Ann_A0'}='2660;spades solo;1'; # spades
    $conf->{'Ann_A1'}='2665;hearts solo;1'; # hearts
    $conf->{'Ann_A2'}='2666;diamonds solo;1'; # diamonds
    $conf->{'Ann_A3'}='2663;clubs solo;1'; # clubs
    $conf->{'Ann_AQ'}='265B;queens solo;1'; # chess queen  
    $conf->{'Ann_AJ'}='265D;jacks solo;1'; # chess bishop (jack solo)
    $conf->{'Ann_AN'}='2691;ace solo;1'; # flag (trump solo)
# Bids:
    $conf->{'Ann_B1'}='2694;double;4'; # crossed swords 
    $conf->{'Ann_B2'}='2694;counter-double;2';
    $conf->{'Ann_B9'}='1F0D9;no 90!;1'; # 9 of clubs
    $conf->{'Ann_B6'}='1F0D6;no 60!;1';
    $conf->{'Ann_B3'}='1F0D3;no 30!;1';
    $conf->{'Ann_B0'}='1F0DF;schwarz!;1'; # white joker (green)
# Sort:
    #$conf->{'Sort_SS'}='26D7;zeigt Sortier-Buttons'; # two way (sort)
    $conf->{'Sort_ss'}='24C8;Solo : klick solo symbol first;7';
    #$conf->{'Sort_ss'}='24C8;Solo entsprechend der Sortierung;1';
    $conf->{'Sort_S0'}='2660;sort for spades solo;0'; # see solos
    $conf->{'Sort_S1'}='2665;sort for hearts solo;1';
    $conf->{'Sort_S2'}='2666;sort for diamonds solo;2';
    $conf->{'Sort_S3'}='2663;sort for clubs solo;3';
    $conf->{'Sort_SQ'}='2655;sort for queens solo;0';
    $conf->{'Sort_SJ'}='2657;sort for jacks solo;0';
    $conf->{'Sort_SN'}='2690;sort for no trumps solo;0'; 
    $conf->{'Symbol_0T'}='2618;middle of table;0'; # Kleeblatt
    $conf->{'Ann_Nx'}='261E;next/pass;0'; # => hand
    $conf->{'Ann_Vb'}='26A0;reservation;2'; # 'special/reservation' 
    $conf->{'Symbol_Dk'}='324B;Doppelkopf (>=40);1'; # circled 40 on black square
    $conf->{'Ann_Lh'}='24C1;show my cards to ...;3'; # L=learner
# result symbols:
    $conf->{'Symbol_G2'}='1F3C6;against the elders;2';
    $conf->{'Symbol_K9'}='1F0D9;no 90;0'; # 9 of clubs
    $conf->{'Symbol_K6'}='1F0D6;no 60;0';
    $conf->{'Symbol_K3'}='1F0D3;no 30;0';
    $conf->{'Symbol_K0'}='1F0DF;schwarz;0'; # white joker (green)
    $conf->{'Symbol_G9'}='1F0D9;>=90;3'; # 9 of clubs
    $conf->{'Symbol_G6'}='1F0D6;>=60;3';
    $conf->{'Symbol_G3'}='1F0D3;>=30;3';
    $conf->{'Symbol_G0'}='1F0DF;not schwarz;3'; # white joker (green)
    # Miscellaneous:
    $conf->{'Local_uu'}='1F0DD;change utf/image card presentation;3'; # club queen
    $conf->{'Symbol_gm'}='1F465;Doppelkopf';

  } # getConfig

sub setMsg {
    my $table=shift;
    my ($msg) = @_;
    
    $msg->{'nonTrump'}='non-trump';
    $msg->{'helpPt'}='eg. K3 : contra with 3 points, '
	.'R-1 : elders won, but negative result because of point deduction';
    $msg->{'povertyPartner'}='$1 is]AR[partner of $2';
    $msg->{'changeCards'}='change cards of $1';
    $msg->{'povertyOpen'}='$1 plays poverty and looks for';
    $msg->{'povertyComplete'}='poverty complete $1 : $2';
    $msg->{'trumpsReturned'}='$1 trumps returned';
    $msg->{'playerPlays'}='$1 plays';
    
    } # setMsg

sub checkCards { # returns buttons for special combinations of cards
    my $table=shift;
    my ($POS) = @_;
    
    my $trumps=$table->get('trumps-S2');
    my $re="";
    my ($hint,$occ,$chkCards);
    $chkCards=$table->get('RD..') || "";
    if ($chkCards ne "") {
	($hint,$occ,$chkCards)=split(":",$chkCards);
	}
    foreach my $P (split("",$POS)) {
	my $cards=$table->get("H.$P") || "";
	my $buttons="";
	if ($chkCards) {
	    my $cnt9=PC::cardIsIn($chkCards,$cards,0);
	    $buttons.=",Rd"."[$hint]" if $cnt9>=$occ; # 5 nines or kings
	    }
	$buttons.=",AR" if PC::cardIsIn( $trumps,$cards,0)<=3; # poverty
	my $n3Q=PC::cardIsIn("3Q",$cards,0);
	if ($n3Q>0) {
	    $buttons.=",HZ" if $n3Q==2; # wedding
	    $re.=$P;
	    }
	if ($buttons) 
	    { $table->set("B.$P",substr($buttons,1)); }
	# print "*checkCards: $cards : $buttons\n";
	}
    $table->set("Re..",$re);
    return 1;
    } # checkCards

sub announcement { 
    # returns: undef/-1 : error / no change, 1 : no advance, 0 : next player
    #		2 : start play (from Doko_Armut)
    my $table=shift;
    my ($param) = @_; # "$cardId $myP"
    
    my ($cardId,$myP)=split(" ",$param);
    my $res;
    my $C=$table->get('C') || "";
    my $prevA=$table->get("A$myP") || "";
    print "*announcement: $cardId from $myP\n" if $test>0;
    if (uc($cardId) eq "AR") {
	return Doko_Armut($table,$myP,$C,$cardId);
	}
    elsif ($C ne "" && $cardId!~/^(B|Nx)/) { # should not occur
	$table->set("M.$myP","[&noMoreBids()]"
	    ."/".substr($C,0,2)."[&active()]");
	$res=-1; 
	}
    else {
	my $T=$table->get('T');
	if ($prevA && $T==0) { $prevA=""; } # .= ?
	$table->set("A$myP",$prevA.$cardId);
	$table->set('MSG',"./[§$myP ]".$cardId);
	$res=0;
	}
    return $res;
    } # announcement

sub Doko_Armut {
    my $table=shift;
    my ($myP,$C,$cardId) = @_;
    # returns: see announcement

    my $res=1;
    my ($changeCards,$newCards); my $msg="";
    my $cards=$table->get("H.$myP");
    my $exchg=$table->get('EXCHG..');
    my $Pp; # poverty player
    if ($cardId eq "AR") { # 1st call from poverty player
	my $trumps=$table->get('trumps-S2');
	($changeCards,$newCards)=PC::cardIsIn( $trumps,$cards,3);
	}
    elsif ($cardId eq "Ar") { # partner
	$Pp=substr($C,2,1);
	$table->set('MSG',"[&povertyPartner(§$myP,§$Pp)]");
	$table->set("A.$myP","Ar");
	$table->set('C',"AR$Pp$myP");
	$newCards=$cards.",".$exchg;
	$msg="[&changeCards(§$Pp): ]".$exchg;
	$changeCards="";
	$exchg="";
	}
    else {
	$newCards=PC::cardIsIn( $cardId,$cards,3);
	$changeCards=$cardId;
	}
    $exchg.=",".$changeCards if $changeCards ne "";
    $table->set("H.$myP",$newCards);
    $exchg=~s/\,\,/,/g; # replace double ','
    if ($C eq "") { $C="AR$myP"; $table->set('C',$C); }
    $table->set('EXCHG..',$exchg);
    if (length($exchg)<9) { # <3 cards
	$msg.=$exchg."/[&pleaseClickChangeCard()]";
	#$res=1;
	}
    elsif (length($C)<4) { # poverty player, 3 cards in EXCHG
	$table->set("A$myP","AR");
	$table->set('MSG',"[&povertyOpen(§$myP)]Ar");
	$res=0;
	my $pos=$table->get('POS');
	foreach my $P (split("",$pos)) {
	    if ($P!=$myP) {
		$table->set("A$P","");
		$table->set("T$P","");
		$table->set("B.$P","Ar");
		}
	    }
	}
    else { # partner : finish exchange of cards
	$Pp=substr($C,2,1);
	$table->set("H.$Pp",".".$exchg);
	$table->set("M.$Pp","[&changeCards(§$myP)]".$exchg);
	$table->set('EXCHG..',"");
	$msg="[&povertyComplete()]ARAr";
	if (my $tmp=PC::cardIsIn( $cardId,$table->get('trumps-S2')))
	    { $msg.="/[&trumpsReturned($tmp)]"; }
	$table->set('MSG',$msg);
	$table->set("A$myP","Ar");
	$msg="";
	$res=3; # start trick
	}
    $table->set("M.$myP",$msg) if $msg ne "";
    return $res;
    } #  Doko_Armut

sub setContract { # to be called in dealCards
    my $table=shift;
    
    my $masterOpt=$table->get('masterOpt') || "";
    # buttons for announcements (before 1st trick) or bids (after start)
    $table->set('T0B',"NxVb/ssS0S1S2S3SQSJSN",2);
    $table->set('TxB',"B1B2B9B6B3B0",2);
    # print STDOUT "*setContract: m=$masterOpt\n";
    $table->set('masterOpt',"") if $masterOpt;
    } # setContract

sub checkContract { 
    # called with 'ok', and to check additional input for contracts
    # result: 1 = advance to next player, 0 = no advance, -1 = error
    my $table=shift;
    my ($param)=@_;
    
    $param="" unless defined($param);
    $table->printLog("checkContract($param)\n",1) if $table->{test}>3;
    if ($param ne "") { # additional card for contract
	my ($cardId,$myP)=split(" ",$param);
	$table->printLog("*checkContr: error par=$param\n",1) 
	    unless $cardId && $myP && length($cardId)<=3;
	my $T=$table->get('T') || 0;
	if ($T==0) { # poverty ?
	    my $C=$table->get('C');
	    if (uc(substr($C,0,2)) ne "AR" || substr($C,2)!~/$myP/
		    || $cardId!~/[0-3][\w\d]/) { # only playing card accepted
		$table->set("M.$myP","[&error()]");
		return -1;
		}
	    my $res=Doko_Armut($table,$myP,$C,$cardId);
	    #$table->printLog("checkContract->$res\n",1) if $table->{test}>3;
	    return $res;
	    }
	else { # $T>0
	    return 0;
	    }
	}
    my $msg=""; my $C_="";
    for my $P (split("",$table->get('POS'))) {
	my $A=$table->get("A$P") || "";
	$msg.=" ".$table->get("N$P") if $A eq ""; #!~/(Nx|Vb|S.)/;
	$C_.=",$1$P" if $A=~/(..)$/ && $1 ne "Nx"; 
	}
    if ($msg ne "") {
	$table->set('MSG..',"ERR=[&toBid(".substr($msg,1).")]");
	return -1;
	}
    my $specialPoints=$table->get('rules') || "";
    $table->set('lastIsHigher',(index($specialPoints,"11")>=0?"11":""));
    if ($C_ ne "") { # solo, ...
	$C_=substr($C_,1); # discard 1st comma
	my @C=split(",",$C_);
	if (scalar @C==1) { 
	    my $P=substr($C_,2); my $c=substr($C_,0,2);
	    if ($c eq "AR") {
		$table->set('MSG',"[&povertyNoPartner(§$P)]");
		return 2; # new cards
		}
	    else {
		$table->set('MSG',"[&playerPlays(§$P)]$c");
		# solo, HZ ??
		if (substr($c,0,1) eq "S") { # solo
		    $table->set('X',$P); 
		    $table->set('SORT',$c);
		    $table->set('lastIsHigher',"") if substr($c,1,1)=~/[QJN]/;
		    }
		}
	    $table->set('C',$C_);
	    }
	else { # more than one announcement
	    $msg="[&whoPlays()? ]";
	    foreach my $a (@C) {
		my $P=substr($a,2);
		$msg.=",[§$P : ]".substr($a,0,2);
		}
	    $table->set('MSG',$msg);
	    return -1;
	    }
	}
    return 1;
    } # checkContract

sub completeTrick {
    my $table=shift;
    my ($param) = @_;
    
    my ($winP,$CT,$X,$cardPoints)=split(",",$param);
    my $T=$table->get('T') || 0; 
    my $POS=$table->get('POS');
    my $posX=index($POS,$X) || 0;
    if ($posX>0) # shift positions : $X (1st in trick) is a POS0
	{ $POS=substr($POS,$posX).substr($POS,0,$posX); }
    my $pts="";	
    my $C=$table->get('C') || "";
    my $msg="*C:$C ";
    if (substr($C,0,1) ne "S") { # no solo
      my $specialPoints=$table->get('rules') || "";
      $msg.="*sp:$specialPoints *cp=$cardPoints";
      if ($specialPoints) {
	$specialPoints=~s/\,/|/g; 
	    #if index($specialPoints.",")>=0;
        if ($CT=~/($specialPoints)/) {
	  for (my $i=0; $i<8; $i+=2) {
	    my $cardId=substr($CT,$i,2);
	    if ($cardId=~/($specialPoints)/) {
		#my $spec=$1;
		$msg.="+".$cardId;
		    my $P=substr($POS,$i/2,1); # i/2=position of card's player
		if ($cardId eq "3J") { # Karlchen wins last trick ?
		    next if $P ne $winP || $T<$table->get('CPP');
		    }
		else { 
		    next if $P==$winP; # not caught from other player
		    $cardId.="[/§$P]"; # to be replaced by player's name
		    }
		$pts.=$cardId."/";
		}
	    }
	  }
        $pts.="Dk/" if $cardPoints>=40 && $specialPoints=~/Dk/;
	}
      if ($pts ne "") {
	    my $A=$table->get("A$winP") || "";
	    $A.="/" if $A ne "";
	    $A.=$pts;
	    $A=~s/\/\/+/\//g; # remove multiple '/' (used for newline)
	    $table->set("A$winP",$A);
	    }
      }
    $table->printLog("*completeTrick($param) m=$msg p=$pts\n")
	if $table->{test}>3;
    if ($T<=3) {
	my $hzP=substr($C,2,1);
	if (substr($C,0,2) eq "HZ" && length($C)<4) {
	    if ($hzP ne $winP 
		&& !PC::cardIsIn(substr($CT,0,2),$table->{'trumps-std'})) {
		$table->set("C",".$winP");
		$table->set('MSG',"./[ §$winP spielt mit §$hzP]Hz");
		$table->set("A$winP","Hz");
		$table->set("Re..","$hzP$winP");
		}
	    elsif ($T==3) {
		$table->set('MSG',"./[ §$hzP spielt alleine]HZ");
		$table->set("Re..","$hzP$hzP");
		}
	    }
	}
#    else {
#	my $CPP=$table->get('CPP') || 0;
#	$table->gamePoints() if $T>=$CPP; # if not yet in nextTrick
#	}
    return 1;
    } # completeTrick

sub gamePointsDK {
    my ($rePts,$rSpec,$kSpec,$rkBonus,$specialPoints) = @_;
    # $rePts : [Sx]sum of card points for Re (prefix Sx for solos with type)
    #	schwarz: set to 241 if kontra won no tricks (or -1 for re)
    $rSpec="" unless $rSpec; # announces, bids, special points for Re
    $kSpec="" unless $kSpec; # announces, bids, special points for Ko
    $rkBonus="+2" unless $rkBonus; 
	# add / multiplication operation for re/kontra announcement
	    # for the winner points (w/o the special points)

    my $msg=""; my $res=""; my $res2=""; my $winner=0;
    my $solo=""; if ($rePts=~/^(A.)(.*)/i) { $solo=$1; $rePts=$2; }
    my $koPts=240-$rePts;
    my $rGP=""; my $kGP=""; 
    if ($rSpec!~/A[QJN0123]/ && $kSpec!~/A[QJN0123]/) { # no solo
	while ($rSpec=~/($specialPoints)/) 
	    { $rGP.=$1; my $t=$1; $t=~s/\*/\\*/; $rSpec=~s/$t//; }
	while ($kSpec=~/($specialPoints)/) 
	    { $kGP.=$1; my $t=$1; $t=~s/\*/\\*/; $kSpec=~s/$t//; }
	}
    my $rTgt=121; my $rTgt2=-1; my $kTgt2=-1;
    if ($rSpec=~/B[10369]/) {
	foreach ('0','3','6','9')
	    { if ($rSpec=~/B$_/) 
		{ $rTgt2=$_*10; $rTgt=240-$rTgt2+1; last; } }
	}
    elsif ($kSpec=~/B[20369]/) { $rTgt=120; } # reduce later
    my $kTgt=240-$rTgt+1; 
    if ($kSpec=~/B[0369]/) {
	if ($rTgt2>=0) { $kTgt=$rTgt2; }
	foreach ('0','3','6','9')
	    { if ($kSpec=~/B$_/) 
		{ $kTgt2=$_*10; $kTgt=240-$kTgt2+1; last; } }
	if ($rTgt==120) { $rTgt=$kTgt2; }
	}
    my $gp0=0; my $gp1=0; my $gp2=0; my $gw=0;
    if ($rePts>=$rTgt) { # re won
	$winner="R"; $gw=1; $res2="G1";
	}
    elsif ($koPts>=$kTgt) { # kontra won
	$winner="K"; 
	if ($solo) { $gw=1; $res2="G1"; }
	else { $gw=2; $res2="G1G2"; }
	($kTgt2,$rTgt2)=($rTgt2,$kTgt2); 
	($kTgt,$rTgt)=($rTgt,$kTgt);
	($koPts,$rePts)=($rePts,$koPts); 
	($kGP,$rGP)=($rGP,$kGP);
	}
    else {
	$winner="r";
	$msg=" / weder ko>=$kTgt noch re>=$rTgt aber ";
	if ($koPts>$rePts) {
	    $winner="k";
	    ($kTgt2,$rTgt2)=($rTgt2,$kTgt2); 
	    ($kTgt,$rTgt)=($rTgt,$kTgt);
	    ($koPts,$rePts)=($rePts,$koPts); 
	    ($kGP,$rGP)=($rGP,$kGP);
	    $msg.="ko>re";
	    }
	else { $msg.="re>ko"; }
	$msg=$winner.$msg;
	}
    if ($winner=~/[RK]/) {
	#if ($solo ne "") { $gw=1; $res2=$solo; }
	$msg=$winner." gewinnt (>=$rTgt)"; 
	if ($koPts<119) { $gp0=int((119-$koPts)/30); }
	$rTgt2=$kTgt2 if $kTgt2>=0 && ($rTgt2<0 || $rTgt2>$kTgt2);
	$gp1=int((120-$rTgt2)/30) if $rTgt2>=0; # just for announcement
	my $tmp=($rePts>120?120:$rePts);
	$gp2=int(($tmp-$kTgt2)/30) if $kTgt2>=0; # got > announced
	}
    else { 
	$gp0=int((119-$koPts)/30); 
	$gp1=-int(($koPts-$kTgt2)/30) if $koPts>$kTgt2;
	}
    if ($gp0>0) { $res2.=substr("K9K6K3K0",0,$gp0*2); }
    if ($gp2<0) { $res2.=substr("G9G6G3G0",0,$gp2*2); }
    $res2.=substr("B9B6B3B0",0,$gp1*2) if $gp1>0;
    $res="($gw+$gp0+$gp1+$gp2)";
    $msg.=" ".$res." g:0=$gp0 1=$gp1 2:$gp2 p:r$rePts k$koPts"
	." tgt:r$rTgt k$kTgt tgt2:r$rTgt2 k$kTgt2";

    if ($rSpec=~/B[10369]/) { $res.=$rkBonus; $res2.="B1"; }
    if ($kSpec=~/B[20369]/) { $res.=$rkBonus; $res2.="B2"; }
    if ($rGP ne "") { $res.="+".length($rGP)/2; $res2.=$rGP; }
    if ($kGP ne "") { $res.="-".length($kGP)/2; $res2.="/m1".$kGP; }
    $msg.=" : $res";
    $res=eval($res);
    $res=$winner.$res.";".$res2; #."\n".$msg;
    return $res;
    } # gamePointsDK  

sub gamePoints {
    my $table=shift;
    my ($POS) = @_;
    
    my $C=$table->get('C') || $table->get('Re..') || "";
    $C=substr($C,2) if length($C)>2;
    my $rePts=0; my $koPts=0; my $reTricks=0; my $koTricks=0;
    my $reAnn=""; my $koAnn=""; my $reNames=""; my $koNames="";
    foreach my $P (split("",$POS)) {
	my $pts=$table->get("POINTS..$P") || 0; 
	my $ann=$table->get("A$P") || "";
	$table->set("T$P","[$pts]");
	my $pName=$table->get("N$P");
	my $nTricks=$table->get("W$P") || 0;
	if (index($C,$P)>=0) {
	    $reNames.="|".$pName; $rePts+=$pts; 
	    $reTricks+=$nTricks;
	    $reAnn.="[ $pName]".$ann; 
	    }
	else {
	    $koNames.="|".$pName; $koPts+=$pts; 
	    $koTricks+=$nTricks;
	    $koAnn.="[ $pName]".$ann;
	    }
	}
    $reNames=substr($reNames,1); $koNames=substr($koNames,1);
    # Remove parts in ..Ann where a card of a partner was caught:
    while ($reAnn=~/^(.*)[\w\d]{2,2}\[\/($reNames)\](.*)$/) { $reAnn=$1.$3; }
    while ($koAnn=~/^(.*)[\w\d]{2,2}\[\/($koNames)\](.*)$/) { $koAnn=$1.$3; }
    $reAnn=~s/(Nx|Hz|\/)//ig; $koAnn=~s/(Nx|Hz|\/)//ig;
    # Special handling of 'schwarz' (no tricks won):
    my $rePts_=$rePts;
    if ($rePts_==240 && $koTricks==0) { $rePts_=241; } # ko is schwarz
    if ($rePts_==0   && $reTricks==0) { $rePts_=-1; } # re is schwarz
    my $specialPoints=$table->get('rules') || "";
    $specialPoints=~s/\,/|/g; 
    my $rkBonus=$table->get('rkBonus') || "+2";
    my $gp=gamePointsDK($rePts_,$reAnn,$koAnn,$rkBonus,$specialPoints);
    my ($rkGP,$tmp)=split(";",$gp);
   #gp="[$rkGP ]".$tmp;
    my $msg="[R:$rePts ]".$reAnn."/[K:$koPts ]".$koAnn."//[$rkGP ]".$tmp;
    $table->set('MSG',$msg);
#    my $automatic=$table->get('AUTO') || "";
#    if (index($automatic,'POIN')>=0) { convertPoints($table,$rkGP); }
    return $rkGP;
    } # gamePoints

sub convertPoints { # convert the game result into points per player
    # form: PLAYERNUM:POINTS:SHOWasW
    my $table=shift;
    my ($rkGP) = @_;
    
    my $rkWin=substr($rkGP,0,1); 
    my $ptsWin=0+substr($rkGP,1);
    my $C=$table->get('C') || $table->get('Re..') || "";
    $C=substr($C,2) if length($C)>2;
    my $POS=$table->{'POS'};
    my $reFactor=(length($C)==1 || substr($C,0,1) eq substr($C,1,1) ? 3 : 1);
    my $result="";
    foreach my $P (split("",$POS)) {
	my $gp_=$table->get("G$P") ||0;
	my $rk=(index($C,$P)>=0 ? "R" : "K");
	my $gPoints=($rk eq $rkWin ? $ptsWin : -$ptsWin);
	$gPoints*=$reFactor if $rk eq "R";
	$result.=",$P:$gPoints:($gPoints)";
	}
    return substr($result,1);
    } # convertPoints

1;
