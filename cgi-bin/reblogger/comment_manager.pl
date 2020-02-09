#!/usr/bin/perl -w

#J-Soft Reblogger version: 2.1r3

# J-Soft Reblogger Comment Manager
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


# ----------------------------------------------------------------------------------------------------------
# This program changes a user's reblogger preferences. The functions which it performs are:

#	- Enable/disable email notification of new comments
#	- changing the user's time zone
#	- removing unwanted comments
#	- changing the user's template
#	- changing ip blicking settings

# Each user has four files which are stored in the same directory as the reblogger scripts. These are 
# username.pst, username.dat, username.pref, and username.tpl. In addition there are two files which may
# stored in a different directory that contain login information. These are rblist.cgi and usr_current.cgi.
# Below is a description of each file and how information is stored in it

# username.pst:
#
# username.pst is used to store all of the user's comments. Each comment is seperated by the text <ITEM>.
# The first two lines of each comment contain special information. The first line contains the item ID of
# the web log entry for which the comment was made, and the second line contains the IP address of the
# person that left the comment.

# username.dat:
#
# username.dat stores the number of comments that have been made for each web log entry. The information is
# stored in a list, with the even numbered lines of the file containing the ID number of a particular entry,
# and the odd numbered lines containing the number of comments for that entry. Here is an example
#
# 10000
# 5
# 12345
# 16
#
# Here the web log entry with ID 10000 has 5 comments and the web log entry with ID 12345 has 16 comments.


# username.pref
#
# username.pref stores the user's time zone, email notification status, ip's to block and the email address
# to be used for email notification
#
# below is the order in which informtion is stored in a users's preferences file
# line 0: time zone
# line 1: e-mail enabled/disabled
# line 2: ip addresses to block
# line 3: e-mail address for email notification

# username.tpl
#
# username.tpl is the file that contains the user's template. It is a normal html file with special tags to
# indicate how comments should be formatted and where they should appear, and where the add comments form
# should appear

# rblist.cgi
#
# rblist.cgi stores the list of users and their passwords. It should be kept in the cgi-bin directory, or
# another secure directory. User names are stored on even numbered lines and their passwords are stored on 
# odd numbered lines. Here is an example
#
# joe
# joespassword(encrypted, but don't bet your life on it)
# john
# johnspassword(encrypted, but don't bet your life on it)

# usr_current.cgi
#
# usr_current.cgi should be stored in the same directory as rblist.cgi. It contains a list of user's that
# have logged in. When a user logs in their user name is placed in this file along with a random number
# between 1 and 100000(the number is encrypted). The user's name and this number are placed in every form that they view. When a form
# is submitted the number placed in the form is compared with the number that was placed in usr_current.cgi 
# for that user. If it matches then whatever action the form requested is carried out.
# The file is formatted the same way as rblist.cgi, with the user names on even lines and their
# numbers on odd lines

#VARIABLE LISTING:

#	$path		- path where this script is stored
#	$pw_path	- path to directory where passwords and login information are stored
#       $url		- url of the directory where this script is stored
#	$sendmail       - path to sendmail
#	$pw_file	- path to password file
#	$usr_current	- path to list of currently logged in users
#	$pref_path	- path to a user's preferences file
#	$pst_path	- path to the file containing a user's posts
#	$dat_path	- path to the file containing a user's post counts
#	$tpl_path	- path to a user's template
#	$count_path	- path to the file containing the number of user's currently on this host

#	$settings	- contents of settings file
#	$submit		- data from submitted forms
#	$command	- value of the submit button on submitted forms
#	$user		- stores user name
#	$count		- a random integer placed on forms to verify that the user has logged in properly
#	$cryptedCount   - the encrypted $count
#	@user_prefs	- an array storing the contents of the user's preferences file

#	$i	- iterator
#	$i2	- iterator

	# variables used for Login
#	$pass	- the password submitted by the user
#	%pws	- a hash containing the list of users and their corresponding passwords
#	@pws    - an array containing the list of users and their corresponding passwords for input/output

	# variables used to enable email notification and change email entry in user's prefs file
#	$user_address	- stores the email address submitted by the user

	# variables used to Select Time Zone	
#	$tzone		- a string containing the user's time zone selection
#	@all_tzones	- an array containing all time zones
#	$t_difference	- the integer difference of the user's selection from GMT

	# variables used to display Remove Unwanted Comments form
#	$pst		- a scalar containing all of the user's posts
#	@pst		- an array of the user's individual posts
#	$output_pst	- a post with the first two lines removed
#	@current_pst	- an array of the individual lines of a post
#	$output		- the text of posts to be placed in the remove comments form
#	$max		- total number of posts

	# variables used to delete posts
#	@item		- array of item(web log entry) ID numbers associated with posts that were deleted
#	$num_items	- the number of posts that were deleted
#	%old_counts	- a hash containing the contents of the user's post counts file
#	@old_counts	- an array of the contents of the user's post counts file for input/output
#	@output		- array containing modified post counts to be written to the user's post counts file

	# variables used to Save Template
#	$template	- the contents of the template the user submitted

	# variables used to save ip list
#	$ip_list	- the list of IPs to block submitted by the user
#	$error		- message to display if the list is not properly formatted

#	# variables used to remove account
#	$numUsers	- number of users currently signed up on this host
# -----------------------------------------------------------------------------------------------------------
use strict;
use CGI;
use Fcntl;

use vars qw(
	$path $url $pw_path $sendmail $pw_file $usr_current $pref_path $pst_path $dat_path $tpl_path $count_path

	$settings $submit $command $user $count @user_prefs

	$i $i2

	$pass %pws @pws

	$user_address

	$tzone @all_tzones $t_difference

	$pst @pst $output_pst @current_pst $output $max

	@item $num_items %old_counts @old_counts @output

	$template

	$ip_list $error

	$numUsers
);

