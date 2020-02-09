#!/usr/bin/perl -w

#J-Soft Reblogger version: 2.1r3

# J-Soft Reblogger
# Copyright (C) 2002 by Jesse Malone

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA


# This program displays comments and allows visitors to leave comments. It performs three functions:

#	Load
#	Show
#	Post

# For a discription of the different files used by this program see the comments in comment_manager.pl

# Below are brief descriptions of the three functions this program performs:
#
# when given the command "Load" this program retrieves the post counts for the users web log entries from
# the user's .dat file and output a javascript program that displays them along with the comment link 
#
# when given the command "Show" this program will get the contents of the users .pst file and display all
# comments relevant to the web log entry for which they were requested, along with a form to display new
# comments. (everything is displayed according to the user's template of course)
#
# when given the command "Post Comment" this program will add the submitted comment to the user's .pst file.
# It will first check if the visitor's ip is in the user's list of ip addresses to block. If it is not then
# the comment is filtered for illegal html tags. Then the time is adjusted according to the user's time zone
# setting and added to the comment. The comment is formatted according to the user's template and output.


# VARIABLE LISTING:
#	$path	# path where this script is located
#	$url	# url where this script is located
#	$sendmail	# path to sendmail
#	$dat_path	# path to the user's .dat file
#	$pst_path	# path to the user's .pst gile
#	$pref_path	# path to the user's preferences file
#	$tpl_path	# patht to the user's template

#	$settings	# contents of the settings file
#	$submit		# the CGI object
#	$ip		# ip address of the visitor
#	$command	# determines what action to take
#	$user		# username
#	$item		# item number of the web log entry for which comments are being viewed or posted
#	$output		# used to store some output
#	$item_id	# used to store a single item id from @item_ids
#	@item_ids	# an array of id numbers of all of the web log entries for which there are comments
#	%pst_count	# a hash of post counts with their associated item numbers as keys
#	@pst_count	# a array used to output the contents of %pst_count

#	$i		# iterator

#	%rbform		# a hash containing the last values entered for name, email and homepage by the 
			# visitor that were placed in a cookie
#	$pst		# contains the contents of the user's .pst file 
#	@pst		# an array of all the individual posts in the user's .pst file
#	$valid_posts	# a string of all the posts that are associated with the current item
#	$template	# the contents of the user's template
#	@template	# an array containin three parts of the template with the <comments> section in the
			# middle 

#	$name		# the name submitted by the visitor
#	$homepage	# the homepage submitted by the visitor
#	$email		# the email address submitted by the visitor
#	$comments	# the comment submitted by the visitor
#	$rbform_cookie	# a cookie containing the contents of the submitted name email and homepage
#	@user_prefs	# an array containing the user's preferences
#	%prefs		# a hash containing the user's preferences
#	$allow		# indicates whether or not to allow the visitor to leave a comment
#	@ip_list	# the list of ip addresses to block
	
	# the following variables determine the time
#	$time_minute	# minutes
#	$time_hour	# hours
#	$date_day	# day of the month
#	$date_month	# month(numerical)
#	$date_year	# year

#	@months		# array of months of the year
#	@weekdays	# array of days of the week
#	$t_difference	# the user's time zone difference in hours from GMT
#	$time		# a string containing the time
#	$date		# a string containing the date

use strict;
use CGI;

use vars qw(
	$path $url $sendmail $pw_path $dat_path $pst_path $pref_path $tpl_path

	$settings $submit $ip $command $user $item $output $item_id @item_ids %pst_count @pst_count

	$i

	%rbform $pst @pst $valid_posts $template @template

	$name $homepage $email $comments $rbform_cookie @user_prefs $allow @ip_list
	
	$time_minute $time_hour $date_day $date_month $date_year $tz_correct $day_correct $month_correct $year_correct

	$t_difference $time $date);	 

sub untaint; # sub that checks that submitted values are not tainted


require 'settings';
require 'time_correct';




$submit = new CGI;
$ip = $ENV{'REMOTE_ADDR'};	# ip address of the visitor


