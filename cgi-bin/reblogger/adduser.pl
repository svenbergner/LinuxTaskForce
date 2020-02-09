#!/usr/bin/perl -w

#J-Soft Reblogger version: 2.1r3

# J-Soft Reblogger New User Setup
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
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


# This program creates new user accounts. This involves adding the new username and password to rblist.pwd
# and creating the user's .pref, .dat, .pst, and .tpl files
#VARIABLE LISTING:
#
#	$path,		- path where reblogger scripts are stored
#	$url		- the url of the directory where the reblogger scripts are stored
#	$pw_path,	- path where usernames and passwords are stored
#	$sendmail	- path to sendmail
#	$pw_file,	- path to the file containing usernames and passwords
#	$pref_path,	- path to the user's preferences file
#	$dat_path,	- path to the file containing the comment counts for web log entries that have comments
#	$pst_path,	- path to the file containing all of the user's comments
#	$tpl_path,	- path to the file containing the user's template
#	$count_path,	- path to the file containing the number of user's on this host
#	
#	$submit,	- the CGI object
#	$max_users,	- maximum number of user's that can sign up on this host
#	$command,	- determines the action that will be taken

#	$pass,		- password submitted by the user
#	$crypted_pass	- password with encryption
#	$user,		- username submitted by the user
#	$email,		- email address submitted by the user
#	$output,	- used to store data to be output to a file
#	@output		- same as $output but as an array
#	$error		- contains error message to be displayed
#
#	%users,		- a hash containing the list of usernames and their passwords
#	$numUsers,	- stores the number of users that have signed up on this host
#
#	$template	- stores the contents of the user's blogger template
use strict;
use CGI;

use vars qw(
	$path $url $url2 $pw_path $sendmail $pw_file $pref_path $dat_path $pst_path $tpl_path $count_path
	
	$settings $max_users $submit $command 

	$pass $crypted_pass $user $email $output @output $error

	%users $numUsers 

	$template);
	

sub uNamePass; #asks for username, password
sub finish; #displayed after successful sign up
sub displayTemplate; # displays the users blogger template with reblogger code added
sub untaint; # checks that variables are not tainted
sub showcode; # displays code to add to blog template

#****************************************************************************************************
#****************************************************************************************************
#												    #
#												    #	
#												    #
 $max_users = 1; # change this value to the maximum number of user's you want to have on this host. #
#		 # The default is 1								    #
#												    #
#												    #
#												    #
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^#
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


require 'settings';

my $version = "2.1r2";

$count_path = $pw_path."count.dat";
open(NUMUSERS, '<'.$count_path) or die "could not get user count";
flock(NUMUSERS, 2);
$numUsers = <NUMUSERS>;
close(NUMUSERS) or die "could not close user count";



$submit = new CGI;

unless ($command = $submit->param('command')){
	$command = 'none';
}

if ($command eq 'none') {
	&uNamePass;
}