sub init;		# sets the random integer variable $count
sub usrCheck;		# checks that the $count submitted from the form matches the user's count in usr_count.dat
sub usrUpdate;		# remove the user's previous entry in usr_current.cgi and create new one
sub logIn;		# Displays login form
sub loggedIn;		# displays main form after login
sub badPw;		# displayed when user enters bad password(not done)
sub emailEnable;	# dispays enable email form
sub niceTry;		# displayed if usrCheck does not return true
sub tZone;		# displays time zone change form
sub delDialogue;	# displays delete form
sub changeTemplate;	# displays template form
sub ipBlocking;		# displays ip blocking form
sub untaint;		# checks for tainted variables
sub removeAccount;	# displays remove account form
sub fgpass;		# dispays forgotten  password form
sub getprefs($user);		# gets users preferences, returns a hash reference
sub writeprefs($user,$prefstowrite);		# writes user preferences to file from hash reference
sub showDateFormat;	# displays the date format form



require 'settings';

my $version = "2.1r2"; # reblogger version
# get user preferences
my $prefs_hash = {}; # hash(reference) of user preferences



$submit = new CGI;

unless ($command = $submit->param('command')){
	$command = 'none';
}

if ($command eq 'none'){
	$error = "";
	&logIn; #displays login screen
}


if ($command eq 'Login'){
#check user and password, if correct login user
	&init;
	

	$pass = $submit->param('pass');	# password
	$user = $submit->param('user');	# username

	$pw_file = $pw_path."rblist.cgi";	# string containing path to the file containing 
						# user names and passwords
	open(PWLIST, '<'.$pw_file) or die "could not open pw list";
	flock(PWLIST, 2);
	chomp(@pws = <PWLIST>);	#usernames and passwords stored in a hash with username as the key
	close (PWLIST) or die "could not close pw list";
	%pws = @pws;

	if ($pws{$user} && $pws{$user} eq crypt($pass, $pws{$user})) {
		&usrUpdate;	#add user name to list of currently logged in users
		&loggedIn;	#display main screen
	}
	else { 
		$error = "bad username or password";	# display error message indicating wrong username or
		&logIn;					# password entered
	}
}

if ($command eq 'Enable E-Mail Notification') {
#display form to enable email notification
	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action 
	if (&usrCheck == 1){
	# if the user has logged in properly do the following
			
				
		&emailEnable;	# outputs the enable email form
	}
	else {
		&niceTry;	# display "Nice try" error message
	}
}

if ($command eq 'Submit'){
# enables email notification and creates or changes email entry in user's prefs file 
# uses data submitted by the enable email notification form

	$user = $submit->param('user');			# user name
	$user = &untaint($user,'userName');			# untaint user name
	$user_address = $submit->param('email');		# user's submitted email address
	$user_address = &untaint($user_address,'email');	# untaint email address
	$count = $submit->param('count');			# $count placed in form by previous action
	
	if (&usrCheck == 1){
		$pref_path = $path.$user.'.pref';
		open(PREFS, '<'.$pref_path) or die "could not open $pref_path for updating email prefs";
		flock(PREFS, 2);
		@user_prefs = <PREFS>; # contents of user's prefs file. See top of this file for format
		close(PREFS) or die "could not close $pref_path for updating email prefs";

		$user_prefs[1] = "1\n"; # 1 indicates enabled, 0 indicates disabled
		$user_prefs[3] = "$user_address\n";

			

		open(WRTPREFS, '>'.$pref_path) or die "could not open $pref_path for writing email prefs";
		flock(WRTPREFS, 2);
		print WRTPREFS @user_prefs or die "could not write to $pref_path for writing email prefs";		
		close (WRTPREFS) or die "could not close $pref_path for writing email prefs";
		
		&loggedIn;	# go back to main form
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Disable E-Mail Notification') {
# diables e-mail notification

	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1){
	# if the user has logged in correctly do the following

		$pref_path = $path.$user.'.pref';	# path to user's prefs file
		open(PREFS, '<'.$pref_path) or die "could not open $pref_path for updating email prefs";
		flock(PREFS, 2);
		@user_prefs = <PREFS>; # contents of user's prefs file. See top of this file for format
		close(PREFS) or die "could not close $pref_path for updating email prefs";
		$user_prefs[1] = "0\n";	# 1 indicates enabled, 0 indicates disbled



		open(WRTPREFS, '>'.$pref_path) or die "could not open $pref_path for writing email prefs";
		flock(WRTPREFS, 2);
		print WRTPREFS @user_prefs or die "could not write to $pref_path for writing email prefs";
		close(WRTPREFS) or die "could not close $pref_path for writing email prefs";
		
		&loggedIn;	# return to main form
	}
	else {
	       &niceTry;	# display "Nice Try" error message
	}
}

if ($command eq 'Set Time Zone') {
# displays the time zone form
	$user = $submit->param('user');	#username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) { 
		&tZone; # display time zone form
	}
	else {
		&niceTry; # display "nice try" error
	}
}

if ($command eq 'Select Time Zone') {
# changes the time zone differenc(in hours) based on user's selection

	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$tzone = $submit ->param('tzone');	# time zone difference
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
		
		@all_tzones = ('GMT -12:00', 'GMT -11:00', 'GMT -10:00', 'GMT -09:00', 'GMT -08:00', 'GMT -07:00', 'GMT -06:00', 'GMT -05:00', 'GMT -04:00', 'GMT -03:00', 'GMT -02:00', 'GMT -01:00', 'GMT \(Greenwich Mean Time\)', 'GMT \+01:00', 'GMT \+02:00', 'GMT \+03:00', 'GMT \+04:00', 'GMT \+05:00', 'GMT \+06:00', 'GMT \+07:00', 'GMT \+08:00', 'GMT \+09:00', 'GMT \+10:00', 'GMT \+11:00', 'GMT \+12:00');

		for ($i=0;$i<@all_tzones;$i++) {	
			if ($tzone =~ m/$all_tzones[$i]/) {
				 $t_difference = $i - 12;
			}
		}
		
		
		$pref_path = $path.$user.'.pref';
		open(PREFS, '<'.$pref_path) or die "could not open $pref_path to set t_zone";
		flock (PREFS, 2);
		@user_prefs = <PREFS>; # the users prefs file. see top for format
		close(PREFS) or die "could not close $pref_path to set t_zone";

		$user_prefs[0] = "$t_difference\n"; # change time zone difference to user's selection

		open(WRTPREFS, '>'.$pref_path) or die "could not open $pref_path to write t_zone";
		flock(WRTPREFS, 2);
		print WRTPREFS @user_prefs or die "could not write to $pref_path to write t_zone";
		close(WRTPREFS) or die "could not close $pref_path to write t_zone";

		&loggedIn;	# go back to main form
	}
	else {
		&niceTry;	# display "nice try" error
	}
}