# get user preferences
my %prefs; # hash of user preferences
$user = $submit->param('user');
$pref_path = $path.$user.'.pref'; # location of the user's preferences file  
open (GETPREFS, '<'.$pref_path) or die "could not open prefs";
flock(GETPREFS, 2);
chomp(@user_prefs = <GETPREFS>);	# an array containing the user's preferences
close(GETPREFS) or die "could not close prefs";

# create hash of preferences
$prefs{timezone} = $user_prefs[0];
$prefs{emailnotify} = $user_prefs[1];
$prefs{ipblock} = $user_prefs[2];
$prefs{emailaddr} = $user_prefs[3];
$prefs{displayAscending} = $user_prefs[4];
$prefs{dateformat} = $user_prefs[5];
$prefs{linktype} = $user_prefs[6];
$prefs{linkformat} = $user_prefs[7];



unless ($command = $submit->param('command')){
	$command = 'none';
}

if ($command eq 'load') {
# the following will return a javascript file which will display the comment window and comment counts
	my $presource = "\'\'"; # text that appears before the comment link source in the comment link
	my $postsource = "\'\'"; # text that appears after the comment link source 
	my $linktext; # string giving format of comment link
	my $cwidth; # width of comment window or iframe
	my $cheight; # height of comment windor or iframe
	my $iframeblend; # do not use the user's reblogger template within the iframe
			 # (retains comment format, and form layout)
	$output = "var pCount = new Array();"; # creates a javascript declaration for pCount, which is
						 # an array of post counts with their associated item numbers
						 # as the array index


	$user = $submit->param('user'); # user name
	$user = &untaint($user, 'userName');	# untaint user name
	$dat_path = $path.$user.'.dat'; # path to the user's .dat filr
	open(GETDAT, '<'.$dat_path) or die "could not open $dat_path for web log item data";
	flock(GETDAT, 2);
	chomp(@pst_count = <GETDAT>);	
	%pst_count = @pst_count; # a hash of post counts with their associated item numbers as keys
	close(GETDAT) or die "could not close $dat_path  for blog item data";

	@item_ids = keys(%pst_count);	# creates an array of the keys of %pst_count
	for $item_id (@item_ids) {
		$output .= "pCount[\'$item_id\'] = $pst_count{$item_id};"; # add the post counts to the
									 # javascript output

	}
	
	($cwidth,$cheight,$linktext,$iframeblend) = &linkformat($prefs{linkformat});
	
	
	
	# assign default window dimensions if dimensions have not been given
	unless (defined($cwidth)) {
	  $cwidth = 450;
	}
	unless (defined($cheight)) {
	  $cheight = 480;
	}
	unless (defined($linktext)) {
	  $linktext = "Comment [#]";
	}
	if ($prefs{linktype} eq '') {
	  $prefs{linktype} = 'newwin';
	}

	$linktext =~ s/\#/\"+pCount[item]+\"/; # replace # with post count

	if ($prefs{linktype} eq 'newwin') {
	  $presource = "\"<a href=\\\"javascript:displayReblogger(\'\"+item+\"\');\\\">$linktext</a><!--\"";
	  $postsource = "\"-->\"";
	}
	elsif ($prefs{linktype} eq 'iframe') {
	  $presource = "\"<a href=\\\"javascript:onpageReblogger(\\\'\"+item+\"\\\')\\\">$linktext</a><!-- \"";
	  $postsource = "\" -->\\n<div id=\'reblogger\"+item+\"\' ></div>\"";
	}
	elsif ($prefs{linktype} eq 'samewin') {
	  $presource = "\"<a href=\'\"";
	  $postsource = "\"\'>$linktext</a>\"";
	}
	
	


	
	$url .= "reblogger.pl?command=show&user=$user&item=";
	$output .= <<"EOT";	# add the postCount and displayReblogger functions to the javascript output

var commentsOpen = new Array();
function postCount(pre,item,post){
	if (pCount[item]){
		var output = pre + pCount[item] + post;
		document.write(output);
	} else {
		document.write(pre+"0"+post);
	}
}

function rebloggerLink(item) {

	if (!pCount[item]) {
		pCount[item] = 0;
	}
	var source = \"$url\" + item;
	var linktext = $presource + source + $postsource;
	document.write(linktext);
}

function onpageReblogger(item) {

	
	var source = \"$url\" + item;
	var iframe = "<a style=\\\"font-size:8pt\\\" href=\\\"javascript:onpageReblogger(\\\'\"+item+\"\\\')\\\">(hide)</a><iframe style=\\\"font-family:arial\\\" src='" + source + "' width=\'$cwidth\' height=\'$cheight\'></iframe>";
	var id = "reblogger" + item;
	if (!commentsOpen[item]) {
		commentsOpen[item] = 1;
		document.getElementById(id).innerHTML = iframe;
	}
	else {
		commentsOpen[item] = 0;
		document.getElementById(id).innerHTML = "";
	}
}


function displayReblogger(item){
	var source = \"$url\" + item;
	window.open(source,"Reblogger","width=$cwidth,height=$cheight,directories=0,toolbar=0,status=1,scrollbars=1");
}
EOT

	print <<"EOT";	# print $output
Content-type: text/javascript

$output
EOT

}