if ($command eq 'Sign Up'  && $numUsers < $max_users) {
	$pass = $submit->param('pass');	# password submitted by user
	$user = $submit->param('user');	# username
	$email = $submit->param('email');	# email address submitted by user
	my $systype = $submit->param('systype');
	
	
	$pw_file = $pw_path."rblist.cgi";	# path to the file containing usernames and their passwords

	open(USRCHK, '<'.$pw_file) or die "could not open $pw_file to check new user";
	flock(USRCHK, 2);
	%users = <USRCHK>;	# a hash containing the list of usernames and their passwords
	close(USRCHK) or die "could not close $pw_file while checking new user";
	
	
	if ($user && !$users{"$user\n"} && $pass && $email) {
	# if the username has not already been taken and an email address has been given then the new user
	# is created

		# the following line encrypts the password using perl's crypt function
		$crypted_pass = crypt($pass, join('', ('.', '/', 0..9, 'A'..'Z','a'..'z')[rand 64, rand 64]));

		$email = &untaint($email,'email');	# untaint email address
		$user = &untaint($user,'userName');	# untaint username
		open(USRADD, '>>'.$pw_file) or die "could not open $pw_file to add new user";
		flock(USRADD, 2);
		# the following line adds the new username and password to the password file
		print USRADD "$user\n$crypted_pass\n" or die "could not write to $pw_file to add user";
		close(USRADD) or die "could not close $pw_file to add new user";
	
	
	
		$output = <<"EOT"; # creates the user's preferences file
0
0

$email
0
text
newwin
450>|<480>|<Comment [#]>|<0
EOT

		$pref_path = $path.$user.'.pref';	# path to the user's preferences file
		open(PREFS, '>'.$pref_path) or die "could not open $pref_path to initiate prefs";
		flock(PREFS, 2);
		print PREFS $output or die "could not write to $pref_path to initiate prefs";
		close(PREFS) or die "could not close $pref_path to initiate prefs";

		
	      # the following creates the user's .dat file
		$dat_path = $path.$user.".dat";
		open(DAT, '>'.$dat_path);
		close(DAT);

		# the following creates the user's .pst file
		$pst_path = $path.$user.".pst";
		open(PST, '>'.$pst_path);
		close(PST);

		# the following creates the user's template file, which will contain the default template
		$tpl_path = $path.$user.".tpl";
		open(SETTPL, '>'.$tpl_path) or die "could not open $tpl_path to set template";
		$output = <<"EOT"; # default template
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
   <HEAD>
   <TITLE>Reblogger</title>
   

	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
	<meta http-equiv="Content-Script-Type" content="text/javascript" />
	<meta http-equiv="Content-Style-Type" content="text/css" />
	

	<style type="text/css">
	
		
		body {
			font-family: helvetica, arial;
			font-style: normal;
			background-color: #000045;
			color: #ffffff;
		}
		table {
			background-color: #000045;
		}
		td {
			border-spacing: 0px;
			border-width: 0px;
			border-color: transparent;
			border-style: solid;
			
		}
		div {
			border-width:0px;
		}
		
		
		td.main {
			padding:0px;
			
			
			vertical-align:top;
		}
		div.td-main {
			
			font-family: helvetica, arial;
			border-style:solid;
			border-color:#435577;
			border-width: 1px;
			background-color:#000034;
			padding: 10px;
			color: #ffffff;
		}
		
		div.hidden {
			visibility:hidden;
			color:#000045;
		}
		a {
			font-style:normal;
			text-decoration:underline;
			color:#6375b7;
		}
		a:hover {color:#6385e7;}
		a:visited {color:#637597;}

		a.topnav {
			font-style:normal;
			text-decoration:none;
			color:#e3e4f7;
		}

		
	</style>
   </head>

<BODY bgcolor="002367" text="ffffff">
<TABLE style="width:100%" align="left" width="100%"  bgcolor="000045">
   
   <TR>
      <TD valign=top align="left" bgcolor="000034" color="#ffffff"  ><div class="td-main">
	 
         <br><br><br>

	 <comments>
	 <*comment*>
	 <BR><font size=1>Posted by <B><*name*></b> at <*time*> <*date*></font>
	 <BR><BR><BR>
	 <comments>

	 <rbform><div class="td-main" style="background:#000045">
	 <TABLE align=center cellspacing=5>
	    <TR><TD >Name: </td><TD><*fname*></td></tr>
	    <TR><TD >Email: </td><TD><*email*></td></tr>
	    <TR><TD >Homepage: </td><TD><*homepage*></td></tr>
	    <TR><TD valign=top>Comments: </td><TD><*fcomment*><br><*htmltext*></td></tr>
	 </table>
	 <CENTER><*submit*></center><br>
	 </div></rbform><br><br>
         <center><*credit*></center>
      </div></td>
   </tr>
</table>
</body>
</html>

EOT

		print SETTPL $output or die "could not print to $tpl_path to initiate tpl";
		close(SETTPL) or die "could not close SETTPL";

		
		$count_path = $pw_path."count.dat"; # path to file that stores number of users that have
						      # an account
		open(COUNT, '<'.$count_path) or die "could not open count, retreive";
		flock(COUNT, 2);
		$numUsers = <COUNT>;
		close(COUNT) or die "couldn't close count, retrieve";

		$numUsers +=1; # increments the number of users that have signed up on this host
		
		open(COUNT, '>'.$count_path) or die "could not open count, update";
		flock(COUNT, 2);
		print COUNT $numUsers or die "could not write to count"; 
		close(COUNT) or die "couldn't close count, update";

		$output = $url."comment_manager.pl";
		# the following sends a confirmation email to the user that is signing up
		open(EMAIL, "| $sendmail -oi -t");
		flock(EMAIL, 2);
		print EMAIL "To: $email\n";
		print EMAIL "From: \"Reblogger\" <reblogger\@jsoft.ca>\n";
		print EMAIL "Subject: your reblogger account\n";
		print EMAIL "Your username is: $user\n";
		print EMAIL "Your password is: $pass\n\n";
		print EMAIL "To change your reblogger settings go to $output";
		close (EMAIL);	
		&showcode($systype); # displays final page of the sign up process
	}
	elsif ($users{"$user\n"}) {
	# if the username submitted by the user is already taken an error is displayed
		$error = "The username you selected is already in use on this host";
		&uNamePass; # displays the sign up form
	}
	else {
	# if there is one of the fields is empty then an error is displayed
		$error = "You must make sure you have filled all three fields.";
		&uNamePass; # displays the sign up form
	}
}
elsif ($command eq 'Sign Up' && $numUsers >= $max_users) {
	print "Content-type: text/html\n\nThe maximum number of users has been reached on this server";
	die "too many users";
}


if ($command eq 'Modify Template') {
# adds reblogger code to the user's template
	$user = $submit->param('user'); # username
	my $systype = $submit->param('systype'); # weblog system being used
	$template = $submit->param('template'); # the blogger template submitted by the user

	$url .= "reblogger.pl?command=load\&user=$user";
	$template =~ s/<head>/<head>\n<script type=\"text\/javascript\" src=\"$url\"> <\/script>/i;

	if ($systype eq "Blogger" || $systype eq "BlogStudio") {
	  $template =~ s/<\/Blogger>/<\!--start of comment link-->\n<script type=\"text\/javascript\">rebloggerLink(\'<\$BlogItemNumber\$>\')\;<\/script>\n<\!--end of comment link-->\n<br><br><\/Blogger>/i;
	}
	elsif ($systype eq "Thingamablog") {
	  $template =~ s/<\/BlogEntry>/<\!--start of comment link-->\n<script type=\"text\/javascript\">rebloggerLink(\'<\$EntryID\$>\')\;<\/script>\n<\!--end of comment link-->\n<br><br><\/BlogEntry>/i;
	  
	}
	elsif ($systype eq "Diary-x") {
	  $template =~ s/\[body\]/\[body\]<\!--start of comment link-->\n<script type=\"text\/javascript\">rebloggerLink(\'\[date\]\[time\]\')\;<\/script>\n<\!--end of comment link-->\n<br><br>/i;
	
	}

	&displayTemplate;

}

if ($command eq 'Continue') {
# sends the user to the reblogger comment manager
$url .= "comment_manager.pl";
	print <<"EOT";
Location: $url

EOT
}



sub showcode($systype) {
	$url2 = $url."reblogger.pl?command=load&user=$user";
	$url .= "adduser.pl";
	my $systype = shift;
	my $auto = 0; # boolean, can code be automatically added to the given sytem's template
	
	my $step1; # the first step to add reblogger to the given system
	my $step2; # the second step to add reblogger to the given system

	if ($systype eq "Blogger" || $systype eq "BlogStudio") {
	  $auto = 1;
	  $step1 = "<p>1. Open up your $systype template and insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2. Next you need to add a link within your template that your readers can click on to view and post comments. Insert the following code between the &lt;Blogger&lt;/Blogger&gt; tags in your template, where you want the link to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('<\$BlogItemNumber\$>');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Thingamablog") {
	  $auto = 1;
	  $step1 = "<p>1. Open up your Thingamablog template and insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2. Next you need to add a link within your template that your readers can click on to view and post comments. Insert the following code between the &lt;BlogEntry&lt;/BlogEntry&gt; tags in your template, where you want the link to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('<\$EntryID\$>');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Radio Userland") {
	  $auto = 0;
	  $step1 = "<p>1. Open up your Radio Userland template and insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2. Next you need to add a link within your template that your readers can click on to view and post comments. Insert the following code in template, where you want the link to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('<%itemNum%>');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Diaryland") {
	  $auto = 0;
	  $step1 = "<p>1. From the members area go to \"Change your template\" and then \"change how each of your entry pages looks\". Insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2.  Next you need to add a link that your readers can click on to view and post comments. Insert the following code where you want the link to appear. If you're using a weblog style diary you'll also have to go to \"change how each of your individual entries looks\" and insert this code where you want the linkt to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('%%date%%%%time%%');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Diary-x") {
	  $auto = 1;
	  $step1 = "<p>1. Open up your Diary-x template and insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2.  Next you need to add a link within your template that your readers can click on to view and post comments. Insert the following code where you want the link to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('[date][time]');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Big Blog Tool") {
	  $auto = 0;
	  $step1 = "<p>1. Open up your Big Blog Tool template and insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2. Next you need to add a link within your template that your readers can click on to view and post comments. Insert the following code in your template, where you want the link to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('\/.blogid');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Bloxsom") {
	  $auto = 0;
	  $step1 = "<p>1. Open the \'head.html\' part of your Bloxsom template and insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2. Next you need to add a link that your readers can click on to view and post comments. Insert the following code in the 'story.html' part of your template, where you want the link to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('\$mo_num,\$da,\$hr,\$min');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Pitas") {
	  $auto = 0;
	  $step1 = "<p>1. Log into Pitas and go to \"Make custom changes...\". Insert the following code in the &lt;HEAD&gt section.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2.  Next you need to add a link that your readers can click on to view and post comments. Go to \"Change the format...\" and insert the following code where you want the link to appear.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('%%date%%%%time%%');&lt;\/script&gt;</b>";
	}
	elsif ($systype eq "Other") {
	  $auto = 0;
	  $step1 = "<p>Reblogger will work as long as you provide a string to identify a comment thread. Most weblog systems provide a tag that you can place in your template that identifies each entry.<p>1. Add the following code to the &lt;HEAD&gt section of your weblog template or webpage.</p>
			<b>&lt;script type=text/javascript src=\"$url2\"&gt; &lt;/script&gt;<BR><BR><BR></b>";
	  $step2 = "<p>2. Next you need to add a link that your readers can click on to view and post comments. Insert the following code where you want the link to appear. Replace \"&lt;ItemID>\" with something to identify the comment thread.</p>
			<b>&lt;script type=\"text/javascript\"&gt;rebloggerLink('&lt;ItemID>');&lt;\/script&gt;</b>";
	}
	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Sign Up</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial;}
	A:visited {COLOR: #ffffff; TEXT-DECORATION: underline;}
	A:link {COLOR: #ffffff; TEXT-DECORATION: underline;}
        A:hover {COLOR: #d45700; TEXT-DECORATION: none;}
	A:unknown {COLOR: #ffffff; TEXT-DECORATION: underline;}
   </STYLE>
   
   </HEAD>

<BODY bgcolor=002367 text=ffffff>
<TABLE align=right width=100% height=100% bgcolor=000000>
   <TR><TD valign=bottom width=100% align=right><FONT size=5><I>Reblogger</I><br><font size=1>Version: $version</TD><TD valign=top align=right><IMG src=../../LogoR.gif></TD></TR>
   <TR>
      <TD valign=top bgcolor=002367 colspan=2 height=100%>
	 <br><br><br>
	 <table align=center width=85%>
	    <tr><td valign=top>
		 <center><font size=5><I>Welcome to Reblogger</I></font></center>
		 <font size=2>
		 <P>To make reblogger work with your blog you will have to add two pieces of code to your blog template. For Blogger, BlogStudio, Diary-x and Thingamablog you can scroll down and paste your template into the textbox. This program can add the code for you, however, the comment link might not be where you want it to be.<br><br>
	 	 $step1
	 	 $step2
		 
		 <p>Once you\'ve modified your template reblogger will be ready to run. Click on continue to proceed to your comment manager, where you can change various aspects of Reblogger.
                 <br><br>
		 <form method="post" action=\"$url\">
		    <center><input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Continue"></center>
		 </form>
EOT


if ($auto) {
	print <<"EOT";
	 	 <hr width=90%><br>If you don\'t want to add the code manually, paste your template code into the textbox below and the modified template will be displayed.
		 <br><br>
		 <form method="post" action=\"$url\">
                 <br><br><center><textarea name="template" rows=30 wrap=off style="background-color:#999999;border-color:#0023d4;width:60em" >template</textarea></center>
		 <br><br><input type="hidden" name="user" value="$user">
		 <br><br><input type="hidden" name="systype" value="$systype">
		 <center><input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Modify Template"></center>
EOT

}

	print <<"EOT";
	    </td></tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
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

sub uNamePass {
	$url .= "adduser.pl";
print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Sign Up</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana}
	A:visited {COLOR: #ffffff; TEXT-DECORATION: underline;}
	A:link {COLOR: #ffffff; TEXT-DECORATION: underline;}
        A:hover {COLOR: #d45700; TEXT-DECORATION: none;}
	A:unknown {COLOR: #ffffff; TEXT-DECORATION: underline;}
   </STYLE>
   <STYLE type=text/css name=BOTD>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
	A:visited {COLOR: #ffffff; TEXT-DECORATION: underline;}
	A:link {COLOR: #ffffff; TEXT-DECORATION: underline;}
        A:hover {COLOR: #002367; TEXT-DECORATION: none;}
	A:unknown {COLOR: #ffffff; TEXT-DECORATION: underline;}
   </STYLE>
   </HEAD>

<BODY bgcolor=002367 text=ffffff>
<TABLE align=right width=100% height=100% bgcolor=000000>
   <TR><TD valign=bottom width=100% align=right><FONT size=5><I>Reblogger</I><br><font size=1>Version: $version</TD><TD valign=top align=right><IMG src="../../LogoR.gif"></TD></TR>
   <TR>
      <TD valign=top bgcolor=002367 colspan=2 height=100%>
	 <br><br><br>
	 <table align=center width=75%>
	    <tr><td valign=top>
		 <center><font size=5><I>Reblogger Sign Up</I></font></center>
		 <FORM method="post" action="$url">
	 	 <TABLE align=center width=200>
	 	 <TR><TD valign=top colspan=2><FONT size=2><b>$error</b><br><br>Please enter a name you want to use as your username, and then enter your email address and a password</TD></TR>
	 	 <TR><TD valign=center><FONT size=2><BR>Username:</td><td valign=center><INPUT type=text name=user maxlength=15 size=15></TD></TR>
		 <TR><TD valign=center><FONT size=2><BR>Email:</td><td valign=center><INPUT type=text name=email maxlength=50 size=20></TD></TR>
	 	 <TR><TD valign=center><FONT size=2><BR>Password:</td><td valign=center><INPUT type=password name=pass maxlength=15 size=15></TD></TR>
		 <TR><td colspan="2" valign=center><font size="2"><p>Please select the weblog system you will be using reblogger with:</p><p><input type="radio" name="systype" checked value="Blogger" />Blogger<br><input type="radio" name="systype" value="BlogStudio" />BlogStudio<br><input type="radio" name="systype" value="Diary-x" />Diary-x<br><input type="radio" name="systype" value="Diaryland" />Diaryland<br><input type="radio" name="systype" value="Big Blog Tool" />Big Blog Tool<br><input type="radio" name="systype" value="Pitas" />Pitas<br><input type="radio" name="systype" value="Bloxsom" />Bloxsom<br><input type="radio" name="systype" value="Thingamablog" />Thingamablog<br><input type="radio" name="systype" value="Radio Userland" />Radio Userland<br><input type="radio" name="systype" value="Other">Other<br></p></font></TD></TR>
	 	 </TABLE>
		 <br><br>
		 <center><input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Sign Up"></center>
		 </FORM>
	    </td></tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
EOT

}



sub displayTemplate {
	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Sign Up</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial;}
	A:visited {COLOR: #ffffff; TEXT-DECORATION: underline;}
	A:link {COLOR: #ffffff; TEXT-DECORATION: underline;}
        A:hover {COLOR: #d45700; TEXT-DECORATION: none;}
	A:unknown {COLOR: #ffffff; TEXT-DECORATION: underline;}
   </STYLE>
   
   </HEAD>

<BODY bgcolor=002367 text=ffffff>
<TABLE align=right width=100% height=100% bgcolor=000000>
   <TR><TD valign=bottom width=100% align=right><FONT size=5><I>Reblogger</I><br><font size=1>Version: $version</TD><TD valign=top align=right><IMG src="../../LogoR.gif"></TD></TR>
   <TR>
      <TD valign=top bgcolor=002367 colspan=2 height=100%>
	 <br><br><br>
	 <table align=center width=85%>
	    <tr><td valign=top>
		 <center><font size=5><I>Welcome to Reblogger</I></font></center>
		 <font size=2>
		 <br><br>Here is your template with the reblogger code added. Please replace your current template with this one.
		 
                 <br><br><center><textarea name="template" rows=30 wrap=off style="background-color:#999999;border-color:#0023d4;width:60em">$template</textarea></center>
		 <br><br>
		 <form method="post" action=\""$url"adduser.pl\">
		 <center><input type=submit style="color:a3a3a3;background-color:002394;border-color:#0023d4" name=command value="Continue"></center>
		 </form>		 
	    </td></tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}