if ($command eq 'Remove Unwanted Comments') {
# displays the remove unwanted comments form
	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed on form by previous action
	if (&usrCheck == 1) {
		$pst_path = $path.$user.'.pst';
		$dat_path = $path.$user.'.dat';
		open(GETPST, '<'.$pst_path) or die "could not open $pst_path to get posts";
		flock(GETPST, 2);
		$pst = join('', <GETPST>);
		close(GETPST) or die "could not close $pst_path to get posts";
		
		@pst = split(/<ITEM>/, $pst); #split file into individual ITEMS of posts
		for ($i=1;$i<@pst;$i++) {
			$output_pst = ""; 
			@current_pst = split(/\n/, $pst[$i]); #split the current post into it's individual lines(the first to lines contain count info)
			for ($i2=2;$i2<@current_pst;$i2++) {
				$output_pst .= $current_pst[$i2]."\n";
			}
			$output .= "<tr><td valign=top bgcolor=\"#004587\"><font face=verdana size=2>".$current_pst[0]."<br>".$current_pst[1]."<br>".$output_pst."</td><td vilign=center bgcolor=004587><font face=verdana size=2><input type=checkbox name=".$i." value='true'></td></tr>\n";
		}
		$max = @pst;	# total number of posts

		&delDialogue;
	}
	else {
		&niceTry;
	}
}


#The following deletes any of the posts that were selected in the form displayed by &delDialogue
if ($command eq 'Delete') {
	$user = $submit->param('user');	# user name
	$user = &untaint($user,'userName');	# untaint user name
	$count = $submit->param('count');	# $count placed in form by previous action
	$max = $submit->param('max');		# total number of posts

	if (&usrCheck == 1) {
		$pst_path = $path.$user.'.pst';	# path to the file where user's posts are stored
		$dat_path = $path.$user.'.dat';	# path to the file where the user's comment counts
							# are stored
		open(GETPST, '<'.$pst_path) or die "could not open $pst_path to get posts";
		flock(GETPST, 2);
		$pst = join('', <GETPST>);
		close(GETPST) or die "could not close $pst_path to get posts";

		@pst = split(/<ITEM>/, $pst);	# spits $pst into individual items and stores them in @pst
		$num_items = 0;	# used to store the number of posts that are deleted and to keep
					# track of the index of @item
		
		for ($i=1;$i<@pst;$i++) {
			if ($submit->param($i) eq 'true' && $pst[$i-$num_items] =~ /\S+/) {
			# check boxes in the delete form are named with a number. if the value of the
			# $i'th check box is true and the i'th post is more than just space then the
			# following will be done to remove the $i'th post

				@current_pst = split(/\n/, $pst[$i-$num_items]); # split the current post 
										 # into individual lines
				$item[$num_items] = $current_pst[0]; # store the post's associated item id
			
				for ($i2=$i-$num_items;$i2<@pst;$i2++) {
					$pst[$i2] = $pst[$i2+1];	# remove the $i'th post
				}	
				$num_items += 1;
			}
		}

		open(WRTPST, '>'.$pst_path) or die "could not open $pst_path to write edited posts";
		flock(WRTPST, 2);
		$output = join("<ITEM>", @pst[0..@pst-$num_items-1]);	#rejoin all items with '<ITEM>' between them
		print WRTPST $output or die "could not print to $pst_path to write edited posts";
		close(WRTPST) or die "could not close $pst_path to write edited posts";
		
		open(GETDAT, '<'.$dat_path) or die "could not open $dat_path to get post counts";
		flock(GETDAT, 2);
		chomp(@old_counts = <GETDAT>);
		%old_counts = @old_counts;	# store post counts in a hash
		close(GETDAT);
		#new section
		for ($i=0;$i<@item;$i++) {
			$old_counts{$item[$i]} -= 1;	# reduces post count for the items for which posts
							# have been deleted
		}
		
		$output = join("\n", %old_counts);	# convert hash into a scalar to be output
		open(WRTDAT, '>'.$dat_path) or die "could not open dat path to write count";
		flock(WRTDAT, 2);
		print WRTDAT $output or die "could not write to dat path for count";
		close(WRTDAT) or die "could not close dat path for count";

	

		&loggedIn;

	}
	else {
		&niceTry;
	}
}

if ($command eq 'Change Template'){
# displays form to change template
	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
		&changeTemplate;	# display change template form
	}
	else {
		&niceTry;
	}
}

#The following saves the changes to a user's template
if ($command eq 'Save Template') {
	$user = $submit->param('user');	# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	$template = $submit->param('template');	# the template code submitted by the user
	if (&usrCheck == 1) {
		$tpl_path = $path.$user.".tpl";	# path to the user's template file
		open(TPLWR, '>'.$tpl_path) or die "could not open template path to write template";
		flock(TPLWR, 2);
		print TPLWR $template or die "could not write to template path";
		close(TPLWR) or die "could not close template path";

		&loggedIn;
	}
	else {
		&niceTry;
	}
}