if ($command eq 'show'){
# the following will display the comment window
	my $valid_count = 0; # number of valid posts found
	my @valid_posts; # array of comments associated with $item
	my $linktext; # string giving format of comment link
	my $cwidth; # width of comment window or iframe
	my $cheight; # height of comment windor or iframe
	my $iframeblend; # do not use the user's reblogger template within the iframe
			 # (retains comment format, and form layout)
	my $rbform; # a string containing the form portion of the user's template

	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$item = $submit->param('item');	# item number of the web log entry that these comments are 
						# for
	$pst_path = $path.$user.'.pst';	# path to the user's .pst file
	$pref_path = $path.$user.".pref";	# path to the user's prefs file
	$tpl_path = $path.$user.".tpl";	# path to the user's template
	%rbform = $submit->cookie('rbform');	# a hash of the last values entered for name, email and
						# homepage by the visitor that were placed in a cookie

	open(GETPOSTS, '<'.$pst_path) or die "could not get posts for display";
	flock(GETPOSTS, 2);
	@pst = split(/<ITEM>/i, join('', <GETPOSTS>)); # an array of all the individual posts in the user's .pst file
	close(GETPOSTS) or die "could not close posts for display";

	
	for ($i=0;$i<@pst;$i++){;
		if ($pst[$i] =~ s/$item\n.+\n//i) {	
			$valid_posts[$valid_count] = $pst[$i];	# a string of all the posts that are associated
							# with the current item
			$valid_count += 1;
		}
	}
	
	open(GETTPL, '<'.$tpl_path) or die "could not open template for show";
	flock(GETTPL, 2);
	$template =  join('', <GETTPL>);	# a string containing the user's template
	close(GETTPL) or die "could not close template show";
	

	$url .= "reblogger.pl";
	# the following substitutions replace reblogger tags with the html they represent
	$template =~ s/<rbform>/<form method=\"post\" action=\"$url\">/gi;
	$template =~ s/<\*fname\*>/<input type=text name=name maxlength=30 value=\"$rbform{'fname'}\">/gi;
	$template =~ s/<\*email\*>/<input type=text name=email maxlength=50 value=\"$rbform{'email'}\">/gi;
	$template =~ s/<\*homepage\*>/<input type=text name=homepage maxlength=80 value=\"$rbform{'homepage'}\">/gi;
	$template =~ s/<\*fcomment\*>/<textarea cols=30 rows=10 name=comments maxlength=500><\/textarea>/gi;
	$template =~ s/<\*submit\*>/<input type=submit name=command value=\"Post Comment\">/gi;
	$template =~ s/<\/rbform>/<input type=\"hidden\" name=\"user\" value=\"$user\">\n<input type=\"hidden\" name=\"item\" value=\"$item\">\n<\/form>/gi;
	$template =~ s/<\*htmltext\*>/<font size="-1">&lt;b>&lt;\/b>&lt;u>&lt;\/u>&lt;i>&lt;\/i>&lt;a href=\"\">&lt;\/a> tags are allowed\. Tags cannot be nested\.<\/font>/gi;
	$template =~ s/<\*credit\*>/<div style="background-color:#000000;width:112px"><a href=\"http:\/\/jsoft.ca\/reblogger\/\" target="_Blank" style="font-family: verdana, helvetica, arial;text-decoration:none;color:#ffffff"><FONT size=4><I>Reblogger<\/i><IMG width=20 border=0 src=\"..\/..\/LogoR.gif\"><\/a><\/div>/gi;
	
	@template = split(/<comments>/i, $template);	# splits $template into three sections, with the
							# comments section in the middle
	$template[1] = ''; # remove comment formatting portion of template, which will be replaced
			   # with actual comments

	if ($prefs{displayAscending}) {
	  for ($i=$valid_count;$i>=0;$i--) {
	    $template[1] .= $valid_posts[$i];	# replaces template code with actual comments
	  }
	}
	else {
	  for ($i=0;$i<=$valid_count;$i++) {
	    $template[1] .= $valid_posts[$i];
	  }
	}

	($cwidth,$cheight,$linktext,$iframeblend) = &linkformat($prefs{linkformat});
	
	unless ($prefs{linktype} eq "iframe" && $iframeblend) {
	  $output = join("<comments>", @template);	# recombines all three parts of the template which 
							# have now been replaced with the actual html to 
							# output
	}
	else {
	  $template[2] =~ m/(<form.+\/form>)/si; # get the comment form from the template
	  $rbform = $1; 
	  $output = $template[1].$rbform;
	}
	print <<"EOT";
Content-type: text/html


$output
EOT
	
}