if ($command eq 'IP Blocking') {
	$user = $submit->param('user');		# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
		$pref_path = $path.$user.'.pref';
		open(PREFS, '<'.$pref_path) or die "could not open $pref_path for IP blocking";
		flock(PREFS, 2);
		chomp(@user_prefs = <PREFS>);
		close(PREFS) or die "could not close $pref_path for IP blocking";
		$error = "";
		
		&ipBlocking;
	
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Save List') {
	$user = $submit->param('user');		# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	$ip_list = $submit->param('ipList');	# list of ip addresses to block entered by user
	if (&usrCheck == 1) {

		$ip_list =~ s/\s//g;	# remove any whitespace from the ip list

		if ($ip_list =~ /[^\d.,]+/) {
		# if the list contains characters other than digits, periods or commas then display an error
		# otherwise go ahead and write the changes to the user's prefs file
			$error = "Your list was not properly formatted, please re-enter it as a comma seperated list of IP addresses";
		       
			&ipBlocking;
		}
		else {
			$pref_path = $path.$user.'.pref';
			open(PREFS, '<'.$pref_path) or die "could not open $pref_path to get IP list";
			flock(PREFS, 2);
			@user_prefs = <PREFS>;
			close(PREFS) or die "could not close $pref_path to get IP list";

			$user_prefs[2] = "$ip_list\n"; # write new ip list. See top for format of prefs file

			open(WRTPREFS, '>'.$pref_path) or die "could not open $pref_path to write IP list";
			flock(WRTPREFS, 2);
			print  WRTPREFS @user_prefs or die "could print to $pref_path to write IP list";
			close(WRTPREFS) or die "could not close $pref_path to write IP list";

			&loggedIn;
		}
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Show comments in ascending order') {
	$user = $submit->param('user');		# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
	  $prefs_hash = &getprefs($user);
	  $prefs_hash->{displayAscending} = 1;
	  &writeprefs($user,$prefs_hash);
	  &loggedIn;
	
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Show comments in descending order') {
	$user = $submit->param('user');		# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
	  $prefs_hash = &getprefs($user);
	  $prefs_hash->{displayAscending} = 0;
	  &writeprefs($user,$prefs_hash);
	  &loggedIn;
	
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Change Date Format') {
	$user = $submit->param('user');		# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
	  &showDateFormat; # show date format form
	}
	else {
		&niceTry;
	}
      }

if ($command eq 'Save Date Format') {
  $user = $submit->param('user');		# username
  $user = &untaint($user,'userName');	# untaint username
  my $dformat = $submit->param('dformat'); # date format submitted
  $count = $submit->param('count');	# $count placed in form by previous action
  if (&usrCheck == 1) {
    $prefs_hash = &getprefs($user);
    $prefs_hash->{dateformat} = $dformat;
    &writeprefs($user,$prefs_hash);
    
    &loggedIn;
  }
  else {
    &niceTry;
  }
}

if ($command eq 'Change Comment Link') {
	$user = $submit->param('user');		# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
	  &showCommentLink; # show comment link format form
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Save Comment Link') {
	$user = $submit->param('user');		# username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action

	my $linktype = $submit->param('linktype');
	my $cwidth = $submit->param('width');
	my $cheight = $submit->param('height');
	my $blend = $submit->param('blend');
	my $linktext = $submit->param('linktext');
	if (&usrCheck == 1) {
	  $prefs_hash = &getprefs($user);
	  $prefs_hash->{linktype} = $linktype;
	  if ($blend eq "on") {
		$blend = 1;
	  }
	  $prefs_hash->{linkformat} = "$cwidth>|<$cheight>|<$linktext>|<$blend";

	  &writeprefs($user,$prefs_hash);

	  &loggedIn;
	}
	else {
		&niceTry;
	}
}



if ($command eq 'Remove Account') {
# displays remove account confirmation
	$user = $submit->param('user');	#username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
		&removeAccount; # displays remove account confirmation 
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Yes, I\'ve had it with reblogger') {
# removes the user's account
	$user = $submit->param('user');	#username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
		system("rm","$path$user.dat");	# removes the user's .dat file
		system("rm","$path$user.pst");	# removes the user's .pst file
		system("rm","$path$user.pref");	# removes the user's preferences file
		system("rm","$path$user.tpl");	# removes the user's template

		# the following removes the user's entry in the password file
		$pw_file = $pw_path."rblist.cgi";
		open(PWLIST, '<'.$pw_file) or die "could not open $pw_file to remove user";
		flock(PWLIST, 2);
		chomp(@pws = <PWLIST>);
		%pws = @pws;
		close (PWLIST) or die "could not close $pw_file to remove user";

		delete($pws{$user});
		
		@pws = %pws;
		$output = join("\n", %pws);
		open(WRTPW, '>'.$pw_file) or die "could not open $pw_file to write new pw list removing user";
		flock(WRTPW, 2);
		print WRTPW "$output\n" or die "could not write to $pw_file to remove user";
		close (WRTPW) or die "could not close $pw_file to write new pw list removing user";

		print "Content-type: text/html\n\nYour account has been removed";

		$count_path = $pw_path."count.dat";
		open (NUMUSERS, '<'.$count_path) or die "could not get count";
		flock(NUMUSERS, 2) or die "could not lock count";
		$numUsers = <NUMUSERS>;
		close(NUMUSERS) or die "could not close count";
		$numUsers -= 1;
		open (NUMUSERS, '>'.$count_path) or die "could not write count";
		flock(NUMUSERS, 2);
		print NUMUSERS $numUsers;
		close (NUMUSERS) or die "could not close count";
	}
	else {
		&niceTry;
	}
}

if ($command eq 'Oops, no!') {
	$user = $submit->param('user');	#username
	$user = &untaint($user,'userName');	# untaint username
	$count = $submit->param('count');	# $count placed in form by previous action
	if (&usrCheck == 1) {
		&loggedIn; # returns user to main form
	}
}

if ($command eq 'fgpass') {
	&fgpass;
}

if ($command eq 'Send me my password') {
	$user = $submit->param('user');
	$user_address = $submit->param('email');
	$pw_file = $pw_path."rblist.cgi";

	open(PWLIST, '<'.$pw_file) or die "could not open pw list";
	flock(PWLIST, 2);
	chomp(@pws = <PWLIST>);	#usernames and passwords stored in a hash with username as the key
	close (PWLIST) or die "could not close pw list";
	%pws = @pws;

	if ($user && $pws{$user}) {
		$user = &untaint($user, 'userName');
		$pref_path = $path.$user.'.pref';
		open(GETPREFS, '<'.$pref_path) or die "could not open $pref_path for password recover";
		flock(GETPREFS, 2);
		chomp(@user_prefs = <GETPREFS>);
		close (GETPREFS) or die "could not close $pref_path for password recover";
		$user_address = $user_prefs[3];
		
		$pass = join('', ('a'..'z', 'A'..'Z', '0'..'9')[rand 61, rand 63, rand 64, rand 61, rand 61, rand 61, rand 61]);
		# finish this and then see about server error with Soundcrafter

		$pws{$user} = crypt($pass, join('', ('.', '/', 0..9, 'A'..'Z','a'..'z')[rand 64, rand 64]));

		$output = join("\n", %pws);
		open(WRTPW, '>'.$pw_file) or die "could not open $pw_file to add new user";
		flock(WRTPW, 2);
		print WRTPW "$output\n" or die "could not write to $pw_file to add user";
		close(WRTPW) or die "could not close $pw_file to add new user";


		open(EMAIL, "| $sendmail -oi -t");
		flock(EMAIL, 2);
		print EMAIL "To: $user_address\n";
		print EMAIL "From: Reblogger password recovery\n";
		print EMAIL "Subject: here is your reblogger username and password\n";
		print EMAIL "\n\nUsername: $user\nPassword: $pass";
		close (EMAIL);


	}
	elsif ($user_address) {
		$user_address = &untaint($user_address, 'email');
		
		for $user (keys(%pws)) {
			$pref_path = $path.$user.'.pref';
			open(GETPREFS, '<'.$pref_path) or die "could not open $pref_path for password recover";
			flock(GETPREFS, 2);
			chomp(@user_prefs = <GETPREFS>);
			close (GETPREFS) or die "could not close $pref_path for password recover";

			if ($user_prefs[3] eq $user_address) {
				$pass = join('', ('a'..'z', 'A'..'Z', '0'..'9')[rand 61, rand 63, rand 64, rand 61, rand 61, rand 61, rand 61]);

				$pws{$user} = crypt($pass, join('', ('.', '/', 0..9, 'A'..'Z','a'..'z')[rand 64, rand 64]));

				$output = join("\n", %pws);
				open(WRTPW, '>'.$pw_file) or die "could not open $pw_file to add new user";
				flock(WRTPW, 2);
				print WRTPW "$output\n" or die "could not write to $pw_file to add user";
				close(WRTPW) or die "could not close $pw_file to add new user";


				open(EMAIL, "| $sendmail -oi -t");
				flock(EMAIL, 2);
				print EMAIL "To: $user_address\n";
				print EMAIL "From: Reblogger password recovery\n";
				print EMAIL "Subject: here is your reblogger username and password\n";
				print EMAIL "\n\nUsername: $user\nPassword: $pass";
				close (EMAIL);

				&logIn;
				die;
			}	
		}
	}
	
	logIn;
}