if ($command eq 'Post Comment'){
# the following adds a new comment to the user's .pst file
	$name = $submit->param('name');		# the name of the person that submitted the comment
	$homepage = $submit->param('homepage');	# homepage of the person that submitted the comment
	$email = $submit->param('email');	# email address of the person that submitted the comment
	$comments = $submit->param('comments');	# the comment itself
	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$item = $submit->param('item');	# the item id of the web log entry for which this comment was made
	$pst_path = $path.$user.'.pst';	# path to the user's .pst file
	$dat_path = $path.$user.'.dat';	# path to the user's .dat file
	$pref_path = $path.$user.'.pref';	# path to the user's preferences file
	$tpl_path = $path.$user.'.tpl';	# path to the user's template


	%rbform = ('fname',$name,'email',$email,'homepage',$homepage); # a hash containing the submitted name
								       # email and homepage
	$rbform_cookie = $submit->cookie(-name=>'rbform',	# creates a cookie containing the submitted
					 -value=>\%rbform,	# name email and homepage
					 -expires=>'+3M');

	open (GETPREFS, '<'.$pref_path) or die "could not open prefs";
	flock(GETPREFS, 2);
	chomp(@user_prefs = <GETPREFS>);	# an array containing the user's preferences
	close(GETPREFS) or die "could not close prefs";


	# the following determines if the visitor has been blocked form leaving comments
	$allow = "true";	# allow indicates whether of not to allow the visitor to leave a comment
      $allow = $submit->cookie('allow');	# if the visitor has been successfully blocked berofe there 
						# will be a cookie indicating this.

	@ip_list = split(/,/, $user_prefs[2]);	# creates an array of all the ip's to be blocked for
			        			# this user
	for ($i=0;$i<@ip_list;$i++) {
	       
		if ($ip eq $ip_list[$i] || $allow eq "false") {
		# if the visitors ip matches one of the ip's to block or the visitor has been blocked before
			$allow = $submit->cookie(-name=>'allow',	# creates cookie indicating the 
						 -value=>'false',	# visitor has been blocked before
						 -expires=>'+10y');
				print <<"EOT";	# display error message
Set-Cookie: $allow
Content-type: text/html

Error: <BR><BR><B><FONT color=ff0000>You have been blocked from leaving comments
EOT
			$command = 'none';
			die;
		}
	}




	$comments =~ s/</&lt;!/g;	# disables html tags in the comment
	
	$name =~ s/</&lt;/g;		# disables html tags in the submitted name
	
	$homepage =~ s/</&lt;/g;	# disables html tags in the sumitted homepage
	$homepage =~ s/http:\/\///i;	# removes http:// which will be added later

	$email =~ s/</&lt;/g;	# diables html tage in the submitted email address
	

	$comments =~ s/&lt;!\s*b\s*>([^&]+)&lt;!\s*\/b\s*>/<b>$1<\/b>/gis;
	$comments =~ s/&lt;!\s*b\s*>(.+)/<b>$1<\/b>/gis;
	$comments =~ s/&lt;!\s*a([^>]*)>([^&]+)&lt;!\s*\/a\s*>/<a target=\'_Blank\' $1>$2<\/a>/gi;
	$comments =~ s/&lt;!\s*a([^>]*)>([^\n]+)/<a target=\'_Blank\' $1>$2<\/a>/gis;
	$comments =~ s/&lt;!\s*i\s*>([^&]+)&lt;!\s*\/i\s*>/<i>$1<\/i>/gis;
	$comments =~ s/&lt;!\s*i\s*>(.+)/<i>$1<\/i>/gis;
	$comments =~ s/&lt;!\s*u\s*>([^&]+)&lt;!\s*\/u\s*>/<u>$1<\/u>/gis;
	$comments =~ s/&lt;!\s*u\s*>(.+)/<u>$1<\/u>/gis;

	$comments =~ s/(\s)+http:\/\/(\S+)/$1<a target=\'_Blank\' href=\'http:\/\/$2\'>http:\/\/$1<\/a>/gi;


	$comments =~ s/<([^<^>]*)\n([^<^>]*)>/<$1$2>/gis; #remove newlines from tags
	$comments =~ s/\n/<br>/g; # replace newline character with html <br> tags





	(my($time_second),	# seconds
	$time_minute,	# minutes
	$time_hour,	# hours
	$date_day,	# day of the month
	$date_month,	# month(numerical)
	$date_year,	# year
	my($day_week),	# day of the week(numerical)
	my($day_year),	# day of the year(numerical)
	my($isdst)		# determines whether it is daylight saving time or not
	) = localtime(time); # get the current time

	# array of months in the year, needed for text date
	my @months = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
	
	# array of days of the week, needed for text date
	my @weekdays = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');


	# the following four lines make adjustments to the time and date if the time or date on the
	# host is known to be incorrect
	$time_hour -= $tz_correct;
	$date_day -= $day_correct;
	$date_month -= $month_correct;
	$date_year -= $year_correct;

	# the following code adusts the time variables according to the user's time zone setting

	$t_difference = $prefs{timezone};	# the difference in hours from GMT
	
        
        $time_hour  += $t_difference;		# subtracts the time zone difference from GMT to get the
						# time in the user's time zone
	if ($time_hour>=24) {
	# adjust hour and day if the user's time zone is a day ahead of GMT
		$time_hour -= 24;
		$date_day += 1;
	}
	elsif ($time_hour < 0) {
	# adjust hour and day if the user's time zone is a day behind GMT
		$time_hour += 24;
		$date_day -= 1;
	}
	
	if ($time_minute < 10) {
	# add a leading "0" to the minute if the minute is not two digits
		$time_minute = "0".$time_minute;
	}

	$time = $time_hour.":".$time_minute;	# a string containing the resulting time

	$date_year += 1900;	# this is done because the localtime() function returns the number of 
				# years that have passed since 1900
	$date_month += 1;	# this is done because the localtime() function returns the month with a
				# range of 0..11, rather than the human friendly 1..12x

	if ($prefs{dateformat} eq "text") {
	  # write the date as text, with month and weekday names
	  $date = $weekdays[$day_week]." ".$months[$date_month]." ".$date_day.", ".$date_year; 
		# a string containing the resulting date
	}
	elsif ($prefs{dateformat}) {
	  # write the date in d/m/y or m/d/y format
	  $date = $prefs{dateformat};
	  $date =~ s/day\/month\/year/$date_day\/$date_month\/$date_year/i;	
	  $date =~ s/month\/day\/year/$date_month\/$date_day\/$date_year/i;
	}
	else {
	  $date = $date_day."/".$date_month."/".$date_year;
	}
	#end of time zone code
	
	open (GETTPL, '<'.$tpl_path) or die "could not open tpl for post";
	flock(GETTPL, 2);
 	@template = split(/<comments>/i, join('', <GETTPL>));	# the user's template split into three parts with the
							# comments section in the middle
	close(GETTPL) or die "could not close tpl for post";

	$output =<<"EOT";
<ITEM>$item
$ip
$template[1]
EOT

# $template[1] contains the template from which to contstruct the comment
# the following substitutions replace the template with the actual comment
	$output =~ s/<\*comment\*>/$comments/gi;

	# linkhtml contains the link that will appear with the comment
	my $linkhtml = "<a href=\"mailto:$email\">$name<\/a>(<a href=\"http:\/\/$homepage\" target=\"_blank\">www<\/a>)";

	if ($homepage eq '' && $email eq '') {
	  # if no homepage or email is given, then display only the commenter's name(no link)
	  $linkhtml = $name;
	}
	elsif ($email eq '') {
	  # if no email address is given, have the commenter's name link to their homepage
	  $linkhtml = "<a href=\"http:\/\/$homepage\" target=\"_blank\">$name</a>";
	}
	elsif ($homepage eq '') {
	  # if no homepage is give, display only the email link
	  $linkhtml = "<a href=\"mailto:$email\" target=\"_blank\">$name</a>";
	}
	  
	$output =~ s/<\*name\*>/$linkhtml/gi;
	$output =~ s/<\*time\*>/$time/gi;
	$output =~ s/<\*date\*>/$date/gi;

	open (WRTPST, '>>'.$pst_path) or die "could not open pst for post";
	flock (WRTPST, 2);
	print WRTPST $output or die "could not print to pst for post"; # add the new comment to the user's
									 # .pst file
	close(WRTPST) or die "could not close pst for post";


	
	if ($user_prefs[1] == 1){
	# if the user has email notification enable, send an email about this comment to them
	my $return_address;
	if ($email =~ m/[^\s]*@[^\s]*/) {
	  $return_address = $email;
	}
	else {
	  $return_address = 'reblogger@jsoft.ca';
	}

		open(EMAIL, "|$sendmail -oi -t");
		flock(EMAIL, 2);
		print EMAIL "To: $user_prefs[3]\n";
		print EMAIL "From: \"Reblogger Email Notification\" <$return_address>\n";
		print EMAIL "Subject: $name left a comment\n\n\n";
		print EMAIL "Comment left by $name: $url"."reblogger.pl?command=show&user=$user&item=$item\nIP Address: $ip\n\n";
		print EMAIL "$comments\n\n";
		print EMAIL "email: $email\nURL: $homepage\n\n";
		close(EMAIL);
	}

	

	open(GETDAT, '<'.$dat_path) or die "could not open datpath to get dat";
	flock(GETDAT, 2);
	chomp(@pst_count = <GETDAT>); 
	%pst_count = @pst_count;  # creates a hash of the user's post counts with their associated web log
				 # entry ids as keys
	close(GETDAT) or die "could not close datpath to get dat";

	$pst_count{$item} += 1; # increment the post count of the web log entry for which this comment was 
				# made
	
	$output = join("\n",%pst_count); # convert %pst_count into a scalar to be output
	open (WRTDAT, '>'.$dat_path) or die "could not open datpat to write dat";
	flock (WRTDAT, 2);
	print WRTDAT $output or die "could not print to datpath to write dat";
	close(WRTDAT) or die "could not close datpath to write dat";

	$url .= "reblogger.pl?command=show&user=$user&item=$item";
	print <<"EOT"; # return the visitor to the comments window
Set-Cookie: $rbform_cookie
Location: $url

EOT

}


sub untaint {
	my $str = $_[0];
        my $class = $_[1];
	
	if ($class eq 'userName' && $str =~ /^([\w-]+)$/) {
		return $1;
	}
	elsif ($class eq 'email' && $str =~ /(\S+)\@([\w.-]+)/) {
		return "$1\@$2";
	}
	else {
		print "Content-type: text/html\n\n$str<br>$class<br>The form you submitted contained invalid characters. Try removing characters such as \"\/\" \"\;\" \"\$\" \"\*\" \"\<\" or other unusual characters and then resubmit the form.";
		die "tainted variable"; 
	}
}

sub linkformat($formatstring) {
  my $formatstring = shift;
  my @result;
  
  $formatstring =~ m/(\d*[\w\%]*)>\|<(\d*[\w\%]*)>\|<(.*)>\|<(\d*)/ ;
  @result = ($1,$2,$3,$4);

  return @result;
}