sub init {
	srand;
	$count = int(rand(100000));
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

sub usrCheck {
	my $passed = 0;	#indicates whether user is actually logged in. 0=false 1=true
	my %usr_list;	# will contain list of currently logged in users
	my @usr_list;	# %usr_list in the form of an array for input/output
	$usr_current = $pw_path."usr_current.cgi";
	open(USRCHK, '<'.$usr_current) or die "could not open $usr_current for usr list check";
	flock(USRCHK, 2);
	chomp(@usr_list = <USRCHK>);
	%usr_list = @usr_list;
	close(USRCHK) or die "could not close $usr_current for usr list check";

	if (crypt($count,$usr_list{$user}) eq $usr_list{$user}) {
	#if the count passed to this script ($count) matches the count last written to $usr_current.cgi
	#then return 1(true)
		$passed = 1;	
	}

	return $passed;
}

sub usrUpdate {

		my %usr_list;	# will contain list of currently logged in users
		my @usr_list; # %usr_list in the form of an array for input/output
	        my $cryptedCount; #encrypted count to be placed in usr_current.dat


		$cryptedCount = crypt($count, join('', ('.', '/', 0..9, 'A'..'Z','a'..'z')[rand 64, rand 64]));
		$usr_current = $pw_path."usr_current.cgi";
		open(USR, '<'.$usr_current) or die "could not open $usr_current for usr list prime";
		flock(USR, 2);
		@usr_list = <USR>;
		%usr_list = @usr_list;
		
		close (USR) or die "could not close $usr_current for usr list prime";

		delete $usr_list{"$user\n"};	#removes $user from %usr_list
		@usr_list = %usr_list;	#prepares list for output to file
		
		open(USROUT, '>'.$usr_current) or die "could not open $usr_current usr primed for writing";
		flock(USROUT, 2);
		print USROUT @usr_list or die "could not write primed usr";
		close(USROUT) or die "could not close primed usr";
		
		open (USRADD, '>>'.$usr_current) or die "could not open $usr_current usr to add";
		flock(USRADD, 2);
		$output = "$user\n$cryptedCount\n";	# add new entry for the current user in the list of logged 
						# in users
		print USRADD $output or die "could not write to $usr_current for usr add";
		close (USRADD) or die "could not close $usr_current for usr add";

}

sub getprefs($user) {
  my $user = shift;
  my $result = {};
  my $pref_path = $path.$user.'.pref'; # location of the user's preferences file
  open(GETPREFS, '<'.$pref_path) or die "could not open $pref_path for password recover";
  flock(GETPREFS, 2);
  chomp(@user_prefs = <GETPREFS>);
  close (GETPREFS) or die "could not close $pref_path for password recover";

  $result->{timezone} = $user_prefs[0];
  $result->{emailnotify} = $user_prefs[1];
  $result->{ipblock} = $user_prefs[2];
  $result->{emailaddr} = $user_prefs[3];
  $result->{displayAscending} = $user_prefs[4];
  $result->{dateformat} = $user_prefs[5];
  $result->{linktype} = $user_prefs[6];
  $result->{linkformat} = $user_prefs[7];

  return $result;
}

sub writeprefs($user,$prefstowrite) {
  my $user = shift;
  my $prefstowrite = shift;
  my @prefs_array;

  $prefs_array[0] = $prefstowrite->{timezone};
  $prefs_array[1] = $prefstowrite->{emailnotify};
  $prefs_array[2] = $prefstowrite->{ipblock};
  $prefs_array[3] = $prefstowrite->{emailaddr};
  $prefs_array[4] = $prefstowrite->{displayAscending};
  $prefs_array[5] = $prefstowrite->{dateformat};
  $prefs_array[6] = $prefstowrite->{linktype};
  $prefs_array[7] = $prefstowrite->{linkformat};

  my $output = join("\n",@prefs_array);
  my $pref_path = $path.$user.'.pref'; #location of user's preferences file
  open(WRTPREFS, '>'.$pref_path) or die "could not open $pref_path to write t_zone";
  flock(WRTPREFS, 2);
  print WRTPREFS $output or die "could not write to $pref_path to write t_zone";
  close(WRTPREFS) or die "could not close $pref_path to write t_zone";

}

sub niceTry {
	print <<"EOT";
Content-type: text/html

<b>You are not logged in, or are logged in in another browser window.
EOT

}

sub logIn {
	
	$url .= "comment_manager.pl";
	print<<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <br><br><br><br>
	 <table align=center width=75%>
	    <tr><td valign=top>
		 <center><font size=5><I>Reblogger Comment Manager</I></font></center>
		 <FORM method="post" action="$url">
	 	 <TABLE align=center width=200>
	 	 <TR><TD valign=top colspan=2><FONT size=2><b>$error</b><br><br>Please enter your user name and password below.</TD></TR>
	 	 <TR><TD valign=center><FONT size=2><BR>User Name:</TD><TD valign=center><INPUT type=text name=user></TD></TR>
	 	 <TR><TD valign=center><FONT size=2><BR>Password:</TD><TD valign=center><INPUT type=password name=pass></TD></TR>
	 	 </TABLE>
		 <br><br>
		 <center><input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Login"></center>
		 </FORM>
		 <br><center><a href="$url?command=fgpass">Forgotten password</a>
	    </td></tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}

sub fgpass {
	
	$url .= "comment_manager.pl";
	print<<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <br><br><br><br>
	 <table align=center width=75%>
	    <tr><td valign=top>
		 <center><font size=5><I>Reblogger Comment Manager</I></font></center>
		 <FORM method="post" action="$url">
	 	 <TABLE align=center width=200>
	 	 <TR><TD valign=top colspan=2><FONT size=2><b>$error</b><br><br>Please enter your username or email address below. Using your user name is faster so please enter it, unless you have forgotten it as well.</TD></TR>
		 <TR><TD valign=center><FONT size=2><BR>Username:</TD><TD valign=center><INPUT type=text name=user></TD></TR>
	 	 <TR><TD valign=center><FONT size=2><BR>Email Address:</TD><TD valign=center><INPUT type=text name=email></TD></TR>
	 	 </TABLE>
		 <br><br>
		 <center><input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Send me my password"></center>
		 </FORM>
	    </td></tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}

sub loggedIn {
	
	
	my $prefs_hash; # hash reference to preferences
	my $time_zone;	# time zone difference from GMT
	my $email;	# email address for email notification
	my $blocking;	# comma seperated list of ip addresses to block
	my $email_status;	# status of email notification. Enabled/Disabled
	my $email_command;	# command to display for email notification.
				# possible values: "Disable E-mail Notification","Enable E-mail Notification"
	my $display_order; # ascending/descending
	my $display_order_command; # text on display order toggle (display ascending/descending)

	$prefs_hash = &getprefs($user);

        $time_zone = $prefs_hash->{timezone};;
        $email = $prefs_hash->{emailnotify};
	$blocking = $prefs_hash->{ipblock};

	if ($prefs_hash->{displayAscending} == 1) {
		$display_order = "Ascending";
		$display_order_command = "Show comments in descending order";
	}
	else {
		$display_order = "Descending";
		$display_order_command = "Show comments in ascending order";
	}

	if ($email == 1){
		$email_status = "Enabled";
		$email_command = "Disable E-Mail Notification";
	}	
	else {
		$email_status = "Disabled";
		$email_command = "Enable E-Mail Notification";
	}

	$url .= "comment_manager.pl";
	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css name=norm>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=3>
		 <br><br>Welcome to the comment manager. Here you will find a number of tools to customize your Reblogger.<br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font size=2>
		    <b>Reblogger User Name: $user<br>
		    <b>Comment Display: $display_order<br>
		    <b>Time Zone: $time_zone<br>
		    <b>Date Format: $prefs_hash->{dateformat}<br>
		    <b>E-Mail Notification: $email_status<br>
		    <b>Blocking: $blocking
		</td>
		<td valign=top align=left>
		   <font size=2>Things To Do:
		   <br><br>
		   <form method=POST action="$url">
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="$display_order_command"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="$email_command"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Change Template"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Set Time Zone"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Change Comment Link"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Change Date Format"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Remove Unwanted Comments"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="IP Blocking"><br><br>
		   <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Remove Account"><br><br>
		   <input type=hidden name=count value=$count>
		   <input type=hidden name=user value=$user>
		   </form>
	         </td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>

EOT

}

sub emailEnable {
	$pref_path = $path.$user.'.pref';
	open(PREFS, '<'.$pref_path) or die "could not open $pref_path for email enable";
	flock(PREFS, 2);
	chomp(@user_prefs = <PREFS>);
	close(PREFS) or die "could not close $pref_path for email enable";

	$url .= "comment_manager.pl";
	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><br>When e-mail notification is enabled you will recieve an e-mail whenever a comment is posted. The message will contain the commenter\'s name, e-mail address, along with the time and date.<br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font size=2>
		    <table width=50% align=center>
		    <tr><td valign=top><font size=2>
		      To enable e-mail notification check that your e-mail address is entered correctly below and click on "Submit"<br><br>
		      <form method=POST action="$url">
			
		    	<input type=text name=email value=$user_prefs[3]><br><br>
			<input type=hidden name=count value=$count>
			<input type=hidden name=user value=$user>
			<input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Submit">
			
		      </form>
		    </td></tr>
		    </table>
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}

sub tZone {
	$url .= "comment_manager.pl";

	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font face=verdana size=2>
		    <table width=50% align=center>
		    <tr><td valign=top><font size=2>
		      Please select your time zone below and click on "Select Time Zone"<br><br>
		      <form method=POST action="$url">
			
		    	<select style="color:a3a3a3;background-color:002394;border-color:0023d4" name=tzone><option>GMT -12:00<option>GMT -11:00<option>GMT -10:00<option>GMT -09:00<option>GMT -08:00<option>GMT -07:00<option>GMT -06:00<option>GMT -05:00<option>GMT -04:00<option>GMT -03:00<option>GMT -02:00<option>GMT -01:00<option selected>GMT (Greenwich Mean Time)<option>GMT +01:00<option>GMT +02:00<option>GMT +03:00<option>GMT +04:00<option>GMT +05:00<option>GMT +06:00<option>GMT +07:00<option>GMT +08:00<option>GMT +09:00<option>GMT +10:00<option>GMT +11:00<option>GMT +12:00</select><br><br>
			<input type=hidden name=count value=$count>
			<input type=hidden name=user value=$user>
			<input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Select Time Zone">
			
		      </form>
		    </td></tr>
		    </table>
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}

sub delDialogue {
	$url .= "comment_manager.pl";

	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css name=norm>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><br>Here you can see a list of all the comments that have been posted on your web log. Select any comments you want to delete and click on "Delete".<br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font size=2>
		    <form method=post action="$url">
		    <table width=90% align=center>
		    $output
		    <tr><td valign=top align=right colspan=2><input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Delete"></td></tr>
		    </table>
		    <input type=hidden name=count value=$count>
		    <input type=hidden name=user value=$user>
		    <input type=hidden name=max value=$max>
		    </form>
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}


sub changeTemplate {
	$tpl_path = $path.$user.'.tpl';
	open (GETTPL, '<'.$tpl_path) or die "could not open $tpl_path to get template";
	flock (GETTPL, 2);
	$template = join('', <GETTPL>);
	close (GETTPL) or die "could not close $tpl_path to get template";

	$url .= "comment_manager.pl";

	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><br>This is your template. Make any changes you want to make and click on "Save Template". Below you will find information about the tags that you can use in the template.<br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font size=2>
		    <form method=post action="$url">
		    <center><textarea rows=30 wrap=off name="template" style="border-color:0023d4;background:#999999;width:60em">$template</textarea><br><br>
		    <input type=submit name=command value="Save Template"></center>
		    <input type=hidden name=count value='$count'>
		    <input type=hidden name=user value='$user'>
		    </form>
		    <br><br><br>
		    <font size=4><i>Special Tags</i></font><br><br>
		    Your template can contain any html you want, and can look however you want it to look. Here is a list of the special tags you can use, and how to use them.
		    <br><br><br>The following 4 tags must be placed between two &lt;comments&gt; tags:
		    <br><hr width=80%>&lt;*comment*&gt; - the main body of a comment
		    <br>&lt;*name*&gt; - the name of the person who left the comment, along with email and web links
		    <br>&lt;*time*&gt; - the time when the comment was posted
                    <br>&lt;*date*&gt; - the date when the comment was posted
		    <hr width=80%>
		    <br><br>The following 4 tags must be placed between a &lt;rbform&gt; tag and a &lt;/rbform&gt; tags:
		    <br><hr width=80%>&lt;*fname*&gt; - the name text box on the comment posting form
		    <br>&lt;*email*&gt; - the email text box on the comment posting form
		    <br>&lt;*homepage*&gt; - the homepage text box on the comment posting form
		    <br>&lt;*fcomment*&gt; - the comment text box on the comment posting form
		    <br>&lt;*submit*&gt; - the "Post Entry" button on the comment posting form
		    <br><hr width=80%>
		    <br><br>&lt;*credit*&gt; - a link to reblogger(much smaller than the old one)
		    <br><br>&lt;*htmltext*&gt; - text describing which html tags are allowed in comments
		    <br><br><br><b>Here is what your template should generally look like:</b>
		    <br><br>--Whatever code makes up your design--<br>
		    <br><br>&lt;comments&gt;<br>
		    <br>&lt;*comment*&gt;&lt;br&gt;
		    <br>Posted by &ltB&gt;&lt;*name*&gt;&lt;/B&gt; at &lt;*time*&gt; &lt;*date*&gt;
		    <br><br>&lt;comments&gt; -- That\'s right...there is no /comments tag, just two comments tags
		    <br><br>--Maybe some more of your code--<br>
		    <br>&lt;rbform&gt;<br>
	   	    <br>Name: &lt;*fname*&gt;&lt;br&gt;
		    <br>E-mail: &lt;*email*&gt;&lt;br&gt;
		    <br>Homepage: &lt;*homepage*&gt;&lt;br&gt;
		    <br>Comments: &lt;*fcomment*&gt;&lt;br&gt;&lt;br&gt;
		    <br>&lt;*htmltext*&gt;
		    <br>&lt;*submit*&gt;
		    <br><br>&lt;/rbform&gt;
		    <br><br>&lt;*credit*&gt;<br>
		    <br>--Perhaps even more of your code--
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}

sub ipBlocking { 
	$url .= "comment_manager.pl";

	print << "EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><b>$error</b><br>Please enter a comma seperated list of any IP addresses you want to block from leaving comments. If you have entered IP addresses to block before, they will appear in the text box and you can add and remove addresses from the list. Please note IP blocking will not work if the person you want to block has a dynamic(changing) IP address. Your list should be arranged like this: 192.168.1.1,192.168.1.2,198.168.1.3
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font size=2>
		    <form method=post action="$url">
		    <center><input type="text"  name="ipList" value="$user_prefs[2]" size=45  style="color:000000;background-color:949494;border-color:0023d4"><br><br>
		    <input type=submit name=command value="Save List"></center>
		    <input type=hidden name=count value='$count'>
		    <input type=hidden name=user value='$user'>
		    </form>
		    
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT


}

sub removeAccount {
	$url .= "comment_manager.pl";

	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY \{FONT-FAMILY:verdana, helvetica, arial}
	A:visited \{COLOR: \#ffffff; TEXT-DECORATION: underline;}
	A:link \{COLOR: \#ffffff; TEXT-DECORATION: underline;}
        A:hover \{COLOR: \#d45700; TEXT-DECORATION: none;}
	A:unknown \{COLOR: \#ffffff; TEXT-DECORATION: underline;}
   </STYLE>
   
   </HEAD>

<BODY bgcolor=002367 text=ffffff>
<TABLE align=right width=100% height=100% bgcolor=000000>
   <TR><TD valign=bottom width=100% align=right><FONT size=5><I>Reblogger</I><br><font size=1>Version: $version</TD><TD valign=top align=right><IMG src="../../LogoR.gif"></TD></TR>
   <TR>
      <TD valign=top bgcolor=002367 colspan=2 height=100%>
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font size=2>
		    <table width=50% align=center>
		    <tr><td valign=top><font size=2>
			Are you sure you want to remove your account?
		      <form method=POST action="$url">
			
			 <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Yes, I've had it with reblogger">&nbsp;&nbsp;
			 <input type=submit style="color:a3a3a3;background-color:002394;border-color:0023d4" name=command value="Oops, no!">
		    	
			<input type=hidden name=count value=$count>
			<input type=hidden name=user value=$user>
			
			
		      </form>
		    </td></tr>
		    </table>
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>
EOT

}

sub showDateFormat {
	$url .= "comment_manager.pl";

	print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font face=verdana size=2>
		    <table width=50% align=center>
		    <tr><td valign=top><font size=2>
		      Please select the date format you would like to use in comments.("text" means date is displayed in this format: Monday May 17, 2004)<br><br>
		      <form method="post" action="$url">
		    	<select style="color:a3a3a3;background-color:002394;border-color:0023d4" name="dformat"><option>text<option>month/day/year<option>day/month/year</select><br><br>
			<input type="hidden" name="count" value=\"$count\">
			<input type="hidden" name="user" value=\"$user\">
			<input type="submit" style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Save Date Format">
			
		      </form>
		    </td></tr>
		    </table>
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>

EOT

}

sub showCommentLink {
  $url .= "comment_manager.pl";
  my $cwidth;
  my $cheight;
  my $linktext;
  my $blend;
  my $newwin = '';
  my $samewin = '';
  my $iframe = '';
  my $iframeblend = '';
  my $prefs_hash = &getprefs($user); # hash of user's preferences

  if ($prefs_hash->{linktype} eq 'newwin') {
    $newwin = 'checked';
  }
  elsif ($prefs_hash->{linktype} eq 'samewin') {
    $samewin = 'checked';
  }
  elsif ($prefs_hash->{linktype} eq 'iframe') {
    $iframe = 'checked';
  }

  $prefs_hash->{linkformat} =~ m/(\d*[\w\%]*)>\|<(\d*[\w\%]*)>\|<(.*)>\|<(\d*)/;
  $cwidth = $1;
  $cheight = $2;
  $linktext = $3;
  $blend = $4;

  if (!defined($cwidth)) {
    $cwidth = 450;
  }
  if (!defined($cheight)) {
    $cheight = 480;
  }
 
  if (!defined($linktext)) {
    $linktext = "Comment [#]";
  }

  if ($blend) {
	$iframeblend = "checked";
      }
  print <<"EOT";
Content-type: text/html

<HTML>
   <HEAD>
   <TITLE>Reblogger Comment Manager</TITLE>
   <STYLE type=text/css>
	BODY {FONT-FAMILY:verdana, helvetica, arial}
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
	 <font size=5><I>Reblogger Comment Manager</I></font>
	 <table align=center width=90%>
	    <tr><td valign=top>
		 <font size=2>
		 <br><br>
	    </td></tr>
	    <tr>
		<td valign=top>
		    <font face=verdana size=2>
		    <table width=50% align=center>
		    <tr><td valign=top><font size=2>
		      <p><u>Important Note</u><br>If you have been using reblogger 2.0 you will have to change your comment link in order to use these options. Go <a href=\"blog-template-code.pl\">here</a> and replace your comment link with the code given in <b>step 2</b>.</p>
		      Please select the way you want reblogger to be displayed. <br><br>
		      <form method="post" action="$url">
			<input type="radio" name="linktype" $newwin value="newwin">Open Reblogger in a new window<br>
			<input type="radio" name="linktype" $iframe value="iframe">Open Reblogger on my blog (ie. display the comments directly below the post they correspond to)<br>
			<input type="radio" name="linktype" $samewin value="samewin">Open Reblogger in the same window as my blog<br>
			<p>Please specifty the width and height of the comment window(this also sets the size of the frame in which comments appear on your blog if you selected "Open Reblogger on my blog")</p>
			width: <input type="text" size="5" name="width" value=\"$cwidth\"> height: <input type="text" size="5" name="height" value=\"$cheight\"><br><br>
			<p>Please specify the text that should appear in the comment link. Use the # symbol to indicate where the comment count should appear</p>
			<input type="text" size="20" name="linktext" value=\"$linktext\"><br><br>
			<input type="hidden" name="count" value=\"$count\">
			<input type="hidden" name="user" value=\"$user\">
			<input type="submit" style="color:a3a3a3;background-color:002394;border-color:0023d4" name="command" value="Save Comment Link">
			
		      </form>
		    </td></tr>
		    </table>
		</td>
	       </tr>
	 </table> 
      </TD>
   </TR>
</TABLE>
</BODY>
</HTML>

EOT

}
